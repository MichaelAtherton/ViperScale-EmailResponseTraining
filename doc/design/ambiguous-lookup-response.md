# Design Doc — Ambiguous Catalog Lookup: Fix & Response Shape (v2)

**Author:** Enzo (with Michael)
**Date:** 2026-04-20
**Status:** Proposed
**Supersedes:** v1 (same path, 2026-04-19) — replaced after council critique surfaced weaknesses
**Task IDs:** 1, 2, 3, 4, 5, 6, 7

---

## Problem

Customer asked for an AFX G-Plus armature. The CLI returned `chassis_not_found`; I treated it as a clean-no and drafted "we don't carry it, try eBay." The category **did exist** (`Aurora G-Plus`, id=522) — the resolver just didn't match "AFX G-Plus" to it.

Two defects surfaced:

1. **Lookup defect.** `resolve_category_id` does exact match only. Near-variants like "AFX G-Plus" vs. "Aurora G-Plus" silently fail even when the category exists.
2. **Response-shape defect.** The skill treats `chassis_not_found` and `count=0` as the clean-no default. This ships confident wrong answers on false negatives.

A third defect surfaced during v2 drafting:

3. **Stale clean-no guidance.** The "try eBay" phrasing was superseded on 2026-04-16 (`context/policies.md` §Never Redirect Customers to Other Retailers) but still lives in `tire-compatibility.md` and in my own drafts. The v1 design doc repeated the stale phrasing.

---

## Evidence

### Query log baseline (Task #1)

Read `.claude/logs/wc-queries.jsonl` (32 entries, mostly dev-time spot checks). **There is no historical baseline for customer-driven zero-count frequency.** The only ambiguous zero-counts are the ones generated today during the AFX G-Plus investigation.

**Implication:** Cannot claim "Branch C is the most common zero-count case." Instead: Branch C is the **safer default** (retains customers on ambiguity); real frequency gets measured once traffic flows and can drive later tuning.

### Policy reality check (Task #4)

Three hits in `context/policies.md` + `context/business-profile.md` that change the doc:

- **`policies.md:54-59`** — Dan explicitly banned "try eBay" on 2026-04-16. Clean-no reads "we don't carry it" with nothing after. In-house substitute is allowed (e.g., Viper Tyco for a vintage Tyco ask). The v1 doc and `tire-compatibility.md` both still carry the stale phrasing.
- **`business-profile.md:27`** — Abby already uses a Gmail "pending" folder to flag items for Dan. This is a real workflow. The escalation fallback in v1 ("Dan may stock something that's not on the site — want me to flag this for him?") is theater unless it maps to that folder. The honest phrasing: **"I'll flag this for Dan to review"** — which is the Abby-puts-it-in-pending workflow, not an invented escalation.
- **`business-profile.md:38-45`** — routing rules are specific (track sales → Dan, drag racing → John, warranty → standard response). There's no generic "Dan eyeballs off-catalog possibilities" path. "Flag for Dan" works because Abby is the human actually doing the flagging; the AI doesn't have a private channel to Dan.

---

## Goals

- Resolver returns a category when the category exists, even if the customer's phrasing is a word off.
- Default zero-count response keeps the customer on the site with a clarifying question and a category link — not a clean-no.
- Clean-no reserved for **rule-backed** cases only (HP7, HP2, Curvehugger, Aurora AX, or a documented discontinued-with-alternative rule), and uses current policy phrasing (no eBay).
- Single source of truth for the decision tree (catalog-lookup skill); `draft-reply` references.
- Verification by harness, not manual spot-check.

## Non-goals

- Fuzzy-everything resolver. The cost of a wrong-category match (wrong products with confidence) is higher than the cost of asking for clarification.
- Rewrite Dan's voice.
- New skill file. All changes live in existing files.

---

## The six fixes (each a first-class task)

### Fix 1 — Query-log baseline recorded (Task #1, done)

No change to code or skills. The finding *itself* is the fix: any future frequency claim must cite the log, not guess. Re-audit quarterly.

---

### Fix 2 — Resolver: token-match + exhaustive seeding (Task #2)

**Drops the v1 "unique substring" layer.** Substring was clever and fragile. Token-match is boring and correct.

**File:** `integrations/woocommerce/cache.py`

**Change 2a — add token-match layer to `resolve_category_id` (lines 184–212):**

