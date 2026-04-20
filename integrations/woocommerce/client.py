"""HTTP client for the WooCommerce REST API v3.

Read-only, HTTPS + Basic Auth. Retry once on 429 and connection timeout.
Always injects status=publish on /products queries by default.
Emits audit log lines to .claude/logs/wc-queries.jsonl.
"""

from __future__ import annotations

import json
import logging
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

from .config import WCConfig, vault_root

logger = logging.getLogger("viper.woocommerce.client")

USER_AGENT = "ViperSecondBrain-WCClient/0.1"


class WCError(Exception):
    """Base exception for WooCommerce client errors."""

    code: str = "unknown_error"

    def __init__(self, message: str, *, status: int | None = None) -> None:
        super().__init__(message)
        self.status = status


class WCAuthError(WCError):
    code = "auth_failed"


class WCNotFoundError(WCError):
    code = "not_found"


class WCRateLimitError(WCError):
    code = "rate_limited"


class WCServerError(WCError):
    code = "server_error"


class WCNetworkError(WCError):
    code = "network_error"


def _audit_log_path() -> Path:
    return vault_root() / ".claude" / "logs" / "wc-queries.jsonl"


def _write_audit_log(entry: dict[str, Any]) -> None:
    """Append one JSON line to the audit log. Never raise — logging is best-effort."""
    path = _audit_log_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, separators=(",", ":")) + "\n")
    except OSError as exc:
        logger.warning("Failed to write audit log line: %s", exc)


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class WCClient:
    """Minimal read-only WooCommerce REST API client."""

    def __init__(self, config: WCConfig) -> None:
        self.config = config
        self.session = requests.Session()
        self.session.auth = (config.consumer_key, config.consumer_secret)
        self.session.headers["User-Agent"] = USER_AGENT
        self.session.headers["Accept"] = "application/json"

    def close(self) -> None:
        self.session.close()

    def __enter__(self) -> "WCClient":
        return self

    def __exit__(self, *exc: Any) -> None:
        self.close()

    # ------------------------------------------------------------------
    # Core GET with retry + error mapping

    def _is_products_path(self, path: str) -> bool:
        # Matches /products, /products?..., /products/{id}/variations, etc.
        # But NOT /products/categories (that has its own status rules).
        head = path.lstrip("/").split("?", 1)[0]
        if head == "products" or head.startswith("products/"):
            # Exclude /products/categories and /products/brands — those don't take status
            tail = head.split("/", 2)
            if len(tail) >= 2 and tail[1] in ("categories", "brands", "tags", "attributes", "shipping_classes", "reviews"):
                return False
            return True
        return False

    def get(
        self,
        path: str,
        params: dict[str, Any] | None = None,
        *,
        inject_publish: bool = True,
    ) -> tuple[Any, dict[str, str]]:
        """GET {api_base}/{path}. Returns (body, response_headers).

        Retries once on 429 (2s) and connection timeout (1s).
        Injects status=publish on /products queries when inject_publish is True.
        """
        params = dict(params or {})
        if inject_publish and self._is_products_path(path) and "status" not in params:
            params["status"] = "publish"

        url = f"{self.config.api_base}{path if path.startswith('/') else '/' + path}"
        audit: dict[str, Any] = {
            "ts": _now_iso(),
            "method": "GET",
            "path": path,
            "params": {k: v for k, v in params.items() if k not in ("consumer_key", "consumer_secret")},
            "status": None,
            "error": None,
            "duration_ms": None,
        }
        start = time.monotonic()

        attempt = 0
        last_exc: Exception | None = None
        while attempt < 2:
            attempt += 1
            try:
                resp = self.session.get(url, params=params, timeout=self.config.timeout_seconds)
            except requests.exceptions.ConnectTimeout as exc:
                last_exc = exc
                if attempt < 2:
                    logger.warning("Connection timeout; retrying once in 1s (%s)", path)
                    time.sleep(1.0)
                    continue
                audit.update(error="network_error", duration_ms=int((time.monotonic() - start) * 1000))
                _write_audit_log(audit)
                raise WCNetworkError(f"Connection timeout after retry: {exc}") from exc
            except requests.exceptions.ReadTimeout as exc:
                audit.update(error="network_error", duration_ms=int((time.monotonic() - start) * 1000))
                _write_audit_log(audit)
                raise WCNetworkError(f"Read timeout: {exc}") from exc
            except requests.exceptions.ConnectionError as exc:
                audit.update(error="network_error", duration_ms=int((time.monotonic() - start) * 1000))
                _write_audit_log(audit)
                raise WCNetworkError(f"Connection error: {exc}") from exc
            except requests.exceptions.RequestException as exc:
                audit.update(error="network_error", duration_ms=int((time.monotonic() - start) * 1000))
                _write_audit_log(audit)
                raise WCNetworkError(f"Request failed: {exc}") from exc

            # We have a response.
            if resp.status_code == 429 and attempt < 2:
                logger.warning("Rate-limited (429); retrying once in 2s (%s)", path)
                time.sleep(2.0)
                continue
            # Any other response: break out to map below.
            break
        else:
            # This branch shouldn't be reachable, but defend anyway.
            raise WCNetworkError(f"Gave up retrying: {last_exc}")

        duration_ms = int((time.monotonic() - start) * 1000)
        audit.update(status=resp.status_code, duration_ms=duration_ms)

        if 200 <= resp.status_code < 300:
            try:
                body = resp.json()
            except ValueError as exc:
                audit.update(error="bad_json")
                _write_audit_log(audit)
                raise WCServerError(f"Invalid JSON from API: {exc}", status=resp.status_code) from exc
            # Record result count if the body is a list, for cheap observability
            if isinstance(body, list):
                audit["result_count"] = len(body)
            _write_audit_log(audit)
            return body, dict(resp.headers)

        # Error paths
        if resp.status_code in (401, 403):
            audit.update(error="auth_failed")
            _write_audit_log(audit)
            raise WCAuthError(
                f"{resp.status_code} Unauthorized — check WC_CONSUMER_KEY/SECRET and key role",
                status=resp.status_code,
            )
        if resp.status_code == 404:
            audit.update(error="not_found")
            _write_audit_log(audit)
            raise WCNotFoundError(
                f"404 Not Found for {path}. Likely pretty-permalinks misconfigured, "
                "or an invalid ID.",
                status=resp.status_code,
            )
        if resp.status_code == 429:
            audit.update(error="rate_limited")
            _write_audit_log(audit)
            raise WCRateLimitError(
                "429 Rate-limited after one retry. Back off and retry manually.",
                status=resp.status_code,
            )
        if 500 <= resp.status_code < 600:
            audit.update(error="server_error")
            _write_audit_log(audit)
            raise WCServerError(
                f"{resp.status_code} server error from {path}", status=resp.status_code
            )
        # Other 4xx
        audit.update(error="unknown_error")
        _write_audit_log(audit)
        raise WCError(
            f"Unexpected {resp.status_code} from {path}: {resp.text[:200]}",
            status=resp.status_code,
        )

    # ------------------------------------------------------------------
    # Paginated GET — follows X-WP-TotalPages

    def get_paginated(
        self,
        path: str,
        params: dict[str, Any] | None = None,
        *,
        max_pages: int = 20,
        per_page: int = 100,
        inject_publish: bool = True,
    ) -> list[Any]:
        """GET with automatic pagination. Concatenates list results across pages.

        Reads X-WP-TotalPages to decide when to stop. Safety cap at max_pages.
        """
        params = dict(params or {})
        params.setdefault("per_page", per_page)

        all_results: list[Any] = []
        page = 1
        while page <= max_pages:
            params["page"] = page
            body, headers = self.get(path, params, inject_publish=inject_publish)
            if not isinstance(body, list):
                # Non-list response — unexpected for paginated endpoints
                return body  # type: ignore[return-value]
            all_results.extend(body)

            total_pages_str = headers.get("X-WP-TotalPages") or headers.get("x-wp-totalpages") or "1"
            try:
                total_pages = int(total_pages_str)
            except ValueError:
                total_pages = 1
            if page >= total_pages:
                break
            page += 1
        return all_results
