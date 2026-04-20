#!/usr/bin/env bash
# Wrapper for the WooCommerce CLI.
#
# Resolves vault root, picks the right Python interpreter (venv if present,
# else system python3), and runs `integrations.woocommerce.cli` with the
# provided args. Always invoked from the vault root regardless of caller CWD.
#
# Usage:
#   bash scripts/wc.sh <subcommand> [flags...]
#
# Examples:
#   bash scripts/wc.sh health
#   bash scripts/wc.sh find --chassis "Mega G+" --part "rear tires"
#   bash scripts/wc.sh lookup --sku 11065

set -euo pipefail

# Resolve vault root: the script lives at scripts/wc.sh under the vault root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Pick Python: venv first, then system.
VENV_PY="$VAULT_ROOT/integrations/woocommerce/.venv/bin/python"
if [[ -x "$VENV_PY" ]]; then
  PY="$VENV_PY"
else
  # Fall back to python3, then python.
  if command -v python3 >/dev/null 2>&1; then
    PY="python3"
  elif command -v python >/dev/null 2>&1; then
    PY="python"
  else
    echo '{"ok": false, "command": "wrapper", "error": "config_error", "message": "no python interpreter found; create integrations/woocommerce/.venv or install python3"}' >&2
    exit 1
  fi
fi

# Always run from vault root so `integrations.woocommerce.cli` is importable.
cd "$VAULT_ROOT"

exec "$PY" -m integrations.woocommerce.cli "$@"
