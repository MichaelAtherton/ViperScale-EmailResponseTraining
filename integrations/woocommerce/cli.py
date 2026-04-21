"""Viper Scale Racing — WooCommerce CLI.

Read-only CLI for catalog queries. Called by Enzo (via the catalog-lookup skill)
from /draft-reply at answer time. Returns standardized JSON envelopes on stdout.

Subcommands: lookup, search, list, find, categories, get, variations.

Exit 0 for success (including empty results).
Exit 1 for real errors (config, auth, network, 5xx, bad args).

See doc/woocommerce/implementation-spec.md §7 and §8 for full spec.
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import sys
from datetime import datetime, timezone
from html import unescape
from html.parser import HTMLParser
from typing import Any

from .cache import (
    DEALER_EXEMPT_CATEGORY_ID,
    get_cache,
    refresh_cache,
    resolve_category_id,
)
from .client import (
    WCAuthError,
    WCClient,
    WCError,
    WCNetworkError,
    WCNotFoundError,
    WCRateLimitError,
    WCServerError,
)
from .config import ConfigError, load_config

logger = logging.getLogger("viper.woocommerce.cli")

# Fields Enzo cares about on a product result
PRODUCT_FIELDS = (
    "id",
    "name",
    "sku",
    "price",
    "regular_price",
    "sale_price",
    "stock_status",
    "manage_stock",
    "stock_quantity",
    "backorders",
    "type",
    "status",
    "permalink",
    "slug",
)

# Fields Enzo cares about on a variation
VARIATION_FIELDS = (
    "id",
    "parent_id",
    "sku",
    "price",
    "regular_price",
    "sale_price",
    "stock_status",
    "manage_stock",
    "stock_quantity",
    "backorders",
    "permalink",
)


# ----------------------------------------------------------------------
# HTML stripping for descriptions

class _TagStripper(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.chunks: list[str] = []

    def handle_data(self, data: str) -> None:
        self.chunks.append(data)

    def get_text(self) -> str:
        return "".join(self.chunks)


def strip_html(html: str) -> str:
    if not html:
        return ""
    parser = _TagStripper()
    parser.feed(html)
    text = parser.get_text()
    text = unescape(text)
    # Collapse whitespace
    text = re.sub(r"\s+", " ", text).strip()
    return text


# ----------------------------------------------------------------------
# Result shaping

def _shape_category(cat: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": cat.get("id"),
        "name": cat.get("name"),
        "slug": cat.get("slug"),
    }


def _contains_dealer_exempt(categories: list[dict[str, Any]]) -> bool:
    return any(c.get("id") == DEALER_EXEMPT_CATEGORY_ID for c in categories or [])


def _shape_product(raw: dict[str, Any], include_descriptions: bool = False) -> dict[str, Any]:
    out: dict[str, Any] = {k: raw.get(k) for k in PRODUCT_FIELDS}
    out["categories"] = [_shape_category(c) for c in raw.get("categories") or []]
    # attributes: keep only the name + options (or "option" for variations)
    attrs: list[dict[str, Any]] = []
    for a in raw.get("attributes") or []:
        entry: dict[str, Any] = {"name": a.get("name")}
        if "option" in a:  # variation attribute
            entry["option"] = a.get("option")
        if "options" in a:
            entry["options"] = a.get("options")
        entry["variation"] = a.get("variation")
        attrs.append(entry)
    out["attributes"] = attrs
    # variations: array of child IDs, already small
    out["variations"] = raw.get("variations") or []
    if include_descriptions:
        out["short_description"] = strip_html(raw.get("short_description") or "")
        out["description"] = strip_html(raw.get("description") or "")
    # First image src only
    images = raw.get("images") or []
    if images:
        out["image"] = images[0].get("src")
    return out


def _shape_variation(raw: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {k: raw.get(k) for k in VARIATION_FIELDS}
    attrs: list[dict[str, Any]] = []
    for a in raw.get("attributes") or []:
        attrs.append({"name": a.get("name"), "option": a.get("option")})
    out["attributes"] = attrs
    return out


def _filter_dealer_exempt(products: list[dict[str, Any]], include: bool) -> list[dict[str, Any]]:
    if include:
        return products
    return [p for p in products if not _contains_dealer_exempt(p.get("categories") or [])]


# ----------------------------------------------------------------------
# Envelope helpers

def emit_success(command: str, results: list[dict[str, Any]], **extra: Any) -> int:
    envelope: dict[str, Any] = {
        "ok": True,
        "command": command,
        "count": len(results),
        "results": results,
    }
    envelope.update(extra)
    json.dump(envelope, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


def emit_error(command: str, error_code: str, message: str, **extra: Any) -> int:
    envelope: dict[str, Any] = {
        "ok": False,
        "command": command,
        "error": error_code,
        "message": message,
    }
    envelope.update(extra)
    json.dump(envelope, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 1


def _handle_wc_error(command: str, exc: WCError) -> int:
    return emit_error(command, exc.code, str(exc), status=exc.status)


# ----------------------------------------------------------------------
# Subcommand handlers

def cmd_lookup(args: argparse.Namespace, client: WCClient) -> int:
    try:
        body, _ = client.get("/products", {"sku": args.sku})
    except WCError as exc:
        return _handle_wc_error("lookup", exc)
    products = body if isinstance(body, list) else []
    products = _filter_dealer_exempt(products, args.include_dealer_exempt)
    shaped = [_shape_product(p, include_descriptions=args.include_descriptions) for p in products]
    return emit_success("lookup", shaped)


def cmd_search(args: argparse.Namespace, client: WCClient) -> int:
    params: dict[str, Any] = {
        "search": args.query,
        "per_page": args.limit,
    }
    if args.category is not None:
        params["category"] = args.category
    if args.in_stock:
        params["stock_status"] = "instock"
    try:
        body, _ = client.get("/products", params)
    except WCError as exc:
        return _handle_wc_error("search", exc)
    products = body if isinstance(body, list) else []
    products = _filter_dealer_exempt(products, args.include_dealer_exempt)
    shaped = [_shape_product(p, include_descriptions=args.include_descriptions) for p in products]
    return emit_success("search", shaped)


def cmd_list(args: argparse.Namespace, client: WCClient) -> int:
    # Support --chassis (auto-resolves) or --category (explicit ID)
    category_id = args.category
    resolved_from: str | None = None
    if category_id is None and args.chassis:
        cache = get_cache(client)
        category_id = resolve_category_id(cache, args.chassis)
        if category_id is None:
            return emit_error(
                "list",
                "chassis_not_found",
                f"Could not resolve chassis name to a category: {args.chassis!r}",
            )
        resolved_from = args.chassis
    if category_id is None:
        return emit_error("list", "bad_args", "must pass --category ID or --chassis NAME")

    params: dict[str, Any] = {
        "category": category_id,
        "per_page": args.limit,
    }
    if args.in_stock:
        params["stock_status"] = "instock"
    try:
        body, _ = client.get("/products", params)
    except WCError as exc:
        return _handle_wc_error("list", exc)
    products = body if isinstance(body, list) else []
    products = _filter_dealer_exempt(products, args.include_dealer_exempt)
    shaped = [_shape_product(p, include_descriptions=args.include_descriptions) for p in products]
    extras: dict[str, Any] = {"category_id": category_id}
    if resolved_from:
        extras["resolved_from"] = resolved_from
    return emit_success("list", shaped, **extras)


def cmd_find(args: argparse.Namespace, client: WCClient) -> int:
    cache = get_cache(client)
    category_id = resolve_category_id(cache, args.chassis)
    if category_id is None:
        return emit_error(
            "find",
            "chassis_not_found",
            f"Could not resolve chassis name to a category: {args.chassis!r}. "
            "Check the cached aliases, slugs, and names. "
            "Add an alias via /teach if this is a known customer phrasing.",
        )
    params: dict[str, Any] = {
        "category": category_id,
        "search": args.part,
        "per_page": args.limit,
    }
    if args.in_stock:
        params["stock_status"] = "instock"
    try:
        body, _ = client.get("/products", params)
    except WCError as exc:
        return _handle_wc_error("find", exc)
    products = body if isinstance(body, list) else []
    products = _filter_dealer_exempt(products, args.include_dealer_exempt)
    shaped = [_shape_product(p, include_descriptions=args.include_descriptions) for p in products]
    return emit_success(
        "find",
        shaped,
        category_id=category_id,
        chassis=args.chassis,
        part=args.part,
    )


def cmd_categories(args: argparse.Namespace, client: WCClient) -> int:
    try:
        cache = refresh_cache(client, hide_empty=args.hide_empty)
    except WCError as exc:
        return _handle_wc_error("categories", exc)
    results = [
        {
            "id": c.id,
            "name": c.name,
            "slug": c.slug,
            "parent": c.parent,
            "count": c.count,
        }
        for c in cache.categories
    ]
    return emit_success("categories", results)


def cmd_get(args: argparse.Namespace, client: WCClient) -> int:
    try:
        body, _ = client.get(f"/products/{args.id}", inject_publish=False)
    except WCError as exc:
        return _handle_wc_error("get", exc)
    if not isinstance(body, dict):
        return emit_error("get", "unknown_error", f"Unexpected response shape for /products/{args.id}")
    shaped = [_shape_product(body, include_descriptions=args.include_descriptions)]
    return emit_success("get", shaped)


def cmd_variations(args: argparse.Namespace, client: WCClient) -> int:
    try:
        body = client.get_paginated(
            f"/products/{args.id}/variations",
            {"per_page": 100},
            per_page=100,
            inject_publish=False,
        )
    except WCError as exc:
        return _handle_wc_error("variations", exc)
    variations = body if isinstance(body, list) else []
    shaped = [_shape_variation(v) for v in variations]
    return emit_success("variations", shaped, parent_id=args.id)


def cmd_health(args: argparse.Namespace, client: WCClient) -> int:
    """Quick end-to-end health check — auth, live endpoint, cache status.

    Exits 0 if everything passes; 1 if any check fails.
    """
    from .cache import _cache_path, load_cache
    from .client import _audit_log_path

    checks: list[dict[str, Any]] = []
    all_ok = True

    # 1. Auth + minimal products endpoint
    try:
        body, headers = client.get("/products", {"per_page": 1})
        total = headers.get("X-WP-Total") or headers.get("x-wp-total")
        checks.append({
            "name": "api_auth_and_products",
            "ok": True,
            "detail": f"auth ok; /products returned {len(body) if isinstance(body, list) else '?'} result, X-WP-Total={total}",
        })
    except WCError as exc:
        all_ok = False
        checks.append({
            "name": "api_auth_and_products",
            "ok": False,
            "error": exc.code,
            "detail": str(exc),
        })

    # 2. Categories cache (don't force refresh; report freshness)
    cache_path = _cache_path()
    cache = load_cache()
    if cache is None:
        checks.append({
            "name": "category_cache",
            "ok": False if not cache_path.exists() else True,
            "detail": (
                "cache file missing — will be created on first /find or /list --chassis call"
                if not cache_path.exists()
                else "cache file exists but failed to parse — will refresh on next use"
            ),
        })
    else:
        age_days = (datetime.now(timezone.utc) - cache.fetched_at).days
        stale = cache.is_stale()
        checks.append({
            "name": "category_cache",
            "ok": True,
            "detail": f"{len(cache.categories)} categories, {len(cache.aliases)} aliases, age {age_days}d, stale={stale}",
        })

    # 3. Audit log path
    log_path = _audit_log_path()
    log_ok = log_path.parent.exists() or log_path.parent.parent.exists()
    checks.append({
        "name": "audit_log",
        "ok": log_ok,
        "detail": f"path: {log_path}; exists={log_path.exists()}; parent exists={log_path.parent.exists()}",
    })
    if not log_ok:
        all_ok = False

    # Emit envelope
    return emit_success("health", checks, all_ok=all_ok) if all_ok else emit_error(
        "health",
        "health_check_failed",
        "one or more checks failed",
        checks=checks,
    )


# ----------------------------------------------------------------------
# Argument parsing

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="cli.py",
        description="Viper Scale Racing — read-only WooCommerce catalog CLI.",
    )
    sub = p.add_subparsers(dest="command", required=True)

    def add_common(sp: argparse.ArgumentParser) -> None:
        sp.add_argument("--limit", type=int, default=10, help="Max results (default 10, max 100)")
        sp.add_argument("--in-stock", action="store_true", help="Filter to in-stock products only")
        sp.add_argument(
            "--include-dealer-exempt",
            action="store_true",
            help="Include Dealer Exempt products (category id=336) in results",
        )
        sp.add_argument(
            "--include-descriptions",
            action="store_true",
            help="Include short_description and description in results (HTML stripped)",
        )

    # lookup
    s = sub.add_parser("lookup", help="Exact SKU lookup")
    s.add_argument("--sku", required=True)
    add_common(s)
    s.set_defaults(func=cmd_lookup)

    # search
    s = sub.add_parser("search", help="Fuzzy text search")
    s.add_argument("--query", required=True)
    s.add_argument("--category", type=int, help="Optional category ID to scope the search")
    add_common(s)
    s.set_defaults(func=cmd_search)

    # list
    s = sub.add_parser("list", help="Category listing")
    s.add_argument("--category", type=int, help="Category ID (or use --chassis)")
    s.add_argument("--chassis", type=str, help="Chassis name — resolved via cache (or use --category)")
    add_common(s)
    s.set_defaults(func=cmd_list)

    # find (the workhorse)
    s = sub.add_parser("find", help="Resolve chassis name + scoped part search")
    s.add_argument("--chassis", required=True)
    s.add_argument("--part", required=True)
    add_common(s)
    s.set_defaults(func=cmd_find)

    # categories
    s = sub.add_parser("categories", help="List all categories (refreshes cache)")
    s.add_argument("--hide-empty", action="store_true", help="Filter out categories with 0 products")
    s.set_defaults(func=cmd_categories)

    # get
    s = sub.add_parser("get", help="Fetch one product by internal ID")
    s.add_argument("--id", type=int, required=True)
    add_common(s)
    s.set_defaults(func=cmd_get)

    # variations
    s = sub.add_parser("variations", help="Fetch variations of a variable product")
    s.add_argument("--id", type=int, required=True)
    s.set_defaults(func=cmd_variations)

    # health
    s = sub.add_parser("health", help="End-to-end health check — auth, API, cache, audit log")
    s.set_defaults(func=cmd_health)

    return p


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(
        level=logging.WARNING,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
        stream=sys.stderr,
    )
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        config = load_config()
    except ConfigError as exc:
        return emit_error(args.command or "config", "config_error", str(exc))

    try:
        with WCClient(config) as client:
            func = args.func
            return func(args, client)
    except WCAuthError as exc:
        return _handle_wc_error(args.command or "unknown", exc)
    except WCNotFoundError as exc:
        return _handle_wc_error(args.command or "unknown", exc)
    except WCRateLimitError as exc:
        return _handle_wc_error(args.command or "unknown", exc)
    except WCServerError as exc:
        return _handle_wc_error(args.command or "unknown", exc)
    except WCNetworkError as exc:
        return _handle_wc_error(args.command or "unknown", exc)
    except WCError as exc:
        return _handle_wc_error(args.command or "unknown", exc)
    except KeyboardInterrupt:
        return emit_error(args.command or "unknown", "interrupted", "Interrupted by user")


if __name__ == "__main__":
    sys.exit(main())
