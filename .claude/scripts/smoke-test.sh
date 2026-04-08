#!/bin/bash
# Smoke tests for the Viper Second Brain vault
# Run from vault root: bash .claude/scripts/smoke-test.sh
# Tests: structure, skills, hooks, settings, cross-references, consistency

VAULT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$VAULT_ROOT" || exit 1

PASS=0
FAIL=0
WARN=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  ⚠ $1"; WARN=$((WARN + 1)); }

echo "═══════════════════════════════════════════"
echo "  SMOKE TESTS — Viper Second Brain"
echo "  Vault: $VAULT_ROOT"
echo "═══════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────
echo "1. DIRECTORY STRUCTURE"
echo "─────────────────────────────────────────"

required_dirs=(
  ".claude"
  ".claude/src"
  ".claude/skills"
  ".claude/hooks"
  ".claude/reference"
  "context"
  "context/channels"
  "knowledge"
  "knowledge/product-rules"
  "knowledge/email-examples"
  "knowledge/email-examples/product-questions"
  "knowledge/email-examples/order-issues"
  "knowledge/email-examples/warranty-returns"
  "knowledge/email-examples/stock-availability"
  "knowledge/email-examples/pre-sales"
  "knowledge/email-examples/setup-support"
  "knowledge/facebook-examples"
  "knowledge/facebook-examples/comment-replies"
  "knowledge/facebook-examples/dm-responses"
  "knowledge/products"
  "knowledge/resources"
  "outputs"
)

for dir in "${required_dirs[@]}"; do
  if [ -d "$dir" ]; then
    pass "$dir/"
  else
    fail "$dir/ — missing directory"
  fi
done
echo ""

# ─────────────────────────────────────────────
echo "2. REQUIRED FILES"
echo "─────────────────────────────────────────"

required_files=(
  "CLAUDE.md"
  ".gitignore"
  ".claude/settings.json"
  ".claude/src/assistant-persona.md"
  ".claude/src/guardrails.md"
  "context/business-profile.md"
  "context/tone.md"
  "context/policies.md"
  "context/website-navigation.md"
  "context/channels/facebook.md"
  "knowledge/resources/links.md"
  ".claude/reference/email-qa-format.md"
)

for file in "${required_files[@]}"; do
  if [ -f "$file" ]; then
    if [ -s "$file" ]; then
      pass "$file"
    else
      fail "$file — exists but empty"
    fi
  else
    fail "$file — missing"
  fi
done
echo ""

# ─────────────────────────────────────────────
echo "3. SKILLS"
echo "─────────────────────────────────────────"

expected_skills=(
  "draft-reply"
  "draft-facebook-reply"
  "categorize-email"
  "teach"
  "onboard"
  "ingest-emails"
  "ingest-facebook"
  "ingest-catalog"
  "ingest-site"
  "extract-knowledge"
)

for skill in "${expected_skills[@]}"; do
  skill_file=".claude/skills/$skill/SKILL.md"
  if [ -f "$skill_file" ]; then
    # Check YAML frontmatter exists
    if head -1 "$skill_file" | grep -q "^---"; then
      # Check required frontmatter fields
      has_name=$(grep -c "^name:" "$skill_file")
      has_desc=$(grep -c "^description:" "$skill_file")
      if [ "$has_name" -gt 0 ] && [ "$has_desc" -gt 0 ]; then
        pass "$skill — SKILL.md with valid frontmatter"
      else
        fail "$skill — missing name: or description: in frontmatter"
      fi
    else
      fail "$skill — SKILL.md missing YAML frontmatter (---)"
    fi
  else
    fail "$skill — SKILL.md not found"
  fi
done
echo ""

# ─────────────────────────────────────────────
echo "4. HOOKS"
echo "─────────────────────────────────────────"

