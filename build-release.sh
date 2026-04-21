#!/usr/bin/env bash
# Build a release zip for the Enzo installer.
# Run from the viper-second-brain project root.
#
# Usage: bash build-release.sh [version]
#   e.g.: bash build-release.sh 1.0.0

set -euo pipefail

VERSION="${1:-1.0.0}"
RELEASE_DIR="/tmp/viper-release-$$"
ZIP_NAME="viper-second-brain-v${VERSION}.zip"

echo "=== Building Enzo Installer v${VERSION} ==="

# ── Step 1: Clean slate via git archive ────────────────────
echo "[1/7] Exporting from git..."
mkdir -p "$RELEASE_DIR"
git archive HEAD | tar -x -C "$RELEASE_DIR"

# ── Step 2: Apply exclude list ─────────────────────────────
echo "[2/7] Removing excluded files..."
rm -rf "$RELEASE_DIR"/audit
rm -rf "$RELEASE_DIR"/prd
rm -rf "$RELEASE_DIR"/scratch
rm -rf "$RELEASE_DIR"/doc
rm -rf "$RELEASE_DIR"/.obsidian
rm -rf "$RELEASE_DIR"/docs
rm -f  "$RELEASE_DIR"/build-release.sh
rm -f  "$RELEASE_DIR"/scripts/wc-*.sh
rm -rf "$RELEASE_DIR"/integrations/woocommerce/.venv
rm -rf "$RELEASE_DIR"/integrations/woocommerce/__pycache__
rm -f  "$RELEASE_DIR"/.claude/settings.local.json
rm -rf "$RELEASE_DIR"/.claude/cache
rm -rf "$RELEASE_DIR"/.claude/logs
rm -f  "$RELEASE_DIR"/.claude/hooks/error.log
rm -f  "$RELEASE_DIR"/.env
rm -f  "$RELEASE_DIR"/.env.*
rm -f  "$RELEASE_DIR"/WOOCOMMERCE-INTEGRATION-HANDOFF.md

# Copy launcher/win/ files to zip root (source org → flat ship layout)
cp "$RELEASE_DIR"/launcher/win/* "$RELEASE_DIR"/ 2>/dev/null || true
rm -rf "$RELEASE_DIR"/launcher

find "$RELEASE_DIR" -name "*.pyc" -delete
find "$RELEASE_DIR" -name ".DS_Store" -delete
find "$RELEASE_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# ── Step 3: Apply ship-time edits ──────────────────────────
echo "[3/7] Applying ship-time edits..."

# Reset relationship.md first_met to null
if [[ -f "$RELEASE_DIR/.claude/src/relationship.md" ]]; then
  sed -i '' 's/^first_met: .*/first_met: null/' "$RELEASE_DIR/.claude/src/relationship.md"
  echo "  relationship.md: first_met reset to null"
fi

# Ensure outputs/ dir exists (empty)
mkdir -p "$RELEASE_DIR/outputs"

# ── Step 4: Grep sweep ─────────────────────────────────────
echo "[4/7] Running grep sweep..."
FAIL=0

if grep -r "/Users/michaelatherton" "$RELEASE_DIR" --include="*.md" --include="*.json" --include="*.sh" --include="*.py" --include="*.cmd" --include="*.bat" 2>/dev/null; then
  echo "FAIL: Found /Users/michaelatherton in release files"
  FAIL=1
fi

if grep -ri -E '\bmarshall\b|\bmarsh\b' "$RELEASE_DIR" --include="*.md" --include="*.json" --include="*.sh" 2>/dev/null | grep -v "Notable Moments" | grep -v "renamed me from"; then
  echo "FAIL: Found Marshall/Marsh references in release files"
  FAIL=1
fi

if [[ $FAIL -ne 0 ]]; then
  echo "=== BUILD FAILED — fix the above before releasing ==="
  rm -rf "$RELEASE_DIR"
  exit 1
fi
echo "  Grep sweep passed"

# ── Step 5: Assert settings.json ───────────────────────────
echo "[5/7] Validating settings.json..."
SETTINGS="$RELEASE_DIR/.claude/settings.json"
for rule in 'Bash(bash scripts/wc.sh' 'Bash(python -m integrations.woocommerce.cli' 'Skill(draft-reply)' 'Skill(teach)' 'Skill(catalog-lookup)'; do
  if ! grep -q "$rule" "$SETTINGS"; then
    echo "FAIL: settings.json missing rule: $rule"
    rm -rf "$RELEASE_DIR"
    exit 1
  fi
done

if [[ -f "$RELEASE_DIR/.claude/settings.local.json" ]]; then
  echo "FAIL: settings.local.json should not be in the release"
  rm -rf "$RELEASE_DIR"
  exit 1
fi
echo "  settings.json validated"

# ── Step 6: Zip ────────────────────────────────────────────
echo "[6/7] Creating zip..."
cd "$RELEASE_DIR"
zip -r "/tmp/$ZIP_NAME" . -x '*.DS_Store' > /dev/null
cd - > /dev/null

# ── Step 7: Summary ────────────────────────────────────────
echo "[7/7] Release built:"
echo "  File: /tmp/$ZIP_NAME"
echo "  Size: $(du -h "/tmp/$ZIP_NAME" | cut -f1)"
echo ""
echo "  File count: $(unzip -l "/tmp/$ZIP_NAME" | tail -1 | awk '{print $2}')"
echo ""
echo "  Upload to: https://github.com/MichaelAtherton/ViperScale-EmailResponseTraining/releases/new"
echo "  Tag: v${VERSION}"

# Cleanup
rm -rf "$RELEASE_DIR"
echo ""
echo "=== Done ==="
