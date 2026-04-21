#!/usr/bin/env bash
# WooCommerce empirical check — runs 10 live queries and saves raw JSON responses.
# See doc/woocommerce/implementation-spec.md section 0 for why.
#
# Prerequisites:
#   1. .env at vault root contains WC_BASE_URL, WC_CONSUMER_KEY, WC_CONSUMER_SECRET
#   2. curl installed (standard on macOS)
#
# Usage:
#   bash scripts/wc-empirical-check.sh
#
# Output:
#   scratch/wc-empirical-check/<NN>-<name>.json   — raw response bodies
#   scratch/wc-empirical-check/<NN>-<name>.headers — response headers (for pagination info)
#   scratch/wc-empirical-check/summary.txt        — one-line summary per query

set -euo pipefail

# --- locate vault root (script lives in scripts/ directly under root) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$VAULT_ROOT"

# --- load .env ---
if [[ ! -f .env ]]; then
  echo "ERROR: .env not found at $VAULT_ROOT/.env" >&2
  echo "Create it with WC_BASE_URL, WC_CONSUMER_KEY, WC_CONSUMER_SECRET" >&2
  exit 1
fi

# Source .env without echoing its contents
set -a
# shellcheck disable=SC1091
source .env
set +a

: "${WC_BASE_URL:?WC_BASE_URL not set in .env}"
: "${WC_CONSUMER_KEY:?WC_CONSUMER_KEY not set in .env}"
: "${WC_CONSUMER_SECRET:?WC_CONSUMER_SECRET not set in .env}"

# Strip trailing slash from base URL if present
WC_BASE_URL="${WC_BASE_URL%/}"
API="$WC_BASE_URL/wp-json/wc/v3"

# --- set up output dir ---
OUT_DIR="scratch/wc-empirical-check"
mkdir -p "$OUT_DIR"
SUMMARY="$OUT_DIR/summary.txt"
: > "$SUMMARY"  # truncate

echo "WooCommerce empirical check — $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$SUMMARY"
echo "Base: $API" | tee -a "$SUMMARY"
echo "" | tee -a "$SUMMARY"

# --- helper: run a query, save body + headers, print summary line ---
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
    "$API$path" || echo "ERR")

  local size
  if [[ -f "$body_file" ]]; then
    size=$(wc -c < "$body_file" | tr -d ' ')
  else
    size="0"
  fi

  printf "  %s  HTTP %s  %s bytes  %s\n" "$num" "$http_code" "$size" "$path" | tee -a "$SUMMARY"
}

# --- the 10 queries ---
echo "Running 10 queries..." | tee -a "$SUMMARY"
echo "" | tee -a "$SUMMARY"

run_query "01" "baseline"         "/products?per_page=1"
run_query "02" "categories"       "/products/categories?per_page=100&hide_empty=true"

# For queries 3-5, we use search-to-discover since we don't have known SKUs yet.
# Pull a handful of products so we can inspect real shapes (simple, variable, OOS).
run_query "03" "sample-simple"    "/products?type=simple&per_page=3"
run_query "04" "sample-variable"  "/products?type=variable&per_page=3"
run_query "05" "sample-oos"       "/products?stock_status=outofstock&per_page=3"

# Fuzzy search quality — real customer phrasings
run_query "06" "search-pinion-mini-t"      "/products?search=pinion+Mini-T&per_page=5"
run_query "07" "search-magnet-traction"    "/products?search=Magnet+Traction+Kit&per_page=5"
run_query "08" "search-rear-tires-mega-g"  "/products?search=rear+tires+Mega+G&per_page=5"
run_query "09" "search-hp7-armature"       "/products?search=HP7+armature&per_page=5"
run_query "10" "search-brushless-motor"    "/products?search=brushless+motor&per_page=5"

echo "" | tee -a "$SUMMARY"
echo "Done. Results in $OUT_DIR/" | tee -a "$SUMMARY"
echo "" | tee -a "$SUMMARY"
echo "Tell Enzo it's done — he'll read the JSON files and analyze against the spec." | tee -a "$SUMMARY"
