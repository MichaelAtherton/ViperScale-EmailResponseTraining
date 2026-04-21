#!/usr/bin/env bash
# Follow-up: wheels / BeadLok queries inside Super G+ category
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$VAULT_ROOT"
set -a; source .env; set +a
WC_BASE_URL="${WC_BASE_URL%/}"
API="$WC_BASE_URL/wp-json/wc/v3"
OUT_DIR="scratch/wc-spot-super-g-wheels"
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

echo "Super G+ wheel queries"
# BeadLok inside Super G+ category
run_query "01" "beadlok-in-super-g-cat"  "/products?category=69&search=beadlok&per_page=20&status=publish"
# All wheel-related subcategories (rear rims in Super G)
run_query "02" "super-g-rear-rims"       "/products?category=190&per_page=50&status=publish"
# Wheels/Tires/Gears/Axles - Super G (id=140)
run_query "03" "super-g-wheels-parent"   "/products?category=140&per_page=50&status=publish"
# "wheels" search inside Super G+
run_query "04" "super-g-wheels-search"   "/products?category=69&search=wheel&per_page=20&status=publish"
# Rear End Setups Super G (id=183)
run_query "05" "super-g-rear-end-setups" "/products?category=183&per_page=50&status=publish"
echo "Done."