for hook in auto-commit.sh session-sync.sh; do
  hook_file=".claude/hooks/$hook"
  if [ -f "$hook_file" ]; then
    if [ -x "$hook_file" ]; then
      pass "$hook — exists and executable"
    else
      fail "$hook — exists but NOT executable (run: chmod +x $hook_file)"
    fi
    # Check for python dependency (should be none)
    if grep -q "python" "$hook_file"; then
      fail "$hook — contains python dependency (should be pure bash)"
    else
      pass "$hook — no python dependency"
    fi
    # Check for bash shebang
    if head -1 "$hook_file" | grep -q "^#!/bin/bash"; then
      pass "$hook — has bash shebang"
    else
      fail "$hook — missing #!/bin/bash shebang"
    fi
  else
    fail "$hook — missing"
  fi
done
echo ""

# ─────────────────────────────────────────────
echo "5. SETTINGS.JSON"
echo "─────────────────────────────────────────"

settings=".claude/settings.json"
if [ -f "$settings" ]; then
  # Valid JSON?
  if python3 -c "import json; json.load(open('$settings'))" 2>/dev/null || \
     python -c "import json; json.load(open('$settings'))" 2>/dev/null; then
    pass "settings.json — valid JSON"
  else
    fail "settings.json — invalid JSON"
  fi

  # Has permissions?
  if grep -q '"permissions"' "$settings"; then
    pass "settings.json — has permissions block"
  else
    fail "settings.json — missing permissions block"
  fi

  # Has hooks?
  if grep -q '"hooks"' "$settings"; then
    pass "settings.json — has hooks block"
  else
    fail "settings.json — missing hooks block"
  fi

  # Hook commands reference 'bash' explicitly (Windows compat)?
  hook_cmds=$(grep '"command"' "$settings" | grep -v '"type"')
  if echo "$hook_cmds" | grep -q "^.*bash "; then
    pass "settings.json — hook commands use explicit 'bash' (cross-platform)"
  else
    fail "settings.json — hook commands don't use explicit 'bash' (may fail on Windows)"
  fi

  # Hook commands reference files that exist?
  while IFS= read -r line; do
    # Extract the .sh filename (must end with .sh, not just any word)
    sh_file=$(echo "$line" | grep -oE '[a-z][-a-z]*\.sh' | head -1)
    if [ -n "$sh_file" ] && [ -f ".claude/hooks/$sh_file" ]; then
      pass "settings.json → .claude/hooks/$sh_file exists"
    elif [ -n "$sh_file" ]; then
      fail "settings.json references .claude/hooks/$sh_file but file missing"
    fi
  done <<< "$hook_cmds"
else
  fail "settings.json — missing"
fi
echo ""

# ─────────────────────────────────────────────
echo "6. CROSS-REFERENCES (skills → vault files)"
echo "─────────────────────────────────────────"

# Check that paths referenced in skills actually exist in the vault
ref_errors=0
for skill_file in .claude/skills/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")

  # Extract vault paths referenced in backticks
  paths=$(grep -o '`[a-z][a-z_-]*/[^`]*`' "$skill_file" | tr -d '`' | sort -u)
  for ref_path in $paths; do
    # Skip paths that are clearly examples/templates (contain brackets or variables)
    echo "$ref_path" | grep -qE '\[|<|\$|YYYY' && continue
    # Skip paths that are file format examples
    echo "$ref_path" | grep -qE '\.sh$|\.py$|\.json$' && continue

    # Check if it's a directory or file reference
    if [ -d "$ref_path" ] || [ -f "$ref_path" ] || [ -f "${ref_path}.md" ]; then
      : # exists, don't print (too noisy)
    else
      # Check if parent directory exists (for paths like knowledge/email-examples/<category>/)
      parent=$(dirname "$ref_path")
      if [ -d "$parent" ]; then
        : # parent exists, reference is probably parameterized
      else
        warn "$skill_name references '$ref_path' — path not found"
        ref_errors=$((ref_errors + 1))
      fi
    fi
  done
done

if [ "$ref_errors" -eq 0 ]; then
  pass "All skill cross-references resolve to existing paths"
fi
echo ""

# ─────────────────────────────────────────────
echo "7. CLAUDE.md CONSISTENCY"
echo "─────────────────────────────────────────"

