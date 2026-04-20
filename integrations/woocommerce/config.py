"""Configuration loader for the WooCommerce client.

Loads WC_BASE_URL, WC_CONSUMER_KEY, WC_CONSUMER_SECRET from .env at vault root.
Validates HTTPS, key prefixes, and strips trailing slashes. Raises ConfigError on issues.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv


class ConfigError(Exception):
    """Raised when WooCommerce config is missing or malformed."""


@dataclass(frozen=True)
class WCConfig:
    base_url: str
    consumer_key: str
    consumer_secret: str
    timeout_seconds: int = 15

    @property
    def api_base(self) -> str:
        """Full REST API base (no trailing slash)."""
        return f"{self.base_url}/wp-json/wc/v3"


def _find_vault_root() -> Path:
    """Walk up from this file until we find a directory containing CLAUDE.md.

    The vault root is the directory containing CLAUDE.md. .env lives there.
    """
    current = Path(__file__).resolve().parent
    for parent in [current, *current.parents]:
        if (parent / "CLAUDE.md").is_file():
            return parent
    # Fallback: two levels up from this file (integrations/woocommerce/config.py)
    return Path(__file__).resolve().parents[2]


def load_config() -> WCConfig:
    """Load WooCommerce credentials from .env at vault root.

    Raises ConfigError if required variables are missing or malformed.
    """
    vault_root = _find_vault_root()
    env_path = vault_root / ".env"
    if env_path.is_file():
        load_dotenv(env_path, override=False)

    base_url = (os.getenv("WC_BASE_URL") or "").strip()
    consumer_key = (os.getenv("WC_CONSUMER_KEY") or "").strip()
    consumer_secret = (os.getenv("WC_CONSUMER_SECRET") or "").strip()
    timeout_raw = (os.getenv("WC_TIMEOUT_SECONDS") or "15").strip()

    if not base_url:
        raise ConfigError("WC_BASE_URL not set in .env")
    if not consumer_key:
        raise ConfigError("WC_CONSUMER_KEY not set in .env")
    if not consumer_secret:
        raise ConfigError("WC_CONSUMER_SECRET not set in .env")

    if not base_url.startswith("https://"):
        raise ConfigError(
            f"WC_BASE_URL must start with https:// (got: {base_url!r}). "
            "Basic Auth over plain HTTP is insecure and unsupported."
        )
    base_url = base_url.rstrip("/")

    if not consumer_key.startswith("ck_"):
        raise ConfigError("WC_CONSUMER_KEY must start with 'ck_'")
    if not consumer_secret.startswith("cs_"):
        raise ConfigError("WC_CONSUMER_SECRET must start with 'cs_'")

    try:
        timeout_seconds = int(timeout_raw)
    except ValueError as exc:
        raise ConfigError(
            f"WC_TIMEOUT_SECONDS must be an integer (got: {timeout_raw!r})"
        ) from exc
    if timeout_seconds <= 0:
        raise ConfigError(f"WC_TIMEOUT_SECONDS must be > 0 (got: {timeout_seconds})")

    return WCConfig(
        base_url=base_url,
        consumer_key=consumer_key,
        consumer_secret=consumer_secret,
        timeout_seconds=timeout_seconds,
    )


def vault_root() -> Path:
    return _find_vault_root()
