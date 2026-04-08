#!/bin/bash
# First meeting flag — runs on Stop event
# Flips first_met in relationship.md frontmatter from null to today's date
# Commits the change to git so it persists across sessions
# Deterministic — no LLM involvement

VAULT_ROOT="$CLAUDE_PROJECT_DIR"
RELATIONSHIP="$VAULT_ROOT/.claude/src/relationship.md"

# Only proceed if relationship file exists
[ -f "$RELATIONSHIP" ] || exit 0

# Check if first_met is still null — if not, nothing to do
grep -q "^first_met: null" "$RELATIONSHIP" || exit 0

# Replace null with today's date
TODAY=$(date '+%Y-%m-%d')
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/^first_met: null$/first_met: ${TODAY}/" "$RELATIONSHIP"
else
  sed -i "s/^first_met: null$/first_met: ${TODAY}/" "$RELATIONSHIP"
fi

# Commit the change so it persists
cd "$VAULT_ROOT" || exit 0
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  git add .claude/src/relationship.md
  git commit -m "vsr: first meeting — ${TODAY}" 2>/dev/null
fi

exit 0
