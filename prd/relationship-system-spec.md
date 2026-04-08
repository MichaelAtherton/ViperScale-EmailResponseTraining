# Technical Spec: Relationship Awareness System

**Date:** 2026-04-08
**Author:** Michael Atherton / AI Revolution Labs
**Vault:** Viper Scale Racing — Client Second Brain
**Status:** Final — ready for implementation
**Depends on:** `prd/relationship-system-design.md` (approved)

---

## Goals

1. **The first meeting problem is solved mechanically.** The SessionStart hook injects context before Claude generates anything. No reliance on Claude reading files.
2. **The relationship file is enrichment, not foundation.** Git data provides the reliable backbone. The relationship file adds the human layer.
3. **No state machine.** Claude reads the relationship data and calibrates naturally. No enum, no phase transitions.

---

## File 1: `.claude/src/relationship.md`

### Purpose
Marsh's memory of the relationship. Read by the SessionStart hook and by Marsh during sessions. Written to by Marsh at natural moments.

### Starting Content

```markdown
# Marsh & Dan

## First Meeting
[not yet]

## How Dan Likes to Work
[learning]

## Notable Moments
[none yet]
```

### Behavior

- **"First Meeting"** starts as `[not yet]`. After Marsh's first introduction, he writes the date and a brief note: `2026-04-14 — Met Dan. Showed him what I know about the business. He started by pasting a tire compatibility email.`
- **"How Dan Likes to Work"** accumulates preferences: `Dan pastes emails without preamble — just goes straight into it.` or `Dan prefers short greetings, doesn't want a recap every session.`
- **"Notable Moments"** captures milestones and inside references: `First email Dan sent without editing my draft (tire compatibility question).` or `Dan taught me that "Cortin" is a misspelling of Core 10 — customers do this all the time.`

### Why this structure
Three sections, all plain language. No metadata, no timestamps on every entry (unless natural), no structured fields. Marsh reads this like notes a coworker left on a sticky pad. Claude is good at extracting meaning from unstructured text — we don't need to impose structure.

---

## File 2: `.claude/hooks/session-briefing.sh`

### Purpose
Runs on SessionStart. Gathers context from git data and relationship.md. Outputs JSON with `additionalContext` that gets injected into Claude's conversation context before any response.

### Script

```bash
#!/bin/bash
# Session briefing — generates context for Marsh before first response
# Injected via SessionStart hook additionalContext

VAULT_ROOT="$CLAUDE_PROJECT_DIR"
RELATIONSHIP="$VAULT_ROOT/.claude/src/relationship.md"

cd "$VAULT_ROOT" || exit 0

# ── Has Marsh met Dan before? ──────────────────────────
met_before="false"
first_meeting_line=""
if [ -f "$RELATIONSHIP" ]; then
  first_meeting_line=$(grep -A1 "## First Meeting" "$RELATIONSHIP" | tail -1)
  # If the line after "## First Meeting" contains a date (starts with 20) or isn't a placeholder
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
resource_links=0
if [ -f "knowledge/resources/links.md" ]; then
  resource_links=$(grep -c "^- \|^### \|http" knowledge/resources/links.md 2>/dev/null | tr -d ' ')
fi

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
```

### Design Decisions

**Why jq with plain text fallback:**
JSON encoding in pure bash (sed-based escaping) is fragile — special characters in git messages or relationship notes can break the JSON. `jq` handles all escaping reliably. If `jq` isn't available (some Windows environments), the script falls back to plain text stdout, which the docs confirm is also added as context for SessionStart hooks.

**Why "do not repeat this verbatim":**
Without this instruction, Claude might dump the briefing into the conversation. The briefing is context for Claude's behavior, not content for Dan to see.

**Why grep for dates starting with `20`:**
Simple heuristic — if the line after "## First Meeting" starts with a year (2024, 2025, 2026...), Marsh has met Dan. If it's `[not yet]` or empty, he hasn't. No complex parsing needed.

**Why `startup|compact` matcher:**
The briefing fires on new sessions (`startup`) and after context compaction (`compact`). Compaction discards earlier context — without re-injection, Marsh's relationship awareness disappears mid-session during long conversations. Re-injecting after compaction is cheap (small text payload) and ensures Marsh stays in character.

---

## File 3: `.claude/settings.json` (update)

### Current State