```python
def resolve_category_id(cache: CategoryCache, text: str) -> int | None:
    """Resolve a chassis/brand/part-type string to a category ID.

    Layers (in order):
      1. Exact alias match (case-insensitive)
      2. Exact slug match (case-insensitive)
      3. Exact name match (case-insensitive)
      4. Token-subset match on category name: input's tokens must be a
         subset of a category name's tokens. Only returns a hit if the
         match is unique across all categories. Ambiguous → None.
    """
    if not text:
        return None
    key = text.strip().lower()

    # Layer 1: aliases
    if key in cache.aliases:
        return cache.aliases[key]

    # Layer 2: slugs
    slug_key = key.replace(" ", "-")
    for c in cache.categories:
        if c.slug.lower() == slug_key or c.slug.lower() == key:
            return c.id

    # Layer 3: exact names
    for c in cache.categories:
        if c.name.lower() == key:
            return c.id

    # Layer 4: unique token-subset match
    def _tokens(s: str) -> set[str]:
        # normalize punctuation, split on whitespace
        cleaned = s.lower().replace("/", " ").replace("-", " ").replace("+", " plus ")
        return {t for t in cleaned.split() if t}

    input_tokens = _tokens(key)
    if input_tokens:
        hits = [
            c for c in cache.categories
            if input_tokens.issubset(_tokens(c.name))
        ]
        if len(hits) == 1:
            return hits[0].id

    return None
```

Why token-match beats substring: "AFX G Plus" → tokens `{afx, g, plus}`. "Aurora G-Plus" → tokens `{aurora, g, plus}`. Not a subset — does NOT match. That's correct: "AFX" and "Aurora" are different words and the resolver should not guess. The fix for that case is the explicit alias (Change 2b), not clever matching.

Conversely, "G Plus" → `{g, plus}` → matches "Aurora G-Plus" uniquely (since "Aurora G-Plus" is the only category containing both tokens). That's the win over v1's substring layer — it handles partial customer phrasings without false hits.

**Change 2b — exhaustive seed aliases for known customer phrasings (same file, `SEED_ALIASES`):**

Audit the cached category list (208 entries) once, seed every chassis-family the customer might name differently than the catalog. Starting set for this fix:

```python
    # AFX / Aurora / Tomy cross-brand aliases — same chassis, different
    # brand prefixes customers use. Category 522 is "Aurora G-Plus" on
    # the site but customers call it AFX G-Plus interchangeably.
    "afx g-plus": 522,
    "afx g plus": 522,
    "aurora g-plus": 522,
    "aurora g plus": 522,
    "tomy g-plus": 522,
    "tomy g plus": 522,
    "g-plus": 522,
    "g plus": 522,
```

A broader alias audit across all chassis families is tracked as a separate follow-up (see §Out-of-scope).

---

### Fix 3 — Step 0 in catalog-lookup: consult customer-terminology first (Task #3)

**Closes a documented-but-unused gap.** `customer-terminology.md:5` claims "Marshall consults this file *before* querying the catalog." No step in `catalog-lookup/SKILL.md` actually does this. Two places to define the same behavior = drift risk.

**File:** `.claude/skills/catalog-lookup/SKILL.md`

**Change:** Insert new Step 0 immediately after the "When to invoke / When NOT to invoke" tables, before current Step 1:

```markdown
## Step 0 — Translate customer aliases first

Before classifying or querying, read `knowledge/product-rules/customer-terminology.md` and substitute any known aliases in the customer's message with the catalog term. Example: if the customer wrote "Cortin," mentally substitute "Core 10" before Step 1.

This matters because:
- The resolver's alias layer only covers chassis/brand names (hardcoded in `cache.py`).
- Customer product nicknames, misspellings, and brand-cross names live in `customer-terminology.md` and will drift as Dan teaches new ones.
- Skipping this step produces `chassis_not_found` or empty searches on known-alias inputs, which then cascades into a Branch C draft when the answer should have been a direct hit.

If the message contains no known alias, proceed to Step 1 unchanged.
```

---

### Fix 4 — Decision tree: three-branch zero-count path (Task #5, template coupling)

**File:** `.claude/skills/catalog-lookup/SKILL.md`

**Change 4a — Step 4 count-0 row (lines 182–190):**

```
| `0` | Go to **Step 5 ambiguous-or-clean-no path** (decide per rule check) |
```

**Change 4b — replace "Step 5 clean-no path" (lines 230–256) with:**

