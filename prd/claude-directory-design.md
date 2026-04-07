---
type: design-doc
status: implemented
created: 2026-04-07
parent: prd/client-second-brain.md
---

# .claude Directory Design — Viper Second Brain

## Purpose

Define the `.claude/` directory structure for the Viper Second Brain vault. Dan will have git installed, so hooks that auto-commit and sync are in scope. Dan will NOT have MCP servers.

---

## Environment

| Environment | User | OS | Git? | Claude Interface | Phase |
|-------------|------|----|------|-----------------|-------|
| **Development** | Michael | macOS | Yes | Claude Code CLI | Phase 1 |
| **Production** | Dan/Abby | Windows | Yes (Michael installs) | Claude Desktop | Phase 2+ |

Both environments have git. This means auto-commit hooks work everywhere, and git sync replaces zip replacement as the update mechanism after initial delivery.

---

## .claude/ Structure

```
.claude/
  settings.json              — permissions (git ops) + hooks (auto-commit, session-sync)
  skills/
    draft-reply/SKILL.md
    categorize-email/SKILL.md
    teach/SKILL.md
    ingest-emails/SKILL.md
    ingest-catalog/SKILL.md
    ingest-site/SKILL.md
    extract-knowledge/SKILL.md
  hooks/
    auto-commit.sh           — commits after Write/Edit to vault content directories
    session-sync.sh          — pulls remote changes on session start
  reference/
    email-qa-format.md       — canonical Q&A pair format for /teach and /ingest-emails
```

### Not included (and why)

| Component | Why excluded |
|-----------|-------------|
| `settings.local.json` | Not needed — both environments have git, same permissions apply. settings.json covers everything. |
| `agents/` | No MCP servers for Dan. No farmers. Deferred to Tier 2+ if/when Gmail or WooCommerce API connectors are added. |
| `hooks/subagent-push.sh` | No subagents/farmers in Dan's vault. |
| `hooks/stop-sound.sh` | macOS-only (afplay). Dan is on Windows. Not worth a cross-platform solution for Phase 1. |

---

## settings.json

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
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/auto-commit.sh",
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
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-sync.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**Permissions:** Pre-approve git operations so Claude can commit and sync without asking Dan every time.

**Hooks:**
- **PostToolUse (Write|Edit):** After any file write/edit, auto-commit.sh checks if the file is in a vault content directory. If yes, it commits with a descriptive message and pushes.
- **SessionStart:** On every new session, session-sync.sh pulls any remote changes (Michael's updates, or changes from another machine).

---

## hooks/auto-commit.sh

Adapted from Michael's second-brain version. Key differences:

| Aspect | Michael's second-brain | Dan's vault |
|--------|----------------------|-------------|
| Content directories | tasks/, projects/, people/, ideas/, daily/, weekly/, context/ | context/, knowledge/, outputs/, daily/ |
| Commit prefix | `cos:` (chief of staff) | `vsr:` (Viper Scale Racing) |
| Type mapping | task, project, person, idea, daily plan, weekly, config | knowledge, context, output, daily, skill |

The hook:
1. Reads the file path from tool input JSON
2. Checks if the file is in a vault content directory
3. If yes: `git add` + `git commit` with a `vsr:` prefixed message
4. Pulls with rebase, then pushes
5. If the file is outside content dirs (e.g., CLAUDE.md, .claude/ itself): does nothing

**Why not auto-commit everything?** To avoid committing scratch files, temp outputs, or accidental edits to configuration. Only curated content directories get auto-committed.

---

## hooks/session-sync.sh

Identical to Michael's second-brain version — it's generic:
1. Abort any in-progress rebase from a crashed session
2. Recover from detached HEAD
3. Ensure we're on main branch
4. `git pull --rebase --autostash`

---

## reference/email-qa-format.md

Canonical format for Q&A pairs. Used by `/teach` and `/ingest-emails` to produce consistent output in `knowledge/email-examples/`.

---

## Changes to Existing Files

### CLAUDE.md
- Update directory structure to show `.claude/` with skills inside
- Remove `skills/` from root-level listing
- Add note about auto-commit behavior (Dan should know his /teach entries are saved automatically)
- Add note about git sync (Dan should know Michael's updates appear automatically on session start)

### PRD (client-second-brain.md)
- Update vault structure diagram to show `.claude/skills/` instead of `skills/`
- Add `.claude/` directory to the structure
- Note that git is installed for Dan (changes Phase 2 delivery/update story)
- Update Phase 2 "Version Updates" section — git sync replaces zip replacement

---

## Git Sync Flow (enabled by these hooks)

```
Michael pushes update → Dan opens Claude Desktop → SessionStart hook pulls → Dan has latest

Dan uses /teach → auto-commit hook commits + pushes → Michael pulls → has Dan's new knowledge
```

This eliminates the PRD's "update friction" problem entirely. No more zip replacement. No more overwriting /teach entries.

---

## Implementation Checklist

1. [ ] Move `skills/` → `.claude/skills/`
2. [ ] Remove empty `skills/` from vault root
3. [ ] Create `.claude/settings.json`
4. [ ] Create `.claude/hooks/auto-commit.sh` (adapted for Dan's dirs)
5. [ ] Create `.claude/hooks/session-sync.sh`
6. [ ] Create `.claude/reference/email-qa-format.md`
7. [ ] Update `CLAUDE.md` — new structure, auto-commit note, git sync note
8. [ ] Update PRD — vault structure, .claude/ directory, git sync
9. [ ] Create `.gitignore`
10. [ ] Init git repo, set remote
