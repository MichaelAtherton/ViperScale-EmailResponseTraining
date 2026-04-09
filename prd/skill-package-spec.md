# Implementation Spec: Complete Client Second Brain Skill Package

**Date:** 2026-04-08
**Author:** Michael Atherton / AI Revolution Labs
**Status:** Draft — pending review before implementation

---

## Purpose

Make the client-second-brain Hermes skill a COMPLETE, self-contained package that can reproduce the entire vault architecture for any new client — without referencing the Viper vault or any external files.

Currently: 12 files exist in the skill (SKILL.md + 7 templates + 4 scripts).
After: 29 files (SKILL.md + 22 templates + 6 scripts).

---

## Current State

```
client-second-brain/
  SKILL.md                              ✓ exists (v9, comprehensive)
  templates/
    CLAUDE.md                           ✓ exists (templatized)
    settings.json                       ✓ exists (all 4 hooks)
    guardrails.md                       ✓ exists (templatized)
    relationship.md                     ✓ exists (YAML frontmatter + guard comments)
    email-qa-format.md                  ✓ exists
    assistant-persona.md                ✓ exists (templatized)
    .gitignore                          ✓ exists
  scripts/
    session-briefing.sh                 ⚠ exists BUT has hardcoded vsr: prefix + Viper file paths
    session-sync.sh                     ✓ exists (truly universal)
    auto-commit.sh                      ⚠ exists BUT has hardcoded vsr: commit prefix
    first-meeting-check.sh              ⚠ exists BUT has hardcoded vsr: commit prefix
```

**3 of 4 scripts need templatizing** — only session-sync.sh is truly universal.

## What's Missing — 18 Files + 5 Fixes

### Missing Scripts (1 file)

| File | Source | Notes |
|------|--------|-------|
| `scripts/smoke-test.sh` | `~/viper-second-brain/.claude/scripts/smoke-test.sh` | Needs templatizing: replace Viper-specific commit prefix grep, adjust test counts |

### Missing Skill Templates (10 files)

These are the 10 vault skills that live at `.claude/skills/*/SKILL.md` in the deployed vault. Each needs to be copied from Viper and templatized — replacing "Dan", "Abby", "John", "Viper Scale Racing", and Viper-specific product references with placeholders.

| File | Source | Universal or Template? |
|------|--------|----------------------|
| `templates/skills/draft-reply.md` | `~/viper-second-brain/.claude/skills/draft-reply/SKILL.md` | Template — routing rules and categories are client-specific |
| `templates/skills/draft-facebook-reply.md` | `~/viper-second-brain/.claude/skills/draft-facebook-reply/SKILL.md` | Template — channel-specific DM redirect phrasing |
| `templates/skills/teach.md` | `~/viper-second-brain/.claude/skills/teach/SKILL.md` | Near-universal — file paths are the same, just strip Viper examples |
| `templates/skills/onboard.md` | `~/viper-second-brain/.claude/skills/onboard/SKILL.md` | Template — section questions reference client business |
| `templates/skills/categorize-email.md` | `~/viper-second-brain/.claude/skills/categorize-email/SKILL.md` | Near-universal — 6 categories apply broadly |
| `templates/skills/ingest-emails.md` | `~/viper-second-brain/.claude/skills/ingest-emails/SKILL.md` | Template — category structure may vary |
| `templates/skills/ingest-facebook.md` | `~/viper-second-brain/.claude/skills/ingest-facebook/SKILL.md` | Template — client-specific channel details |
| `templates/skills/ingest-catalog.md` | `~/viper-second-brain/.claude/skills/ingest-catalog/SKILL.md` | Template — platform-specific (WooCommerce vs Shopify) |
| `templates/skills/ingest-site.md` | `~/viper-second-brain/.claude/skills/ingest-site/SKILL.md` | Template — domain-specific URLs |
| `templates/skills/extract-knowledge.md` | `~/viper-second-brain/.claude/skills/extract-knowledge/SKILL.md` | Near-universal — extraction categories are generic |

### Missing Scaffold Templates (6 files)

These are EMPTY templates with section headings that get populated during the engagement. They define the STRUCTURE that /onboard and the ingestion skills expect to find.

| File | Purpose | Content |
|------|---------|---------|
| `templates/context/business-profile.md` | Company details, team, roles, routing | Empty with section headings: Company Details, Team & Roles, Email Routing Rules, Current Workflow |
| `templates/context/tone.md` | Client's communication style | Empty with section headings: Core Traits, What [Owner] Does, What [Owner] Avoids, Actual Phrasing Examples, Handling Misspellings |
| `templates/context/policies.md` | Shipping, returns, warranty, payment | Empty with section headings: Shipping, Returns/Warranty, Out-of-Stock Items, Payment Methods, Customer Communication, Support Boundaries |
| `templates/context/channels/facebook.md` | Facebook-specific tone and rules | Empty with section headings: Channel Overview, Tone Differences from Email, Comment Replies (Public), DM Responses (Private), What to Avoid on Facebook, Actual Facebook Phrasing |
| `templates/context/website-navigation.md` | Site structure and navigation | Empty with section headings: How to Find Products, Search Behavior, Product Listings, Site Pages, Category Tree |
| `templates/knowledge/resources/links.md` | YouTube, manuals, product pages | Empty with section headings: YouTube Channel, Key Videos, Downloadable Resources, Product Category Quick Links, Site Resources |

