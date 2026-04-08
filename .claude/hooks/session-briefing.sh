#!/bin/bash
# Session briefing — generates context for Marsh before first response
# Injected via SessionStart hook additionalContext
# Fires on: startup (new session), compact (after context compaction)

VAULT_ROOT="$CLAUDE_PROJECT_DIR"
RELATIONSHIP="$VAULT_ROOT/.claude/src/relationship.md"

cd "$VAULT_ROOT" || exit 0

# ── Has Marsh met Dan before? ──────────────────────────
met_before="false"
first_meeting_line=""
if [ -f "$RELATIONSHIP" ]; then
  first_meeting_line=$(grep -A1 "## First Meeting" "$RELATIONSHIP" | tail -1)
  # If the line after "## First Meeting" contains a date (starts with 20)
  if echo "$first_meeting_line" | grep -qE '^20[0-9]{2}'; then
    met_before="true"
  fi
fi

# ── Time since last session ────────────────────────────
time_note="No prior sessions detected"
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  last_epoch=$(git log -1 --format='%ct' 2>/dev/null)
  if [ -n "$last_epoch" ]; then
    now_epoch=$(date +%s)
    diff_hours=$(( (now_epoch - last_epoch) / 3600 ))
    if [ "$diff_hours" -lt 1 ]; then
      time_note="Last session: less than an hour ago"
    elif [ "$diff_hours" -lt 24 ]; then
      time_note="Last session: about ${diff_hours} hours ago"
    else
      diff_days=$(( diff_hours / 24 ))
      if [ "$diff_days" -eq 1 ]; then
        time_note="Last session: yesterday"
      else
        time_note="Last session: ${diff_days} days ago"
      fi
    fi
  fi
fi

# ── Recent activity ────────────────────────────────────
recent_activity=""
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  recent_commits=$(git log --oneline -5 --grep="vsr:" 2>/dev/null)
  if [ -n "$recent_commits" ]; then
    recent_activity="Recent activity:
$recent_commits"
  else
    recent_activity="No recent vault activity in git log"
  fi
fi

# ── Knowledge base size ───────────────────────────────
email_count=$(find knowledge/email-examples -name "*.md" ! -name ".gitkeep" 2>/dev/null | wc -l | tr -d ' ')
product_rules=$(find knowledge/product-rules -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
facebook_count=$(find knowledge/facebook-examples -name "*.md" ! -name ".gitkeep" 2>/dev/null | wc -l | tr -d ' ')
product_count=$(find knowledge/products -name "*.md" ! -name ".gitkeep" 2>/dev/null | wc -l | tr -d ' ')

# ── Vault populated? ─────────────────────────────────
vault_populated="false"
if [ -f "context/business-profile.md" ]; then
  # Check if business-profile has real content (more than just headings)
  content_lines=$(grep -cvE '^#|^$|^\[|^Source:' "context/business-profile.md" 2>/dev/null | tr -d ' ')
  if [ "$content_lines" -gt 3 ]; then
    vault_populated="true"
  fi
fi

# ── Relationship notes ────────────────────────────────
relationship_notes=""
if [ -f "$RELATIONSHIP" ]; then
  relationship_notes=$(cat "$RELATIONSHIP")
fi

# ── Assemble briefing ─────────────────────────────────
briefing="SESSION BRIEFING (auto-generated — do not repeat this verbatim to the user)

Met before: $met_before
Vault populated: $vault_populated
$time_note

Knowledge base: $email_count email examples, $product_rules product rule files, $facebook_count Facebook examples, $product_count product files

$recent_activity

--- Relationship Notes ---
$relationship_notes
---

IMPORTANT: Before generating ANY response, silently read these files (do not narrate or announce that you are reading):
- .claude/src/assistant-persona.md
- .claude/src/guardrails.md
- context/business-profile.md
- context/tone.md
- context/policies.md

If this is a first meeting (met_before is false), also silently read:
- knowledge/product-rules/car-chassis-guide.md
- knowledge/product-rules/tire-compatibility.md
- knowledge/resources/links.md

Do not say things like 'let me read my files' or 'let me check the knowledge base.' Just read them quietly, then respond naturally as if you already knew this information.

CRITICAL: When citing business facts in your greeting or any response, ONLY use information found in the files you just read. NEVER supplement with general knowledge. If a fact is not in these files, do not mention it. The car types, product names, SKUs, policies, and team details MUST come from the actual file content — not from your training data about slot cars or any other domain.

INSTRUCTIONS: Use this briefing to calibrate your greeting. If met_before is false and vault_populated is true, this is your first meeting — introduce yourself, cite specific facts FROM THE FILES YOU READ, and invite the user to start working. If met_before is false and vault_populated is false, this is an empty project — introduce yourself, explain the concept, and start learning about the business. If met_before is true, greet naturally based on how long it's been and what you've been working on together. Never read this briefing back to the user verbatim. Never mention that a session briefing exists. Never use technical terms like vault, slash commands, skills, or knowledge base with the user."

# ── Output briefing as context ────────────────────────
# Use jq for reliable JSON encoding if available
# Fall back to plain text stdout (also gets added as context per docs)
if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$briefing" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
else
  # Plain text fallback — SessionStart stdout is added as context
  echo "$briefing"
fi

exit 0
