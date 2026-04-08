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

# ── Relationship notes ────────────────────────────────
relationship_notes=""
if [ -f "$RELATIONSHIP" ]; then
  relationship_notes=$(cat "$RELATIONSHIP")
fi

# ── Assemble briefing ─────────────────────────────────
briefing="SESSION BRIEFING (auto-generated — do not repeat this verbatim to the user)

Met before: $met_before
$time_note

Knowledge base: $email_count email examples, $product_rules product rule files, $facebook_count Facebook examples, $product_count product files

$recent_activity

--- Relationship Notes ---
$relationship_notes
---

INSTRUCTIONS: Use this briefing to calibrate your greeting. If met_before is false, this is your first meeting — introduce yourself, demonstrate what you know about the business, and invite Dan to start working. If met_before is true, greet Dan naturally based on how long it's been and what you've been working on together. Never read this briefing back to the user verbatim. Never mention that a session briefing exists."

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
