#!/usr/bin/env bash
# Spot check: JAG Hobbies cars (brand lookup) + BeadLok wheels for Super G

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

OUT_DIR="scratch/wc-spot-jag-beadlok"
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

echo "JAG + BeadLok / Super G spot check — $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$SUMMARY"
echo "" | tee -a "$SUMMARY"

# --- JAG Hobbies ---
# 1. Full brand search
run_query "01" "search-jag-hobbies"    "/products?search=JAG%20Hobbies&per_page=10&status=publish"
# 2. Just JAG
run_query "02" "search-jag"            "/products?search=JAG&per_page=10&status=publish"
# 3. JAG in categories
run_query "03" "cats-search-jag"       "/products/categories?search=jag&per_page=50"
# 4. Brands endpoint (saw it in sample response; let's see if populated)
run_query "04" "brands-search-jag"     "/products/brands?search=jag&per_page=50"
# 5. All brands
run_query "05" "brands-all"            "/products/brands?per_page=100"

# --- BeadLok wheels for Super G ---
# 6. Plain search
run_query "06" "search-beadlok-super-g" "/products?search=BeadLok%20Super%20G&per_page=10&status=publish"
# 7. BeadLok alone
run_query "07" "search-beadlok"         "/products?search=BeadLok&per_page=20&status=publish"
# 8. Super G alone
run_query "08" "search-super-g"         "/products?search=Super%20G&per_page=20&status=publish"
# 9. Super G in categories
run_query "09" "cats-search-super-g"    "/products/categories?search=super%20g&per_page=50"
# 10. Super in categories
run_query "10" "cats-search-super"      "/products/categories?search=super&per_page=50"

echo "" | tee -a "$SUMMARY"
echo "Done." | tee -a "$SUMMARY"
