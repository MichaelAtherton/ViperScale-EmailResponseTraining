# Technical Spec: Deterministic First Meeting Flag

**Date:** 2026-04-08
**Author:** Michael Atherton / AI Revolution Labs
**Vault:** Viper Scale Racing — Client Second Brain
**Status:** Approved — ready for implementation

---

## The Problem

After Marsh introduces himself for the first time, the relationship file needs to be updated so the next session knows they've already met. If this doesn't happen, Dan meets Marsh for the "first time" every session.

We've tried asking the LLM to do this update. It doesn't work reliably:
- First attempt: Marsh announced "let me update the relationship file" and showed Dan a permission dialog with a code diff
- Second attempt: Marsh was told to do it silently — he skipped it entirely
- The update never happened in any of our test sessions

The root cause: we're asking an LLM to remember to edit a file. This is probabilistic. We need it to be deterministic.

---

## The Constraint

Dan must never see:
- A file edit approval dialog
- Any mention of "relationship file"
- Any indication that system files are being modified
- Any interruption to the natural conversation flow

---

## Design Decision: Hybrid File Format

The relationship file changes from pure markdown to **YAML frontmatter + markdown body**:

```
---
first_met: null
---

## How Dan Likes to Work
[learning]

## Notable Moments
[none yet]
```

**Why hybrid:**
- The YAML frontmatter is machine-readable state. Shell scripts parse it with simple grep/sed on key-value pairs (`first_met: null` → `first_met: 2026-04-08`). Unambiguous — no risk of matching content in the wrong section.
- The markdown body is LLM-readable enrichment. Claude reads and writes freeform notes naturally.
- Scripts only touch the frontmatter. Claude only touches the markdown body. They never interfere with each other.

**Why not pure YAML or JSON:**
- Claude writes better markdown than structured data
- The relationship notes are freeform by nature — preferences, inside references, milestones
- Pure structured format would constrain what Claude can capture

**Why not pure markdown (current format):**
- Shell scripts had to grep for `[not yet]` under a markdown heading — fragile
- Risk of matching content in the wrong place if Marsh writes a note containing that text
- No clean separation between machine state and LLM content

---

## Proposed Solution: Stop Hook

Use a **Stop hook** that fires after Claude finishes responding. A shell script checks the YAML frontmatter and flips the flag automatically.

### How it works

1. Claude responds to Dan's "hello" with the first-meeting greeting
2. Claude's response completes — the **Stop hook fires**
3. The hook script reads `.claude/src/relationship.md`
4. If `first_met: null` exists in the frontmatter, the script replaces it with today's date
5. Dan sees nothing — the script runs silently after the response is displayed

### Why Stop hook

From the Claude Code hooks docs:
- **Stop** fires "when Claude finishes responding" — this is exactly the right moment
- The hook runs AFTER Dan sees the response, so there's no UI interruption
- Stop fires on every response, not just the first — so the script checks the flag each time but only writes once

### Why not other hooks

- **SessionStart** — fires too early. Marsh hasn't introduced himself yet.
- **SessionEnd** — may not fire if Dan closes the window. We want the flag flipped immediately.
- **PostToolUse** — fires after tool calls, not after text responses. The greeting is text.

---

## The Script: `.claude/hooks/first-meeting-check.sh`

```bash
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
# Auto-commit hook won't catch this (only fires on Write/Edit tool calls,
# and only for context/|knowledge/|outputs/ paths)
cd "$VAULT_ROOT" || exit 0
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  git add .claude/src/relationship.md
  git commit -m "vsr: first meeting — ${TODAY}" 2>/dev/null
fi

exit 0
```

### Design decisions

**Why grep for `first_met: null` in frontmatter:**
YAML key-value pairs are unambiguous. `first_met: null` can only appear in the frontmatter. No risk of matching markdown content elsewhere in the file.

