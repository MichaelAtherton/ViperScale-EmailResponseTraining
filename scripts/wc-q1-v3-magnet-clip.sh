#!/usr/bin/env bash
# Customer question 1: "I broke my V3 magnet clip and I don't see them on your site"
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$VAULT_ROOT"
set -a; source .env; set +a
WC_BASE_URL="${WC_BASE_URL%/}"
API="$WC_BASE_URL/wp-json/wc/v3"
OUT_DIR="scratch/wc-q1-v3-magnet-clip"
mkdir -p "$OUT_DIR"

run_query() {
  local num="$1" name="$2" path="$3"
  local body_file="$OUT_DIR/${num}-${name}.json"
  local headers_file="$OUT_DIR/${num}-${name}.headers"
  local http_code
  http_code=$(curl -sS -u "$WC_CONSUMER_KEY:$WC_CONSUMER_SECRET" -D "$headers_file" -o "$body_file" -w "%{http_code}" "$API$path")
  local size=$(wc -c < "$body_file" | tr -d ' ')
  printf "  %s  HTTP %s  %s bytes  %s\n" "$num" "$http_code" "$size" "$path"
}

echo "Q1: V3 magnet clip"

# 1. Direct search "magnet clip"
run_query "01" "search-magnet-clip"        "/products?search=magnet%20clip&per_page=10&status=publish"
# 2. "V3 magnet clip" exact
run_query "02" "search-v3-magnet-clip"     "/products?search=V3%20magnet%20clip&per_page=10&status=publish"
# 3. In V3 2025 category (id=496)
run_query "03" "cat-v3-search-clip"        "/products?category=496&search=clip&per_page=20&status=publish"
# 4. In V3 2025 category search magnet
run_query "04" "cat-v3-search-magnet"      "/products?category=496&search=magnet&per_page=20&status=publish"
# 5. In Viper V Platform (id=26) broader
run_query "05" "cat-vplatform-search-clip" "/products?category=26&search=clip&per_page=20&status=publish"
# 6. All categories with 'clip' or 'bracket' in name
run_query "06" "cats-search-clip"          "/products/categories?search=clip&per_page=50"
run_query "07" "cats-search-bracket"       "/products/categories?search=bracket&per_page=50"
run_query "08" "cats-search-v3"            "/products/categories?search=v3&per_page=50"
# 7. Raw "clip" search (may be noisy)
run_query "09" "search-clip"               "/products?search=clip&per_page=20&status=publish"
# 8. All products in V3 2025 category to see full inventory
run_query "10" "cat-v3-all"                "/products?category=496&per_page=100&status=publish"

echo "Done."