---

### Missing: Bridge Prompt Template (1 file)

| File | Purpose |
|------|---------|
| `templates/bridge-prompt.md` | Interim Claude Desktop project prompt — the hybrid working assistant that clients use during the training week before vault delivery. Currently only exists in Viper's prd/. Templatize with client name and business description placeholders. |

### Fixes to Existing Files (5 fixes)

| File | Issue | Fix |
|------|-------|-----|
| `scripts/auto-commit.sh` | Hardcoded `vsr:` commit prefix (lines 101, 106) | Replace with `{{COMMIT_PREFIX}}:` |
| `scripts/session-briefing.sh` | Hardcoded `--grep="vsr:"` (line 49) | Replace with `--grep="{{COMMIT_PREFIX}}:"` |
| `scripts/session-briefing.sh` | Hardcoded Viper file paths in briefing text (lines 103-104: `car-chassis-guide.md`, `tire-compatibility.md`) | Replace with generic instruction: "read the files in `knowledge/product-rules/`" |
| `scripts/first-meeting-check.sh` | Hardcoded `vsr:` commit message (line 28) | Replace with `{{COMMIT_PREFIX}}:` |
| SKILL.md | No git initialization instructions in Phase A | Add Step 7: git init, create remote, add origin, initial commit |

### Missing: .gitkeep Handling

The scaffold step creates directories with `mkdir -p` but never creates `.gitkeep` files. Without them, empty directories (outputs/, knowledge/products/, knowledge/facebook-examples/comment-replies/, etc.) won't be tracked by git. 

**Fix:** Add to Phase A Step 1: after mkdir, create .gitkeep in all leaf directories that start empty:
```bash
find <vault-name> -type d -empty -exec touch {}/.gitkeep \;
```

---

## Configuration Step (MUST be added to SKILL.md Phase A)

Before copying any templates, the builder fills in a configuration block. This is the SINGLE SOURCE OF TRUTH for all placeholders. Every template and script references these values.

```
CLIENT_NAME:          [e.g., "Bella's Bakery"]
CLIENT_WEBSITE:       [e.g., "bellasbakery.com"]
SUPPORT_EMAIL:        [e.g., "hello@bellasbakery.com"]
OWNER_NAME:           [e.g., "Bella"]
TEAM_MEMBER_1:        [e.g., "Carlos" — primary support person, or remove if solo]
TEAM_MEMBER_2:        [e.g., "Maria" — specialist, or remove if none]
ASSISTANT_NAME:       [e.g., "Baker"]
ASSISTANT_NICKNAME:   [e.g., "Bake"]
NAME_RATIONALE:       [e.g., "a baker keeps the shop running — that's what you do for customer service"]
COMMIT_PREFIX:        [e.g., "bb" — short lowercase, used in git commit messages]
```

After filling this in, find-and-replace `{{PLACEHOLDER}}` across all copied templates and scripts. Every placeholder in every file maps to exactly one value in this block.

**This step prevents:** discovering placeholders one file at a time, inconsistent naming, missed replacements.

---

## Templatization Rules

When copying Viper files to templates, apply these replacements:

| Viper-Specific | Template Placeholder | Notes |
|----------------|---------------------|-------|
| `Viper Scale Racing` | `{{CLIENT_NAME}}` | |
| `viperscaleracing.com` | `{{CLIENT_WEBSITE}}` | |
| `support@viperscaleracing.com` | `{{SUPPORT_EMAIL}}` | |
| `Dan` (as owner) | `{{OWNER_NAME}}` | |
| `Abby` (as team member) | `{{TEAM_MEMBER_1}}` | Remove section if client is solo |
| `John` (as specialist) | `{{TEAM_MEMBER_2}}` | Remove section if no specialist |
| `Marshall` | `{{ASSISTANT_NAME}}` | Full name |
| `Marsh` | `{{ASSISTANT_NICKNAME}}` | Casual short form |
| "a race marshal keeps things running" | `{{NAME_RATIONALE}}` | Why this name was chosen |
| `vsr:` (commit prefix) | `{{COMMIT_PREFIX}}:` | In scripts AND commit messages |
| Viper product references (SKU 420, Magnet Traction, etc.) | Remove or replace with `<!-- client-specific -->` | |
| Slot car domain language | Replace with generic customer service language | |

**Placeholder consistency:** The existing templates use `{{NICKNAME}}` in some places and `{{ASSISTANT_NICKNAME}}` in others. Standardize ALL templates to use the names from the Configuration block above. Similarly, `{{CLIENT_COMPANY}}` should be `{{CLIENT_NAME}}` everywhere.

**Rule:** If a placeholder would make the template unreadable or confusing, use a descriptive comment instead:
```
<!-- Replace with client-specific product compatibility rules -->
```

---

## Templatization Approach by File Type

