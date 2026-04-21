# Vault Audit — AI Analysis Checklist

Generated: 2026-04-08T20:40:20.170075
Vault: `/Users/michaelatherton/viper-second-brain`

## Summary

- Total templates: 29
- Matched pairs: 28
- Orphan templates (no vault file): 0
- New vault files (no template): 27
- Minimal change (≤10%): 16
- Adapted (10-80%): 7
- Full rewrite (>80%): 5
- Pre-flagged domain-specific: 13
- Pre-flagged universal: 16

## Pairs to Analyze

Each pair needs a subagent auditor. Work through in batches of 3.

### Batch 1

- [ ] **1.** `templates/CLAUDE.md` → `CLAUDE.md`
      Similarity: 89.4% | Change: adapted | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__CLAUDE.md.diff`

- [ ] **2.** `templates/assistant-persona.md` → `.claude/src/assistant-persona.md`
      Similarity: 77.5% | Change: adapted | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__assistant-persona.md.diff`

- [ ] **3.** `templates/guardrails.md` → `.claude/src/guardrails.md`
      Similarity: 89.6% | Change: adapted | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__guardrails.md.diff`

### Batch 2

- [ ] **4.** `templates/relationship.md` → `.claude/src/relationship.md`
      Similarity: 92.3% | Change: minimal | Pre-flag: universal
      Diff: `audit/diffs/templates__relationship.md.diff`

- [ ] **5.** `templates/settings.json` → `.claude/settings.json`
      Similarity: 100.0% | Change: minimal | Pre-flag: universal
      Diff: `audit/diffs/templates__settings.json.diff`

- [ ] **6.** `templates/email-qa-format.md` → `.claude/reference/email-qa-format.md`
      Similarity: 97.5% | Change: minimal | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__email-qa-format.md.diff`

### Batch 3

- [ ] **7.** `templates/.gitignore` → `.gitignore`
      Similarity: 62.8% | Change: adapted | Pre-flag: universal
      Diff: `audit/diffs/templates__.gitignore.diff`

- [ ] **8.** `templates/context/business-profile.md` → `context/business-profile.md`
      Similarity: 7.0% | Change: full_rewrite | Pre-flag: universal
      Diff: `audit/diffs/templates__context__business-profile.md.diff`

- [ ] **9.** `templates/context/tone.md` → `context/tone.md`
      Similarity: 8.8% | Change: full_rewrite | Pre-flag: universal
      Diff: `audit/diffs/templates__context__tone.md.diff`

### Batch 4

- [ ] **10.** `templates/context/policies.md` → `context/policies.md`
      Similarity: 8.0% | Change: full_rewrite | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__context__policies.md.diff`

- [ ] **11.** `templates/context/website-navigation.md` → `context/website-navigation.md`
      Similarity: 1.2% | Change: full_rewrite | Pre-flag: universal
      Diff: `audit/diffs/templates__context__website-navigation.md.diff`

- [ ] **12.** `templates/context/channels/facebook.md` → `context/channels/facebook.md`
      Similarity: 25.1% | Change: adapted | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__context__channels__facebook.md.diff`

### Batch 5

- [ ] **13.** `templates/knowledge/resources/links.md` → `knowledge/resources/links.md`
      Similarity: 4.7% | Change: full_rewrite | Pre-flag: universal
      Diff: `audit/diffs/templates__knowledge__resources__links.md.diff`

- [ ] **14.** `templates/skills/draft-reply.md` → `.claude/skills/draft-reply/SKILL.md`
      Similarity: 94.3% | Change: minimal | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__skills__draft-reply.md.diff`

- [ ] **15.** `templates/skills/draft-facebook-reply.md` → `.claude/skills/draft-facebook-reply/SKILL.md`
      Similarity: 98.1% | Change: minimal | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__skills__draft-facebook-reply.md.diff`

### Batch 6

- [ ] **16.** `templates/skills/teach.md` → `.claude/skills/teach/SKILL.md`
      Similarity: 88.9% | Change: adapted | Pre-flag: universal
      Diff: `audit/diffs/templates__skills__teach.md.diff`

- [ ] **17.** `templates/skills/onboard.md` → `.claude/skills/onboard/SKILL.md`
      Similarity: 99.9% | Change: minimal | Pre-flag: universal
      Diff: `audit/diffs/templates__skills__onboard.md.diff`

- [ ] **18.** `templates/skills/categorize-email.md` → `.claude/skills/categorize-email/SKILL.md`
      Similarity: 92.0% | Change: minimal | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__skills__categorize-email.md.diff`

### Batch 7

- [ ] **19.** `templates/skills/ingest-emails.md` → `.claude/skills/ingest-emails/SKILL.md`
      Similarity: 96.0% | Change: minimal | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__skills__ingest-emails.md.diff`