**Why sed in-place:**
We only change one line. The rest of the file (markdown body with Claude's notes) is preserved untouched.

**Why the script commits to git:**
The auto-commit PostToolUse hook won't catch this change — it only fires after Claude's Write/Edit tool calls, and only for files in `context/|knowledge/|outputs/`. Files in `.claude/src/` are excluded by design. Without an explicit commit here, the flag change would sit as an unstaged local modification — fragile and potentially lost during git operations. The script does its own `git add` + `git commit` to make the change permanent.

**Why no git push:**
The auto-commit hook pushes, but push failures are noisy and can block. For a one-line flag flip, a local commit is sufficient. The next auto-commit push (from a knowledge write) will push this commit along with it. If there's no subsequent push in the session, session-sync on the next startup will handle it.

**Why macOS/Linux sed branching:**
macOS `sed -i` requires `''`. Linux/Git Bash doesn't. Simple `OSTYPE` check handles both.

**Why this runs on EVERY Stop event:**
The script checks `first_met: null` on every run. After the first write, it hits the `grep -q` check and exits in milliseconds. Cost per response: one grep. Negligible.

---

## Settings.json Change

Add a Stop hook:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/first-meeting-check.sh",
        "timeout": 10
      }
    ]
  }
]
```

Stop doesn't support matchers, so no matcher field needed.

---

## Relationship File: New Format

**`.claude/src/relationship.md`**

```
---
first_met: null
---

## How Dan Likes to Work
[learning]

## Notable Moments
[none yet]
```

---

## Updates to Session Briefing Hook

The `session-briefing.sh` script needs to read `first_met` from the YAML frontmatter instead of grepping for a date under a markdown heading:

```bash
# Old (fragile):
first_meeting_line=$(grep -A1 "## First Meeting" "$RELATIONSHIP" | tail -1)
if echo "$first_meeting_line" | grep -qE '^20[0-9]{2}'; then
  met_before="true"
fi

# New (robust):
if grep -q "^first_met: null" "$RELATIONSHIP"; then
  met_before="false"
else
  first_met_value=$(grep "^first_met:" "$RELATIONSHIP" | head -1 | sed 's/first_met: //')
  if [ -n "$first_met_value" ] && [ "$first_met_value" != "null" ]; then
    met_before="true"
  fi
fi
```

---

## What to Remove

1. **CLAUDE.md** — remove "REQUIRED: Immediately after your first greeting, silently update relationship.md..."
2. **session-briefing.sh** — remove "MANDATORY: If met_before is false and you introduce yourself, you MUST silently update relationship.md..."
3. **assistant-persona.md** — remove the "First meeting:" bullet from "Remembering Our Relationship" (the script handles this now)

These were LLM-dependent workarounds. The Stop hook makes them unnecessary and removes the risk of Marsh announcing the update or showing file edit dialogs.

## What to Add to Persona

Add to the "Remembering Our Relationship" section in `assistant-persona.md`:

> **Never modify the frontmatter** (the section between `---` markers at the top of `.claude/src/relationship.md`). That section is managed by system scripts. Only add notes to the markdown sections below it — "How Dan Likes to Work" and "Notable Moments."

This prevents Claude from writing to the YAML frontmatter when adding relationship notes. The frontmatter is the script's domain. The markdown body is Claude's domain.

---

## What Stays LLM-Dependent

The markdown body of relationship.md — "How Dan Likes to Work" and "Notable Moments" — remains LLM-driven enrichment. The persona file still instructs Marsh to write notes at natural moments. If Marsh forgets, the system still works (git data + frontmatter flags provide the backbone). When Marsh does write, it makes the experience better.

This matches the Hermes pattern: critical state = mechanical, enrichment = LLM best-effort.

---

## Validation

1. Start a fresh session with `first_met: null` in relationship.md
2. Say "hello" — Marsh introduces himself
3. After Marsh responds, check relationship.md — `first_met` should have today's date
4. Start another session — Marsh should NOT re-introduce himself
5. The update should be invisible to Dan — no edit dialogs, no announcements

---

## Implementation Order

1. Rewrite `.claude/src/relationship.md` with YAML frontmatter format
2. Create `.claude/hooks/first-meeting-check.sh` + make executable
3. Update `.claude/settings.json` with Stop hook
4. Update `.claude/hooks/session-briefing.sh` to read YAML frontmatter
5. Remove LLM-dependent first-meeting instructions from CLAUDE.md, session-briefing.sh, and assistant-persona.md
6. Add frontmatter protection instruction to assistant-persona.md
7. Update `.claude/scripts/smoke-test.sh` with new checks
8. Test validation scenarios
9. Commit and push
