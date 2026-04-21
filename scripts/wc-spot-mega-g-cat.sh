#!/usr/bin/env bash
# Spot check: products in Mega G+ category (id=89) — the direct lookup approach

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$VAULT_ROOT"

set -a
# shellcheck disable=SC1091
source .env
set +a

WC_BASE_URL="${WC_BASE_URL%/}"
API="$WC_BASE_URL/wp-json/wc/v3"

OUT_DIR="scratch/wc-spot-mega-g-cat"
mkdir -p "$OUT_DIR"
SUMMARY="$OUT_DIR/summary.txt"
: > "$SUMMARY"

run_query() {
  local num="$1"
  local name="$2"
  local path="$3"
  local body_file="$OUT_DIR/${num}-${name}.json"
  local headers_file="$OUT_DIR/${num}-${name}.headers"

  local http_code
  http_code=$(curl -sS \
    -u "$WC_CONSUMER_KEY:$WC_CONSUMER_SECRET" \
    -D "$headers_file" \
    -o "$body_file" \
    -w "%{http_code}" \
    "$API$path")
  local size
  size=$(wc -c < "$body_file" | tr -d ' ')
  printf "  %s  HTTP %s  %s bytes  %s\n" "$num" "$http_code" "$size" "$path" | tee -a "$SUMMARY"
}

echo "Mega G+ category lookup — $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$SUMMARY"
echo "" | tee -a "$SUMMARY"

# 1. All products in Mega G+ category (id 89) — first page
run_query "01" "mega-g-plus-cat-all"     "/products?category=89&per_page=100&status=publish"
# 2. Only in-stock products in Mega G+ category
run_query "02" "mega-g-plus-cat-instock" "/products?category=89&per_page=100&status=publish&stock_status=instock"
# 3. "rear tires" search inside Mega G+ category (the combo query)
run_query "03" "mega-g-plus-rear-tires"  "/products?category=89&search=rear%20tires&per_page=20&status=publish"
# 4. "tire" inside Mega G+ (broader)
run_query "04" "mega-g-plus-tire"        "/products?category=89&search=tire&per_page=20&status=publish"
# 5. "armature" inside Mega G+
run_query "05" "mega-g-plus-armature"    "/products?category=89&search=armature&per_page=20&status=publish"

echo "" | tee -a "$SUMMARY"
echo "Done." | tee -a "$SUMMARY"
