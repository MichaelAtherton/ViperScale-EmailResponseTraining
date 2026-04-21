#!/usr/bin/env bash
# Spot check: how does the API handle "Mega G+" queries?
# Four approaches — see which returns sensible results for a real customer question.

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

OUT_DIR="scratch/wc-spot-mega-g"
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

echo "Mega G+ spot check — $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$SUMMARY"
echo "" | tee -a "$SUMMARY"

# 1. Get remaining category pages (2 and 3)
run_query "01" "categories-page2" "/products/categories?per_page=100&hide_empty=true&page=2"
run_query "02" "categories-page3" "/products/categories?per_page=100&hide_empty=true&page=3"

# 3. Search the category list for anything Mega-related
run_query "03" "categories-search-mega" "/products/categories?search=mega&per_page=100"

# 4. Plain search — "Mega G+"
run_query "04" "search-mega-g-plus" "/products?search=Mega%20G%2B&per_page=10&status=publish"

# 5. Plain search — "Mega G" (without plus — URL encoding can confuse things)
run_query "05" "search-mega-g" "/products?search=Mega%20G&per_page=10&status=publish"

# 6. Just "Mega"
run_query "06" "search-mega" "/products?search=Mega&per_page=10&status=publish"

# 7. More aggressive: search the whole catalog for the string
run_query "07" "search-mega-20" "/products?search=Mega&per_page=20&status=publish"

echo "" | tee -a "$SUMMARY"
echo "Done. Results in $OUT_DIR/" | tee -a "$SUMMARY"
