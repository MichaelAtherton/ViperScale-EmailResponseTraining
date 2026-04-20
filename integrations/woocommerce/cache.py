"""Category cache for the WooCommerce client.

Caches the full category taxonomy at .claude/cache/wc-categories.json.
7-day freshness. Paginates ALL pages on refresh (Viper has 204 across 3 pages).

Provides a 4-layer resolver: alias -> slug -> name -> unique token-subset.
Alias map is seeded with empirically verified entries; extended via /teach
over time.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from .client import WCClient
from .config import vault_root

logger = logging.getLogger("viper.woocommerce.cache")

CACHE_TTL = timedelta(days=7)
DEALER_EXEMPT_CATEGORY_ID = 336

# Seed alias map from implementation-spec.md §6.6 — empirically verified during Step 0
SEED_ALIASES: dict[str, int] = {
    "mega g+": 89,
    "mega g plus": 89,
    "super g+": 69,
    "super g plus": 69,
    "super g": 69,
    "tyco 440x2": 38,
    "tyco 440": 38,
    "440x2": 38,
    "tyco": 37,
    "jag hobbies": 45,
    "jag": 45,
    "v3": 496,
    "v1": 26,
    "aurora/tomy/afx": 36,
    "afx": 36,
    "life like": 40,
    "autoworld": 213,
    "drag cars": 310,
    "builders kits": 532,
    "clips/brackets/misc": 252,
    # Aurora/AFX/Tomy G-Plus cross-brand aliases — same chassis, multiple
    # brand prefixes customers use interchangeably. Category 522 is
    # "Aurora G-Plus" on the site; customers call it AFX G-Plus because
    # Aurora was acquired by Tomy/AFX and the brand shifted without the
    # product name updating. Added 2026-04-20 after customer email missed.
    "afx g-plus": 522,
    "afx g plus": 522,
    "aurora g-plus": 522,
    "aurora g plus": 522,
    "tomy g-plus": 522,
    "tomy g plus": 522,
    "g-plus": 522,
    "g plus": 522,
}


@dataclass
class Category:
    id: int
    name: str
    slug: str
    parent: int
    count: int


@dataclass
class CategoryCache:
    fetched_at: datetime
    categories: list[Category] = field(default_factory=list)
    aliases: dict[str, int] = field(default_factory=dict)

    def is_stale(self) -> bool:
        age = datetime.now(timezone.utc) - self.fetched_at
        return age > CACHE_TTL


def _cache_path() -> Path:
    return vault_root() / ".claude" / "cache" / "wc-categories.json"


def _parse_iso(ts: str) -> datetime:
    # Accept trailing Z
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    return datetime.fromisoformat(ts)


def load_cache() -> CategoryCache | None:
    """Load cache from disk. Returns None if missing or unreadable."""
    path = _cache_path()
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        categories = [
            Category(
                id=c["id"],
                name=c["name"],
                slug=c["slug"],
                parent=c.get("parent", 0),
                count=c.get("count", 0),
            )
            for c in data.get("categories", [])
        ]
        aliases = {k.lower(): v for k, v in (data.get("aliases") or {}).items()}
        fetched_at = _parse_iso(data["fetched_at"])
        return CategoryCache(fetched_at=fetched_at, categories=categories, aliases=aliases)
    except (OSError, KeyError, ValueError) as exc:
        logger.warning("Failed to load category cache: %s", exc)
        return None


def save_cache(cache: CategoryCache) -> None:
    path = _cache_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "fetched_at": cache.fetched_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "page_count": None,  # Filled in by refresh_cache when known
        "total_categories": len(cache.categories),
        "categories": [
            {
                "id": c.id,
                "name": c.name,
                "slug": c.slug,
                "parent": c.parent,
                "count": c.count,
            }
            for c in cache.categories
        ],
        "aliases": cache.aliases,
    }
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def refresh_cache(client: WCClient, *, hide_empty: bool = True) -> CategoryCache:
    """Fetch all category pages from the live API and rewrite the cache."""
    raw = client.get_paginated(
        "/products/categories",
        {"hide_empty": "true" if hide_empty else "false"},
        per_page=100,
        inject_publish=False,
    )
    categories = [
        Category(
            id=c["id"],
            name=c["name"],
            slug=c["slug"],
            parent=c.get("parent", 0),
            count=c.get("count", 0),
        )
        for c in raw
        if isinstance(c, dict) and "id" in c
    ]
    # Preserve any aliases from the existing cache; layer seeds on top
    existing = load_cache()
    aliases: dict[str, int] = dict(SEED_ALIASES)
    if existing:
        for k, v in existing.aliases.items():
            aliases[k.lower()] = v

    cache = CategoryCache(
        fetched_at=datetime.now(timezone.utc),
        categories=categories,
        aliases=aliases,
    )
    save_cache(cache)
    logger.info("Category cache refreshed: %d categories", len(categories))
    return cache


def get_cache(client: WCClient, *, force_refresh: bool = False) -> CategoryCache:
    """Return a usable cache. Refreshes if missing, stale, or force_refresh=True."""
    cache = load_cache()
    if cache is None or force_refresh or cache.is_stale():
        try:
            return refresh_cache(client)
        except Exception as exc:  # noqa: BLE001 - intentionally broad; logged below
            if cache is None:
                raise
            logger.warning("Cache refresh failed (%s); using stale cache", exc)
            return cache
    return cache


# ----------------------------------------------------------------------
# 4-layer resolver: alias -> slug -> name -> unique token-subset


def _tokens(s: str) -> set[str]:
    """Tokenize a chassis/category string for token-subset matching.

    Normalizes punctuation so "G-Plus", "G Plus", and "G+" all produce
    the same {"g", "plus"} token set. Drops empty tokens.
    """
    cleaned = s.lower().replace("/", " ").replace("-", " ").replace("+", " plus ")
    return {t for t in cleaned.split() if t}


def resolve_category_id(cache: CategoryCache, text: str) -> int | None:
    """Resolve a chassis/brand/part-type string to a category ID.

    Tries four layers in order:
      1. Exact alias match (case-insensitive)
      2. Exact slug match (case-insensitive)
      3. Exact name match (case-insensitive)
      4. Unique token-subset match against category names.
         Input tokens must be a subset of exactly ONE category's name
         tokens. Ambiguous matches return None — the resolver never
         guesses when multiple categories could match.
    Returns None if no layer matches unambiguously.
    """
    if not text:
        return None
    key = text.strip().lower()

    # Layer 1: aliases
    if key in cache.aliases:
        return cache.aliases[key]

    # Layer 2: slugs (slug-match is a common normalization for hyphenated forms)
    slug_key = key.replace(" ", "-")
    for c in cache.categories:
        if c.slug.lower() == slug_key or c.slug.lower() == key:
            return c.id

    # Layer 3: names (may be ambiguous if name repeats; first match wins)
    for c in cache.categories:
        if c.name.lower() == key:
            return c.id

    # Layer 4: unique token-subset match
    input_tokens = _tokens(key)
    if input_tokens:
        hits = [c for c in cache.categories if input_tokens.issubset(_tokens(c.name))]
        if len(hits) == 1:
            return hits[0].id

    return None
