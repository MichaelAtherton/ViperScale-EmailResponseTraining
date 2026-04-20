#!/usr/bin/env bash
# Regression harness for the WooCommerce catalog resolver and zero-count paths.
#
# Purpose: verify the four canonical cases from doc/design/ambiguous-lookup-response.md
# still behave correctly after any change to resolver logic (cache.py) or CLI.
#
# Usage:
#   bash scripts/wc-regression.sh
#
# Exit code: 0 if all cases pass, 1 if any fail. Prints pass/fail per case.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WC="$VAULT_ROOT/scripts/wc.sh"

PASS=0
FAIL=0

pass() {
  printf "  \033[32mPASS\033[0m %s\n" "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf "  \033[31mFAIL\033[0m %s\n" "$1"
  printf "       expected: %s\n" "$2"
  printf "       got:      %s\n" "$3"
  FAIL=$((FAIL + 1))
}

# ----------------------------------------------------------------------
# Case 1: AFX G-Plus armature
#   Expected: resolver hits SEED_ALIASES, returns category_id=522.
#   Expected: count=0 (category has Motor Magnets + Pickup Shoes, no armatures).
#   Expected: ok=true (NOT chassis_not_found — this is the case the fix targets).
echo "Case 1: AFX G-Plus armature (alias resolution + zero-count)"
OUT=$(bash "$WC" find --chassis "AFX G-Plus" --part "armature" --limit 5 2>&1)
OK=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok'))")
CAT=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('category_id'))")
COUNT=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('count'))")
if [[ "$OK" == "True" && "$CAT" == "522" && "$COUNT" == "0" ]]; then
  pass "resolved to category 522, count=0"
else
  fail "AFX G-Plus armature" "ok=True category_id=522 count=0" "ok=$OK category_id=$CAT count=$COUNT"
fi

# ----------------------------------------------------------------------
# Case 2: HP7 tires (rule-backed clean-no)
#   Expected: chassis_not_found from CLI (HP7 has no category on the site).
#   This IS the correct CLI behavior — the skill layer then checks
#   tire-compatibility.md which lists HP7 → Branch A clean-no.
echo "Case 2: HP7 tires (chassis_not_found → skill-layer clean-no)"
OUT=$(bash "$WC" find --chassis "HP7" --part "tires" --limit 3 2>&1)
OK=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok'))")
ERR=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('error'))")
if [[ "$OK" == "False" && "$ERR" == "chassis_not_found" ]]; then
  pass "chassis_not_found as expected (skill layer handles Branch A)"
else
  fail "HP7 tires" "ok=False error=chassis_not_found" "ok=$OK error=$ERR"
fi

# Verify HP7 still listed as don't-stock in tire-compatibility.md.
# If this file changes, the skill-layer Branch A logic breaks for HP7.
if grep -qi "HP7" "$VAULT_ROOT/knowledge/product-rules/tire-compatibility.md"; then
  pass "HP7 listed in tire-compatibility.md don't-stock rule"
else
  fail "HP7 rule presence" "HP7 mentioned in tire-compatibility.md" "not found"
fi

# ----------------------------------------------------------------------
# Case 3: "armature" alone (ambiguous token-subset)
#   Expected: chassis_not_found. Six "Armatures" categories exist;
#   token-subset matches all of them → not unique → resolver returns None.
#   This prevents the resolver from silently picking one at random.
echo "Case 3: 'armature' alone (ambiguous → must NOT guess)"
OUT=$(bash "$WC" find --chassis "armature" --part "x" --limit 3 2>&1)
OK=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok'))")
ERR=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('error'))")
if [[ "$OK" == "False" && "$ERR" == "chassis_not_found" ]]; then
  pass "ambiguous input correctly refused (no silent guess)"
else
  fail "'armature' alone" "ok=False error=chassis_not_found" "ok=$OK error=$ERR"
fi

# ----------------------------------------------------------------------
# Case 4: Mega G+ rear tires (positive control)
#   Expected: resolver hits SEED_ALIASES ("mega g+" → 89).
#   Expected: count > 0 (real products exist).
echo "Case 4: Mega G+ rear tires (positive control)"
OUT=$(bash "$WC" find --chassis "Mega G+" --part "rear tires" --limit 5 2>&1)
OK=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok'))")
CAT=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('category_id'))")
COUNT=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('count'))")
if [[ "$OK" == "True" && "$CAT" == "89" && "$COUNT" -gt 0 ]]; then
  pass "resolved to category 89, count=$COUNT"
else
  fail "Mega G+ rear tires" "ok=True category_id=89 count>0" "ok=$OK category_id=$CAT count=$COUNT"
fi

# ----------------------------------------------------------------------
# Case 5: G Plus (token-subset uniqueness)
#   Expected: token-subset {g, plus} matches uniquely to "Aurora G-Plus"
#   (id=522). "Mega G+" normalizes to tokens {mega, g, plus} — SUPERSET
#   of the input, so it does NOT match (input must be subset of category).
#   This proves the token-subset layer works beyond the explicit aliases.
echo "Case 5: 'G Plus' alone (token-subset to unique category)"
OUT=$(bash "$WC" find --chassis "G Plus" --part "magnets" --limit 5 2>&1)
OK=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok'))")
CAT=$(echo "$OUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('category_id'))")
if [[ "$OK" == "True" && "$CAT" == "522" ]]; then
  pass "token-subset resolved 'G Plus' to category 522"
else
  fail "'G Plus' token-subset" "ok=True category_id=522" "ok=$OK category_id=$CAT"
fi

# ----------------------------------------------------------------------
# Summary
echo
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
