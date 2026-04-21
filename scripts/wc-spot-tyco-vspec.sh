#!/usr/bin/env bash
# Spot check: Tyco armatures and VSPEC Builders Kits

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

OUT_DIR="scratch/wc-spot-tyco-vspec"
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

echo "Tyco + VSPEC spot check — $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$SUMMARY"
echo "" | tee -a "$SUMMARY"

# --- Tyco Timed Armature ---
# 1. Pure search
run_query "01" "search-tyco-timed-armature" "/products?search=Tyco%20Timed%20Armature&per_page=10&status=publish"
# 2. Search for 'Timed Armature'
run_query "02" "search-timed-armature"      "/products?search=Timed%20Armature&per_page=10&status=publish"
# 3. Tyco-related categories
run_query "03" "categories-search-tyco"     "/products/categories?search=tyco&per_page=100"
# 4. All Tyco 440X2 products (category id 38 from earlier finding)
run_query "04" "cat-440x2-armature"         "/products?category=38&search=armature&per_page=20&status=publish"
# 5. Broader 'armature' inside 440X2
run_query "05" "cat-440x2-all-armatures"    "/products?category=38&search=arm&per_page=20&status=publish"
# 6. All armatures anywhere
run_query "06" "categories-search-armature" "/products/categories?search=armature&per_page=100"

# --- VSPEC Builders Kits ---
# 7. Search
run_query "07" "search-vspec-builders"      "/products?search=VSPEC%20Builders&per_page=10&status=publish"
# 8. Just VSPEC
run_query "08" "search-vspec"               "/products?search=VSPEC&per_page=20&status=publish"
# 9. Builders Kits category (id 532 from earlier)
run_query "09" "cat-builders-kits"          "/products?category=532&per_page=100&status=publish"
# 10. VSPEC category (id 58 from earlier)
run_query "10" "cat-vspec"                  "/products?category=58&per_page=100&status=publish"

echo "" | tee -a "$SUMMARY"
echo "Done." | tee -a "$SUMMARY"