### Near-Universal Skills (teach, categorize-email, extract-knowledge)

These need minimal changes:
- Replace "Dan" with `{{OWNER_NAME}}` where it appears as a person reference
- Remove Viper product examples but keep the example FORMAT
- Keep all structural elements (steps, categories, output formats)

### Template Skills (draft-reply, onboard, ingest-*, draft-facebook-reply)

These need moderate changes:
- Replace all Viper-specific references per the table above
- Keep the full step-by-step structure
- Replace specific routing rules with placeholders: "Track sales → {{OWNER_NAME}}" becomes a template
- Replace specific product examples with comments: `<!-- Add client-specific examples -->`

### Scaffold Templates (context/, knowledge/)

These are new — they don't exist in the skill yet. Create them with:
- Section headings that match what /onboard expects to populate
- Placeholder text in brackets: `[to be populated during /onboard]`
- The heading structure must match what the skills reference (e.g., /draft-reply searches `context/policies.md` for shipping info — the heading must exist)

### Smoke Test Script

Needs special handling:
- Replace `--grep="vsr:"` with `--grep="{{COMMIT_PREFIX}}:"` 
- The test counts will differ per vault — remove hardcoded count assertions
- Keep all structural checks (directories, files, hooks, settings, cross-references)
- The smoke test itself needs to be templatized or made generic enough to work with any vault

---

## Verification: Can This Skill Recreate a Full Vault?

After implementation, verify by mentally walking through building a HYPOTHETICAL client #2:

**Client:** "Bella's Bakery" — e-commerce bakery, owner Bella, assistant named "Baker"

1. Load skill: `skill_view("client-second-brain")`
2. Read SKILL.md Phase A instructions
3. Create directory structure (from SKILL.md Step 1 command)
4. Copy `templates/CLAUDE.md` → `bellas-bakery/CLAUDE.md` — change `{{CLIENT_NAME}}` → "Bella's Bakery"
5. Copy `templates/assistant-persona.md` → `.claude/src/` — fill in Baker's identity, Bella's team, bakery domain
6. Copy `templates/guardrails.md` → `.claude/src/` — change `[owner name]` → "Bella"
7. Copy `templates/relationship.md` → `.claude/src/` — change `{{OWNER_NAME}}` → "Bella"
8. Copy `templates/settings.json` → `.claude/` — as-is
9. Copy `templates/email-qa-format.md` → `.claude/reference/` — as-is
10. Copy `templates/.gitignore` → root — as-is
11. Copy all `templates/skills/*.md` → `.claude/skills/*/SKILL.md` — customize per client
12. Copy all `templates/context/*.md` → `context/` — empty scaffolds ready for /onboard
13. Copy `templates/knowledge/resources/links.md` → `knowledge/resources/` — empty scaffold
14. Copy `scripts/*.sh` → `.claude/hooks/` and `.claude/scripts/` — make executable
15. Create empty knowledge directories (email-examples/*, facebook-examples/*, product-rules/, products/)
16. Run smoke test
17. Initialize git, commit, push

**Check:** Does anything require going back to `~/viper-second-brain/`? If yes, that file is missing from the skill.

---

## Updated Totals

After implementation:
- SKILL.md (1 file, updated)
- templates/ (24 files: 7 existing + 10 skill templates + 6 scaffold templates + 1 bridge prompt)
- scripts/ (5 files: 4 existing with 3 needing fixes + 1 new smoke test)
- **Total: 30 files (SKILL.md + 29 linked files)**

## Implementation Order

1. Standardize placeholder names in existing 7 templates (`{{NICKNAME}}` → `{{ASSISTANT_NICKNAME}}`, `{{CLIENT_COMPANY}}` → `{{CLIENT_NAME}}`)
2. Fix 3 existing scripts (auto-commit.sh, session-briefing.sh, first-meeting-check.sh) — replace hardcoded `vsr:` with `{{COMMIT_PREFIX}}`
3. Fix session-briefing.sh — replace Viper-specific file paths with generic references
4. Create the 10 skill template files (copy from Viper, templatize)
5. Create the 6 scaffold template files (new, empty with headings)
6. Create the bridge prompt template (templatize from Viper's prd/claude-project-prompt-v1.md)
7. Create the smoke test script (copy from Viper, make generic)
8. Update SKILL.md:
   - Add Configuration step (placeholder block) to Phase A before any file copying
   - Phase A Step 1: add .gitkeep creation after mkdir
   - Phase A: add git initialization step
   - Update template references throughout
9. Verify: walk through the hypothetical client #2 build mentally — every file must come from the skill, every placeholder must map to the Configuration block
10. Run existing Viper vault smoke test to confirm nothing broke

---

## What This Spec Does NOT Cover

- **Automated scaffolding script** — a script that does all the copying and placeholder replacement automatically. Future work. For now, the SKILL.md instructions guide manual copying.
- **Skill-level hooks** — Claude Code supports hooks in SKILL.md frontmatter. Could be useful for vault-building automation but not needed for v1.
- **Multi-platform support** — ingest-catalog assumes WooCommerce. Future clients may use Shopify, custom platforms. The template should note this as a customization point.
