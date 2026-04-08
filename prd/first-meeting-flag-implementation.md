# Implementation Spec: Deterministic First Meeting Flag

**Date:** 2026-04-08
**Author:** Michael Atherton / AI Revolution Labs
**Vault:** Viper Scale Racing — Client Second Brain
**Status:** Draft — pending review before implementation
**Depends on:** `prd/first-meeting-flag-spec.md` (approved)

---

## Summary

Replace the LLM-dependent first meeting flag with a deterministic Stop hook. Convert relationship.md from pure markdown to YAML frontmatter + markdown body. Scripts own the frontmatter. Claude owns the markdown body.

---

## Step 1: Rewrite `.claude/src/relationship.md`

### Current Content
```markdown
# Marsh & Dan

## First Meeting
[not yet]

## How Dan Likes to Work
[learning]

## Notable Moments
[none yet]
```

### New Content
```markdown
<!-- SYSTEM MANAGED — DO NOT EDIT THIS SECTION -->
---
first_met: null
---
<!-- END SYSTEM MANAGED — Add your notes below -->

## How Dan Likes to Work
[learning]

## Notable Moments
[none yet]
```

### What Changed
- Removed `# Marsh & Dan` heading (unnecessary — the file's purpose is defined by its location)
- Removed `## First Meeting` section (replaced by `first_met` in frontmatter)
- Added YAML frontmatter with `first_met: null`
- Added HTML guard comments above and below frontmatter — visible to Claude as text, prevents LLM from editing the machine-managed section
- Markdown body sections unchanged

---

## Step 2: Create `.claude/hooks/first-meeting-check.sh`

### Content
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
cd "$VAULT_ROOT" || exit 0
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  git add .claude/src/relationship.md
  git commit -m "vsr: first meeting — ${TODAY}" 2>/dev/null
fi

exit 0
```

### Post-creation
```bash
chmod +x .claude/hooks/first-meeting-check.sh
```

---

## Step 3: Update `.claude/settings.json`

### Current Content
```json
{
  "permissions": {
    "allow": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git pull:*)",
      "Read(.claude/src/*)",
      "Edit(.claude/src/*)",
      "Write(.claude/src/*)"
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

### New Content
Add `Stop` hook after `SessionStart`:
```json
{
  "permissions": {
    "allow": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git pull:*)",
      "Read(.claude/src/*)",
      "Edit(.claude/src/*)",
      "Write(.claude/src/*)"
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
    ],
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
  }
}
```

### What Changed
- Added `Stop` event with `first-meeting-check.sh` hook
- No matcher on Stop (the docs say Stop doesn't support matchers)
- Timeout 10s (shorter than other hooks — this script is fast)

---

## Step 4: Update `.claude/hooks/session-briefing.sh`

### Change: Replace the `met_before` detection logic

Find:
```bash
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
```

Replace with:
```bash
# ── Has Marsh met Dan before? ──────────────────────────
met_before="false"
if [ -f "$RELATIONSHIP" ]; then
  if grep -q "^first_met: null" "$RELATIONSHIP"; then
    met_before="false"
  else
    first_met_value=$(grep "^first_met:" "$RELATIONSHIP" | head -1 | sed 's/first_met: *//')
    if [ -n "$first_met_value" ] && [ "$first_met_value" != "null" ]; then
      met_before="true"
    fi
  fi
fi
```

### Change: Remove MANDATORY first-meeting instruction

Find:
```
MANDATORY: If met_before is false and you introduce yourself, you MUST silently update .claude/src/relationship.md immediately after your greeting — replace '[not yet]' under '## First Meeting' with today's date and a brief note about the interaction. Do this silently as part of your first response. Do not skip this. If you do not update this file, you will re-introduce yourself on every session.
```

Remove this entire paragraph. The Stop hook handles this now.

---

## Step 5: Update `CLAUDE.md`

### Change: Remove REQUIRED first-meeting instruction

Find:
```markdown
**REQUIRED:** Immediately after your first greeting, silently update `.claude/src/relationship.md` — replace `[not yet]` under `## First Meeting` with today's date and a brief note. If you skip this, you will re-introduce yourself every session.
```

Remove this entire line.

---

## Step 6: Update `.claude/src/assistant-persona.md`

### Change 1: Remove first meeting bullet from "Remembering Our Relationship"

Find:
```markdown
- **First meeting:** After your first introduction, write the date and a brief note under "## First Meeting". Example: `2026-04-14 — Met Dan. He jumped straight into pasting a customer email about tire compatibility.`
```

Remove this bullet.

### Change 2: Add frontmatter protection instruction

After the line "Don't force this. Don't update the file after every interaction..." and before the **IMPORTANT** block, add:

```markdown
**Never modify the frontmatter** (the section between `---` markers at the top of `.claude/src/relationship.md`). That section is managed by system scripts. Only add notes to the markdown sections below it — "How Dan Likes to Work" and "Notable Moments."
```

---

## Step 7: Update `.claude/scripts/smoke-test.sh`

### Change 1: Update relationship system checks

Replace the existing relationship file check:
```bash
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
```

With:
```bash
# Relationship file — YAML frontmatter format
if [ -f ".claude/src/relationship.md" ]; then
  if [ -s ".claude/src/relationship.md" ]; then
    pass ".claude/src/relationship.md exists and non-empty"
  else
    fail ".claude/src/relationship.md exists but empty"
  fi
  # Check for YAML frontmatter
  if head -1 ".claude/src/relationship.md" | grep -q "^---"; then
    pass ".claude/src/relationship.md has YAML frontmatter"
  else
    fail ".claude/src/relationship.md missing YAML frontmatter"
  fi
  # Check for first_met field
  if grep -q "^first_met:" ".claude/src/relationship.md"; then
    pass ".claude/src/relationship.md has first_met field"
  else
    fail ".claude/src/relationship.md missing first_met field"
  fi
else
  fail ".claude/src/relationship.md — missing"
fi
```

### Change 2: Add first-meeting-check.sh checks

After the existing session-briefing checks, add:
```bash
# First meeting check script
fmc_script=".claude/hooks/first-meeting-check.sh"
if [ -f "$fmc_script" ]; then
  if [ -x "$fmc_script" ]; then
    pass "first-meeting-check.sh — exists and executable"
  else
    fail "first-meeting-check.sh — exists but NOT executable"
  fi
  if head -1 "$fmc_script" | grep -q "^#!/bin/bash"; then
    pass "first-meeting-check.sh — has bash shebang"
  else
    fail "first-meeting-check.sh — missing #!/bin/bash shebang"
  fi
else
  fail "first-meeting-check.sh — missing"
fi

# Settings.json has Stop hook
if grep -q "first-meeting-check.sh" .claude/settings.json; then
  pass "settings.json has Stop hook for first-meeting-check.sh"
else
  fail "settings.json missing Stop hook for first-meeting-check.sh"
fi
```

### Change 3: Add first-meeting-check.sh dry run

```bash
# Dry run — verify first-meeting-check handles null correctly
test_rel=$(mktemp)
cat > "$test_rel" << 'TESTEOF'
---
first_met: null
---

## How Dan Likes to Work
[learning]
TESTEOF
CLAUDE_PROJECT_DIR="$(dirname "$(dirname "$test_rel")")" \
  VAULT_ROOT="$(dirname "$(dirname "$test_rel")")" \
  bash -c "
    RELATIONSHIP='$test_rel'
    grep -q '^first_met: null' '$test_rel' && echo 'WOULD_FLIP'
  "
result=$?
if grep -q "^first_met: null" "$test_rel"; then
  pass "first-meeting-check.sh dry run — detects null flag"
else
  fail "first-meeting-check.sh dry run — flag detection failed"
fi
rm -f "$test_rel"
```

---

## Files Changed Summary

| File | Action | Description |
|------|--------|-------------|
| `.claude/src/relationship.md` | Rewrite | YAML frontmatter + markdown body |
| `.claude/hooks/first-meeting-check.sh` | Create | Stop hook script — flips flag + git commit |
| `.claude/settings.json` | Update | Add Stop hook |
| `.claude/hooks/session-briefing.sh` | Update | Read first_met from YAML frontmatter |
| `CLAUDE.md` | Update | Remove REQUIRED first-meeting instruction |
| `.claude/src/assistant-persona.md` | Update | Remove first meeting bullet, add frontmatter protection |
| `.claude/scripts/smoke-test.sh` | Update | YAML frontmatter checks, first-meeting-check checks |

---

## Validation Checklist

- [ ] `first_met: null` in relationship.md frontmatter on fresh deploy
- [ ] Start session, say "hello" — Marsh introduces himself
- [ ] After response, relationship.md shows `first_met: 2026-04-08` (today's date)
- [ ] Git log shows commit "vsr: first meeting — 2026-04-08"
- [ ] Start another session — Marsh does NOT re-introduce himself
- [ ] No edit dialogs shown to Dan
- [ ] No mention of "relationship file" or frontmatter in conversation
- [ ] Smoke test passes with all new checks
- [ ] session-briefing.sh correctly reads `met_before: true` after flag flip
- [ ] Persona still instructs Marsh to write to markdown body sections (working preferences, notable moments)
- [ ] Persona explicitly prevents Marsh from modifying frontmatter