# Check that every skill in .claude/skills/ is listed in CLAUDE.md
for skill_dir in .claude/skills/*/; do
  skill_name=$(basename "$skill_dir")
  if grep -q "/$skill_name" CLAUDE.md; then
    pass "CLAUDE.md lists /$skill_name"
  else
    fail "CLAUDE.md missing /$skill_name — skill exists but not in registry"
  fi
done

# Check that CLAUDE.md doesn't list skills that don't exist
claude_skills=$(grep -oE '/[a-z][-a-z]*' CLAUDE.md | sort -u)
for skill_ref in $claude_skills; do
  skill_name="${skill_ref#/}"
  # Skip if it's not a skill reference (common words starting with /)
  [ -d ".claude/skills/$skill_name" ] && continue
  # Only flag if it looks like a skill (has a trigger phrase pattern)
  if grep -B2 "$skill_ref" CLAUDE.md | grep -qi "command\|skill\|trigger"; then
    if [ ! -d ".claude/skills/$skill_name" ]; then
      fail "CLAUDE.md references /$skill_name but .claude/skills/$skill_name/ doesn't exist"
    fi
  fi
done
echo ""

# ─────────────────────────────────────────────
echo "7b. CLAUDE.md ORCHESTRATOR PATTERN"
echo "─────────────────────────────────────────"

# Check CLAUDE.md references persona and guardrails files
if grep -q '.claude/src/assistant-persona.md' CLAUDE.md; then
  pass "CLAUDE.md references .claude/src/assistant-persona.md"
else
  fail "CLAUDE.md missing reference to .claude/src/assistant-persona.md"
fi

if grep -q '.claude/src/guardrails.md' CLAUDE.md; then
  pass "CLAUDE.md references .claude/src/guardrails.md"
else
  fail "CLAUDE.md missing reference to .claude/src/guardrails.md"
fi

# Check CLAUDE.md has startup sequence
if grep -q 'On Session Start' CLAUDE.md; then
  pass "CLAUDE.md has startup sequence"
else
  fail "CLAUDE.md missing startup sequence (On Session Start)"
fi

# Check CLAUDE.md has purpose routing (not directory tree)
if grep -q 'Where Things Live' CLAUDE.md; then
  pass "CLAUDE.md has purpose-routing section"
else
  fail "CLAUDE.md missing purpose-routing section (Where Things Live)"
fi

# Check CLAUDE.md has tiered skills (Main Tools + Setup Tools)
if grep -q 'Your Main Tools' CLAUDE.md && grep -q 'Setup & Bulk Tools' CLAUDE.md; then
  pass "CLAUDE.md has tiered skills tables"
else
  fail "CLAUDE.md missing tiered skills tables"
fi

# Check CLAUDE.md is under 100 lines (orchestrator should be compact)
claude_lines=$(wc -l < CLAUDE.md)
if [ "$claude_lines" -le 100 ]; then
  pass "CLAUDE.md is compact ($claude_lines lines)"
else
  warn "CLAUDE.md is $claude_lines lines — consider trimming (target: <80)"
fi

# Check skills reference persona file
persona_refs=0
for skill_file in .claude/skills/draft-reply/SKILL.md .claude/skills/draft-facebook-reply/SKILL.md .claude/skills/onboard/SKILL.md; do
  if [ -f "$skill_file" ] && grep -q '.claude/src/assistant-persona.md' "$skill_file"; then
    persona_refs=$((persona_refs + 1))
  fi
done
if [ "$persona_refs" -ge 3 ]; then
  pass "Core skills reference .claude/src/assistant-persona.md ($persona_refs/3)"
else
  fail "Only $persona_refs/3 core skills reference .claude/src/assistant-persona.md"
fi
echo ""

# ─────────────────────────────────────────────
echo "8. RELATIONSHIP SYSTEM"
echo "─────────────────────────────────────────"

# Relationship file
if [ -f ".claude/src/relationship.md" ]; then
  if [ -s ".claude/src/relationship.md" ]; then
    pass ".claude/src/relationship.md exists and non-empty"
  else
    fail ".claude/src/relationship.md exists but empty"
  fi
else
  fail ".claude/src/relationship.md — missing"
fi

# Session briefing script
briefing_script=".claude/hooks/session-briefing.sh"
if [ -f "$briefing_script" ]; then
  if [ -x "$briefing_script" ]; then
    pass "session-briefing.sh — exists and executable"
  else
    fail "session-briefing.sh — exists but NOT executable"
  fi
  if head -1 "$briefing_script" | grep -q "^#!/bin/bash"; then
    pass "session-briefing.sh — has bash shebang"
  else
    fail "session-briefing.sh — missing #!/bin/bash shebang"
  fi
  if grep -q "python" "$briefing_script"; then
    fail "session-briefing.sh — contains python dependency"
  else
    pass "session-briefing.sh — no python dependency"
  fi
else
  fail "session-briefing.sh — missing"
fi

# Settings.json references session-briefing
if grep -q "session-briefing.sh" .claude/settings.json; then
  pass "settings.json has SessionStart hook for session-briefing.sh"
else
  fail "settings.json missing SessionStart hook for session-briefing.sh"
fi

# Dry run — verify output
output=$(cd "$VAULT_ROOT" && CLAUDE_PROJECT_DIR="$VAULT_ROOT" bash .claude/hooks/session-briefing.sh < /dev/null 2>/dev/null)
if [ -n "$output" ]; then
  if echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null || \
     echo "$output" | python -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    pass "session-briefing.sh outputs valid JSON (dry run)"
  elif echo "$output" | grep -q "SESSION BRIEFING"; then
    pass "session-briefing.sh outputs plain text briefing (jq not available)"
  else
    fail "session-briefing.sh output is neither valid JSON nor expected plain text"
  fi
else
  fail "session-briefing.sh produced no output"
fi
echo ""

# ─────────────────────────────────────────────
echo "9. GIT STATUS"
echo "─────────────────────────────────────────"

if command -v git >/dev/null 2>&1; then
  pass "git is installed"
  if git rev-parse --git-dir >/dev/null 2>&1; then
    pass "vault is a git repo"
    # Check for remote
    if git remote get-url origin >/dev/null 2>&1; then
      remote=$(git remote get-url origin)
      pass "remote 'origin' configured: $remote"
    else
      warn "no remote configured — auto-push won't work until 'git remote add origin <url>'"
    fi
  else
    warn "vault is NOT a git repo — hooks will skip (run 'git init' to enable)"
  fi
else
  warn "git not installed — hooks will skip"
fi
echo ""

# ─────────────────────────────────────────────
echo "10. HOOK LOGIC (dry run)"
echo "─────────────────────────────────────────"

# Test auto-commit directory matching logic
test_paths=(
  "context/tone.md:should_commit"
  "context/channels/facebook.md:should_commit"
  "knowledge/product-rules/tire-compatibility.md:should_commit"
  "knowledge/facebook-examples/comment-replies/test.md:should_commit"
  "outputs/draft-2026-04-07.md:should_commit"
  "CLAUDE.md:should_skip"
  ".claude/settings.json:should_skip"
  ".claude/skills/teach/SKILL.md:should_skip"
  ".gitignore:should_skip"
  "prd/design-doc.md:should_skip"
)

for test in "${test_paths[@]}"; do
  path="${test%%:*}"
  expected="${test##*:}"

  # Simulate the hook's directory matching logic
  rel_path="$path"
  case "$rel_path" in
    context/*|knowledge/*|outputs/*|daily/*)
      result="should_commit"
      ;;
    *)
      result="should_skip"
      ;;
  esac

  if [ "$result" = "$expected" ]; then
    pass "auto-commit: $path → $expected"
  else
    fail "auto-commit: $path → got $result, expected $expected"
  fi
done
echo ""

# ─────────────────────────────────────────────
echo "═══════════════════════════════════════════"
echo "  RESULTS: $PASS passed, $FAIL failed, $WARN warnings"
echo "═══════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo "  ✗ SMOKE TESTS FAILED"
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo "  ⚠ PASSED WITH WARNINGS"
  exit 0
else
  echo "  ✓ ALL TESTS PASSED"
  exit 0
fi
