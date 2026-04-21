#!/usr/bin/env bash
# Follow-up to Q1: look inside Clips/Brackets/Misc categories and V3 product list
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$VAULT_ROOT"
set -a; source .env; set +a
WC_BASE_URL="${WC_BASE_URL%/}"
API="$WC_BASE_URL/wp-json/wc/v3"
OUT_DIR="scratch/wc-q1-followup"
mkdir -p "$OUT_DIR"

run_query() {
  local num="$1" name="$2" path="$3"
  local body_file="$OUT_DIR/${num}-${name}.json"
  local http_code
  http_code=$(curl -sS -u "$WC_CONSUMER_KEY:$WC_CONSUMER_SECRET" -o "$body_file" -w "%{http_code}" "$API$path")
  local size=$(wc -c < "$body_file" | tr -d ' ')
  printf "  %s  HTTP %s  %s bytes  %s\n" "$num" "$http_code" "$size" "$path"
}

echo "Q1 follow-up"
# Clips/Brackets/Misc under Viper V Chassis (id=252)
run_query "01" "cat-252-clips-brackets"  "/products?category=252&per_page=50&status=publish"
# Search 'magnet' inside Clips/Brackets
run_query "02" "cat-252-magnet"          "/products?category=252&search=magnet&per_page=20&status=publish"
# Chassis/Brackets/Clips/Accessories (id=369)
run_query "03" "cat-369-chassis-brackets" "/products?category=369&per_page=20&status=publish"
# Full 2025 V3 category product list
run_query "04" "cat-496-v3-all"          "/products?category=496&per_page=100&status=publish"
echo "Done."