```markdown
## Step 5 — Ambiguous-or-clean-no path (count=0)

Zero results has three possible meanings. Decide in order.

### Branch A — Rule-backed clean-no

Check rule files in order:
- `knowledge/product-rules/tire-compatibility.md` — chassis on the don't-stock list (HP7, HP2, Curvehugger, Aurora AX, or similar)?
- `knowledge/product-rules/discontinued-alternatives.md` — discontinued with a documented replacement?
- `knowledge/product-rules/chassis-compatibility.md` — cross-compat rule pointing to a different product?

**If a rule applies:**
- Draft: "Unfortunately, we don't carry anything for the [chassis]." Full stop. NO eBay/Amazon/other-retailer suggestion — this was superseded 2026-04-16 (see `context/policies.md` §Never Redirect Customers to Other Retailers). If `discontinued-alternatives.md` has an in-house replacement, suggest that instead.
- Internal note: confidence HIGH. Cite rule source by plain name.

Branch A is the ONLY branch where the draft asserts we don't carry it.

### Branch B — Customer cited a specific SKU that isn't in the catalog

- Draft: "We don't have SKU [X] in our catalog — could you double-check the number?"
- Internal note: confidence MEDIUM. SKU may be customer-misremembered, discontinued, or Dealer Exempt (filtered).

### Branch C — Ambiguous (default when no rule applies)

Most zero-counts without an explicit rule land here. Never draft a clean-no from ambiguity.

**Before drafting, determine resolver state:**

| Resolver state | How the draft acknowledges its lookup |
|---|---|
| Chassis resolved, `list --category` returned 0 or wrong parts | "I looked under our [chassis] parts and didn't see [part] listed." The AI *did* look — this phrasing is honest. |
| `chassis_not_found` (resolver failed) | "I don't have [chassis] in our parts index — which chassis family is it from?" The AI did NOT look at products — "I looked for X" would be misleading. |

This coupling matters: the template phrasing is only honest when it matches what the tool actually did. The resolver fix (Fix 2) widens the "resolved" column; the fallback row covers cases the resolver genuinely can't handle.

**Four-part template:**

```
Hey [name] —