- [ ] **20.** `templates/skills/ingest-facebook.md` → `.claude/skills/ingest-facebook/SKILL.md`
      Similarity: 94.8% | Change: minimal | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__skills__ingest-facebook.md.diff`

- [ ] **21.** `templates/skills/ingest-catalog.md` → `.claude/skills/ingest-catalog/SKILL.md`
      Similarity: 90.9% | Change: minimal | Pre-flag: domain-specific
      Diff: `audit/diffs/templates__skills__ingest-catalog.md.diff`

### Batch 8

- [ ] **22.** `templates/skills/ingest-site.md` → `.claude/skills/ingest-site/SKILL.md`
      Similarity: 93.3% | Change: minimal | Pre-flag: universal
      Diff: `audit/diffs/templates__skills__ingest-site.md.diff`

- [ ] **23.** `templates/skills/extract-knowledge.md` → `.claude/skills/extract-knowledge/SKILL.md`
      Similarity: 91.7% | Change: minimal | Pre-flag: universal
      Diff: `audit/diffs/templates__skills__extract-knowledge.md.diff`

- [ ] **24.** `scripts/auto-commit.sh` → `.claude/hooks/auto-commit.sh`
      Similarity: 99.4% | Change: minimal | Pre-flag: universal
      Diff: `audit/diffs/scripts__auto-commit.sh.diff`

### Batch 9

- [ ] **25.** `scripts/session-briefing.sh` → `.claude/hooks/session-briefing.sh`
      Similarity: 98.6% | Change: minimal | Pre-flag: universal
      Diff: `audit/diffs/scripts__session-briefing.sh.diff`

- [ ] **26.** `scripts/session-sync.sh` → `.claude/hooks/session-sync.sh`
      Similarity: 100.0% | Change: minimal | Pre-flag: universal
      Diff: `audit/diffs/scripts__session-sync.sh.diff`

- [ ] **27.** `scripts/first-meeting-check.sh` → `.claude/hooks/first-meeting-check.sh`
      Similarity: 99.0% | Change: minimal | Pre-flag: universal
      Diff: `audit/diffs/scripts__first-meeting-check.sh.diff`

### Batch 10

- [ ] **28.** `scripts/smoke-test.sh` → `.claude/scripts/smoke-test.sh`
      Similarity: 64.9% | Change: adapted | Pre-flag: universal
      Diff: `audit/diffs/scripts__smoke-test.sh.diff`

## New Vault Files (no template)

These files were created during the build with no template source. Classify as NEW PATTERN.

- [ ] `.claude/hooks/error.log`

- [ ] `knowledge/email-examples/order-issues/payment-failure.md`

- [ ] `knowledge/email-examples/order-issues/wrong-parts-shipped.md`

- [ ] `knowledge/email-examples/pre-sales/track-inquiry.md`

- [ ] `knowledge/email-examples/product-questions/tire-compatibility-standard-response.md`

- [ ] `knowledge/email-examples/product-questions/what-is-best-for-my-car.md`

- [ ] `knowledge/email-examples/setup-support/drag-racing-questions.md`

- [ ] `knowledge/email-examples/setup-support/timing-system-setup.md`

- [ ] `knowledge/email-examples/stock-availability/product-not-carried.md`

- [ ] `knowledge/email-examples/warranty-returns/defective-car-standard-response.md`

- [ ] `knowledge/facebook-examples/comment-replies/.gitkeep`

- [ ] `knowledge/facebook-examples/dm-responses/.gitkeep`

- [ ] `knowledge/product-rules/car-chassis-guide.md`

- [ ] `knowledge/product-rules/discontinued-alternatives.md`

- [ ] `knowledge/product-rules/inventory-notes.md`

- [ ] `knowledge/product-rules/special-order-items.md`

- [ ] `knowledge/product-rules/tire-compatibility.md`

- [ ] `knowledge/products/.gitkeep`

- [ ] `outputs/.gitkeep`

- [ ] `prd/claude-directory-design.md`

- [ ] `prd/claude-project-prompt-v1.md`

- [ ] `prd/first-meeting-flag-implementation.md`

- [ ] `prd/first-meeting-flag-spec.md`

- [ ] `prd/implementation-spec-personalization.md`

- [ ] `prd/relationship-system-design.md`

- [ ] `prd/relationship-system-spec.md`

- [ ] `prd/skill-package-spec.md`

## Completeness Tracker

Items to analyze: 55
Analyzed: 0 / 55
Remaining: 55