```json
{
  "permissions": {
    "allow": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git pull:*)"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/auto-commit.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-sync.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Proposed Change

Add the session-briefing hook to SessionStart. The existing session-sync hook stays (it does git pull). The briefing hook runs after sync so it reads the latest data.

```json
{
  "permissions": {
    "allow": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git pull:*)"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/auto-commit.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-sync.sh",
            "timeout": 30
          }
        ]
      },
      {
        "matcher": "startup|compact",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-briefing.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Design Decisions

**Why a separate matcher group for the briefing:**
session-sync has `"matcher": ""` (fires on all session types including resume and compact). session-briefing has `"matcher": "startup|compact"` (fires on new sessions and after compaction). Different matchers for different purposes.

**Why two hooks instead of combining into one script:**
session-sync does git operations (pull, rebase recovery). session-briefing does context generation. Different concerns, different matchers. If one fails, the other still runs.

**Hook execution order — parallel, not sequential:**
The docs state "All matching hooks run in parallel." On startup, both session-sync and session-briefing fire at the same time. This means session-briefing may read git data before session-sync finishes its `git pull`. This is acceptable because:
- The briefing cares about LOCAL session history (Dan's last session, what Dan worked on) — not remote changes being pulled
- Remote changes pulled by session-sync will be visible to Claude once it reads vault files during the conversation
- The worst case is the briefing misses a remote change that JUST happened — the next session picks it up

---

## File 4: `.claude/src/assistant-persona.md` (update)

### What Changes

Add a new section after "How I Work" called "Remembering Our Relationship":

```markdown
## Remembering Our Relationship

A session briefing is injected into your context at the start of every new session. It tells you whether you've met the user before, how long it's been, what you've been working on, and any relationship notes. Use it to calibrate your greeting — don't read it back verbatim.

When something notable happens during a session, update `.claude/src/relationship.md`:

- **First meeting:** After your first introduction, write the date and a brief note under "## First Meeting". Example: `2026-04-14 — Met Dan. He jumped straight into pasting a customer email about tire compatibility.`

- **Working preferences:** When you notice how Dan likes to work, add it under "## How Dan Likes to Work". Example: `Dan doesn't want a recap of recent activity every session — he just wants to get to work.`

- **Notable moments:** Milestones, breakthroughs, inside references. Example: `Dan laughed when I got the Magnet Traction answer right on the first try — "you're learning, Marsh."`

Don't force this. Don't update the file after every interaction. Just the moments that a good coworker would actually remember. If nothing notable happens in a session, don't write anything — that's fine.
```

### Design Decision

**Why "don't force this":**
If we instruct Marsh to journal every session, the file becomes a log. Logs aren't relationships. The instruction is to write when something matters, which produces a sparse, meaningful file that Claude can read and actually use to calibrate warmth.

---

## File 5: `CLAUDE.md` (update)

### What Changes

Replace the current "On Session Start" section. The hook now handles context injection, so CLAUDE.md's startup sequence simplifies:

```markdown
## On Session Start

1. Read `.claude/src/assistant-persona.md` — this is who you are and how you work.
2. Read `.claude/src/guardrails.md` — non-negotiable rules. Follow them always.
3. A session briefing has been injected into your context by the SessionStart hook. It contains:
   - Whether you've met the user before
   - How long since the last session
   - Recent vault activity
   - Knowledge base size
   - Your relationship notes

Use the briefing to calibrate your greeting:

### First Meeting (briefing says "Met before: false")
Introduce yourself — name, nickname, role. Demonstrate what you already know about the business by citing specific facts from the vault. Invite the user to start working. Do NOT list commands or suggest /onboard.

### Returning (briefing says "Met before: true")
Greet naturally based on how long it's been and your relationship notes. Reference recent activity if relevant. Be ready to work. The greeting should feel like a colleague who recognizes you, not a tool that rebooted.

### Empty Vault (business-profile.md has no real content)
Introduce yourself and explain the concept. Start by asking about the business or invite them to paste a customer message. Learn as you go.
```

### Design Decision

**Why step 3 says "has been injected" not "read this file":**
The briefing is already in Claude's context via the hook. Claude doesn't need to read a file — the data is there. This eliminates the failure mode from our test where Claude skipped the file reads.

**Why we still keep steps 1 and 2 (read persona, read guardrails):**
The persona file contains the working style and voice guidelines — Claude needs these to behave correctly throughout the session, not just for the greeting. The guardrails are non-negotiable rules. These are worth reading even if there's a small risk of Claude responding before reading them, because the hook-injected briefing handles the greeting reliability. The persona and guardrails shape ongoing behavior, not just the first response.

---

## File 6: `.claude/scripts/smoke-test.sh` (update)

### New Checks to Add

```
10. RELATIONSHIP SYSTEM
─────────────────────────────────────────
  ✓ .claude/src/relationship.md exists and non-empty
  ✓ .claude/hooks/session-briefing.sh exists and executable
  ✓ .claude/hooks/session-briefing.sh has bash shebang
  ✓ .claude/hooks/session-briefing.sh has no python dependency
  ✓ settings.json has SessionStart hook for session-briefing.sh
  ✓ session-briefing.sh outputs valid JSON (dry run)
```

### Dry Run Test

Run the briefing script and validate it produces output (JSON if jq available, plain text otherwise):

```bash
output=$(cd "$VAULT_ROOT" && CLAUDE_PROJECT_DIR="$VAULT_ROOT" bash .claude/hooks/session-briefing.sh < /dev/null 2>/dev/null)
if [ -n "$output" ]; then
  # Check if it's valid JSON (preferred) or plain text (fallback)
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
```

---

## Implementation Order

1. Create `.claude/src/relationship.md`
2. Create `.claude/hooks/session-briefing.sh` + make executable
3. Update `.claude/settings.json` with new SessionStart hook
4. Update `.claude/src/assistant-persona.md` with "Remembering Our Relationship"
5. Update `CLAUDE.md` startup sequence
6. Update `.claude/scripts/smoke-test.sh`
7. Run smoke test
8. Test: start a fresh session and verify first-meeting greeting fires correctly
9. Commit and push

---

## What This Spec Does NOT Cover

- **SessionEnd transcript summarization** — Phase 2. Would use transcript_path to auto-generate session notes.
- **UserPromptSubmit context injection** — evaluated and deemed unnecessary. SessionStart briefing is sufficient.
- **Stop hook for forced journaling** — evaluated and rejected. Marsh journals voluntarily per persona instructions.
- **Relationship stage enum** — intentionally omitted. Claude calibrates naturally from the data.