[Acknowledgment line — per resolver state above, referencing the
customer's terms verbatim where possible.]

Before I point you wrong, could you tell me [ONE variable — chassis
variant, year, or part nickname]?

In the meantime, here's our [category] page in case it's listed under
a name I didn't match: [permalink]
```

Rules:
- **One clarifying question.** Not two. Pick the single variable most likely to unblock the answer.
- **Category link as P.S., not pivot.** Use the best plausible category from the resolver state. If the resolver failed entirely and no plausible parent category exists, omit the P.S. and use the escalation fallback below.
- **No "let me double-check with Dan."** That's theater — the reviewer hasn't acted yet.

**Escalation fallback** (use when the clarifying question + category link won't plausibly resolve):

> "I'll flag this for Dan to take a look at and get back to you."

This maps to Abby's actual pending-folder workflow (`context/business-profile.md:27`). It is a real mechanism, not invented — Abby reviews the draft, routes the email to the pending folder, Dan reviews on his next pass. Do not use this as the default; it taxes the reviewer.

**Internal note (Branch C):**
- Confidence: MEDIUM.
- Literal CLI commands run, terms passed.
- Resolver state (resolved to category X, or `chassis_not_found`).
- Closest near-matches (category ID, name, product count).
- Which variable the clarifying question is asking and why.
- Suggested reviewer action: "If customer replies with [variant], re-run `find --chassis [variant] --part [part]`. If this phrasing recurs, `/teach` an alias."

### Do NOT (across all branches)

- Invent alternatives without rule backing.
- Guess at compatibility (guardrail #9).
- Say "let me double-check with Dan" (theater). Use the escalation fallback phrasing instead.
- Suggest eBay, Amazon, or any other retailer (`policies.md:54-59`).
- Write "we don't carry it" unless Branch A applies.
```

**Change 4c — `chassis_not_found` row in the error-path table (lines 263–270):**

```
| `chassis_not_found` | Treat as ambiguous (Step 5 Branch C, resolver-failed row). Use the "I don't have [chassis] in our parts index" phrasing. Scan cached categories for a plausible parent before drafting. | Record which phrasing failed to resolve. If it's a pattern, propose a new alias for `cache.py` SEED_ALIASES or a new entry in `customer-terminology.md`. |
```

---

### Fix 5 — `draft-reply` delegates, doesn't duplicate (Task #5)

**File:** `.claude/skills/draft-reply/SKILL.md`

**Change:** Step 3 `count == 0` clause (lines 98–99):

```
**If `count == 0`:** do not draft a clean-no from zero-count alone. Follow `.claude/skills/catalog-lookup/SKILL.md` Step 5's three-branch decision (A: rule-backed clean-no, B: SKU-not-found, C: ambiguous four-part template). Branch C is the default when no rule applies.
```

The canonical example at lines 246–304 uses older phrasing. Refresh it in a follow-up PR to match the four-part template. Keep this diff focused.

---

### Fix 6 — Regression harness (Task #6)

**File:** `scripts/wc-regression.sh` (new)

Replaces manual spot-checks. Runs four cases and prints pass/fail:

| # | Case | Expected |
|---|---|---|
| 1 | AFX G-Plus armature | Resolves to category 522, `count=0` (category holds Motor Magnets + Pickup Shoes, no armatures). NOT `chassis_not_found`. |
| 2 | HP7 tires | `chassis_not_found` from CLI. Skill harness then checks `tire-compatibility.md` — HP7 is on the don't-stock list → Branch A clean-no. |
| 3 | "armature" alone | `chassis_not_found`. Six "Armatures" categories exist; token-subset is ambiguous → resolver must return None, not guess. |
| 4 | Mega G+ rear tires | Resolves to category 89, non-zero result. Positive control. |

Case 2 tests the skill's rule-check logic beyond the CLI; the other three test the CLI/resolver directly. Re-run after any future resolver change.

---

### Fix 7 — `customer-terminology.md` entry (Task #2 companion)

**File:** `knowledge/product-rules/customer-terminology.md`

Document the AFX G-Plus alias for human visibility (the SEED_ALIASES dict handles the code path; this file handles the Dan/Abby discoverability).

```markdown
### "AFX G-Plus" / "Aurora G-Plus" / "Tomy G-Plus" / "G-Plus"

- **Maps to:** Category 522 (Aurora G-Plus) — parent: Aurora/Tomy/AFX (id=36)
- **Source:** Customer email 2026-04-19 asked "armature for e AFX G Plus." CLI returned `chassis_not_found` because the category is named "Aurora G-Plus." Council deliberation determined this is an alias issue, not a clean-no.
- **Notes:** Category currently has 2 products (Motor Magnets, Pickup Shoes — no armatures). Customers call this chassis by all three brand prefixes because Aurora was acquired by Tomy/AFX; the product name didn't update when the brand did. Do NOT confuse with "Mega G+" (id=89) or "Super G+" (id=69).
```

---

## Verification

Run `bash scripts/wc-regression.sh` (Fix 6). All four cases must pass.

Additional post-fix checks:

- Re-send the original AFX G-Plus customer message through `/draft-reply`. Draft must use the four-part template, the "I looked under our AFX G-Plus parts and didn't see armatures listed" phrasing, one clarifying question, Aurora G-Plus category link as P.S. No "try eBay."
- Re-send an HP7 tire message (from `tire-compatibility.md` don't-stock list). Draft must say "Unfortunately, we don't carry anything for the HP7" with no trailing eBay pointer.

---

## Out-of-scope (tracked, not in this diff)

- **Fix stale eBay phrasing in `tire-compatibility.md`.** That file still references "Best bet's eBay" (line ~46) — superseded by `policies.md:54-59` on 2026-04-16. One-line fix, but it's a knowledge-layer cleanup, not a code/skill change. File separately.
- **Broader chassis-family alias audit.** Fix 2b seeds AFX/Aurora/Tomy G-Plus. Other families likely have the same issue (Tomy vs. AFX variants, Life Like prefixes, etc.). Sweep the 208-category list once and seed everything.
- **Refresh V3 magnet clip canonical example** in both skills to match the four-part template.
- **Category parent-walking in Branch C:** if the resolved category has zero products, walk up to parent and link that. Nice-to-have.
- **`/teach` writes to both `customer-terminology.md` and `SEED_ALIASES`.** Currently Dan/Abby updating one won't update the other. Drift risk. Separate design.

---

## Changes from v1

- **Dropped** substring-match resolver layer → replaced with token-subset.
- **Dropped** "best bet's eBay" phrasing in Branch A → replaced with clean "we don't carry it" per current policy.
- **Dropped** invented escalation fallback ("Dan may stock something that's not on the site") → replaced with Abby's real pending-folder workflow ("I'll flag this for Dan to take a look at").
- **Added** Fix 1 (query-log audit → explicit "no baseline, default to safer behavior" framing).
- **Added** Fix 3 (Step 0 closes the documented-but-unused terminology-consult gap).
- **Added** Fix 5b (template-resolver state coupling — the acknowledgment line depends on whether the AI actually got to the product search).
- **Added** Fix 6 (regression harness replaces manual spot-checks).
- **Removed** all open questions. Every v1 question resolved via policy/business-profile read.
