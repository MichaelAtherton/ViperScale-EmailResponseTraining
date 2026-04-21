# WooCommerce Integration — Implementation Roadmap

**Purpose:** The single living document that captures everything still to build for the WooCommerce catalog integration. Each item has: scope, files touched, decisions open, outcome-based done criteria, dependencies (with consequences of skipping), and links to the detailed spec docs.

**Written:** 2026-04-16
**Status:** Phase 0 (empirical check) complete. No production code written yet.

---

## Quick status

| # | Item | Status | Size | Can skip? |
|---|---|---|---|---|
| 0 | Pre-build empirical check | ✅ Done | — | N/A |
| 1a | Spec revision: roll findings into `implementation-spec.md` | ✅ Done | S | No — blocks all code |
| 1b | Verify `api-reference.md` checklist against live data | ✅ Done | S | Yes for v1; surfaces issues later |
| 2 | `catalog-lookup` SKILL.md | ✅ Done | M | No — blocks orchestration |
| 3 | `/teach` redesign (incl. scaffolding files) | ✅ Done | M | Yes for first draft; blocks learning |
| 4 | Python client (`integrations/woocommerce/`) | ✅ Done | L | No — blocks live queries |
| 5 | Wire `catalog-lookup` into `/draft-reply` | ✅ Done | M | No — without it, client is unused |
| 6 | Pilot against real customer emails | ⬜ | M–L | No — validation gate |

**Size legend:** S ≈ under 1 hour • M ≈ half-day of focused work • L ≈ 1-2 days with distractions. Real time varies with fluency, interruptions, and what we find along the way.

## Related docs (read alongside this roadmap)

- [`implementation-spec.md`](./implementation-spec.md) — the build spec Michael codes from. Being revised in Step 1a.
- [`api-reference.md`](./api-reference.md) — endpoint + field reference. Verified in Step 1b.
- [`use-cases.md`](./use-cases.md) — customer questions → API call patterns.
- [`data-audit.md`](./data-audit.md) — empirical audit template (filled during Step 4 testing).
- [`findings-log.md`](./findings-log.md) — running record of live-API findings. Input to Step 1.
- [`../../.claude/src/assistant-persona.md`](../../.claude/src/assistant-persona.md) — voice rules (two-part output, no hedging in drafts).
- [`../../.claude/src/guardrails.md`](../../.claude/src/guardrails.md) — non-negotiable rules, especially #8 (two-part output) and #9 (never invent compatibility).

## Canonical example

Everything we build should produce output shaped like the Q1 worked example in [`findings-log.md`](./findings-log.md) — "2026-04-16 — Customer question test: Q1 'V3 magnet clip'". That's the concrete target for Step 5's `/draft-reply` output.

---

## What's explicitly NOT in v1 scope

These have all come up and been deferred deliberately. Not building any of them now:

- Diagnostic → product recommendation ("my car is doing X, what do I need?")
- Upsell logic ("you're $3 from free shipping")
- Cart / order context awareness (current cart, order history)
- Order lookup / "where's my order?" integration
- Write operations (creating products, updating stock, creating drafts)
- Webhooks or real-time push sync
- Facebook DM/comment catalog queries (email only for v1)
- Dan-correction override layer across sessions (flagged as Phase 2 in spec)
- Full catalog mirror / offline mode
- Recommendation engine or compatibility chain traversal

If any of these come up during pilot, they go on a Phase 2 list — don't slip them into v1.

---

## Step 0 — Pre-build empirical check ✅ DONE

- 20+ live queries via scripts in `scripts/` → `scratch/`
- 681 published products, 204 categories across 3 pages
- Auth, HTTPS, pagination, pretty-permalinks confirmed working
- Draft-leak bug found (requires `status=publish`)
- Category-scoped queries identified as the workhorse pattern
- Q1 customer-question test ran end-to-end with the corrected two-part output
- All findings in [`findings-log.md`](./findings-log.md)

---

## Step 1a — Spec revision: roll findings into `implementation-spec.md`

**Goal:** Make `implementation-spec.md` reflect empirical reality, not generic WooCommerce docs.

**Size:** S. Mostly editing.

**Files touched:**
- `doc/woocommerce/implementation-spec.md`

**Concrete changes:**

| Area | Change |
|---|---|
| All `/products` endpoint examples | Add `status=publish` to default query string |
| Section 6.6 (category cache) | Paginate all 3 pages (204 categories for Viper, not 100) |
| Section 6.6 | Add alias map: customer name → category ID. Key by slug since multiple categories share names |
| Section 7 (CLI subcommands) | Add new `find` subcommand: `--chassis` + `--part` flags. Resolves chassis via cache, runs category-scoped search |
| Section 8.5 (disambiguation) | Add BeadLok + Super G case as canonical "requires chassis-family knowledge" example |
| Section 9 (SKILL.md) | Apply guardrail #8 throughout (done in prior edit pass — verify it stuck) |
| Section 9 | Apply guardrail #9 (never invent compatibility) as an explicit branch in the decision tree |
| New section | Dealer Exempt filtering: interim "filter by default, flag for Dan review" |
| Section 10 (test plan) | Update test cases to use real SKUs discovered during empirical check (e.g., SKU 11065 "6 ohm Tyco-Timed Armature") |

**Decisions open:**
- Dealer Exempt handling — interim assumption is "filter out by default." Needs Dan confirmation eventually; not a blocker now.
- Chassis alias seed list — my lean: seed with the 6 verified chassis (Mega G+ → 89, Super G+ → 69, Tyco 440X2 → 38, AFX → via slug, JAG → 45, Life Like → 40). Low risk since these are directly observed.

**Depends on:** Nothing.

**If skipped:** Python client (Step 4) gets built against the pre-empirical spec. Discovery of draft-leak bug happens after coding, causing a refactor of every query-building call-site. Misses the `find` subcommand entirely. Estimated cost of skipping: half a day of Michael's rework.

**Done when — outcome-based:**
- A developer reading only `implementation-spec.md` would build a client that, on first run against viperscaleracing.com, (a) never returns draft products, (b) correctly resolves "Mega G+" → category 89, (c) has a `find` subcommand that answers "rear tires for Mega G+" in one call, and (d) doesn't stop category pagination at 100.

---

## Step 1b — Verify `api-reference.md` checklist against live data

**Goal:** The verification table in section 9 of `api-reference.md` has `[VERIFIED 2026-04-16]` tags for every endpoint and field we actually confirmed.

**Size:** S.

**Files touched:**
- `doc/woocommerce/api-reference.md`

**Decisions open:** None.

**Depends on:** Step 0 (done).

**If skipped:** No immediate functional impact. Consequence is that future maintainers can't distinguish what's trusted from what's drafted-from-docs, so they may rebuild things to verify. Low cost if skipped for v1; higher cost if we ever need to debug a data-shape issue six months from now.

**Done when — outcome-based:**
- Someone debugging a WooCommerce integration issue in the future can look at section 9 and know within 30 seconds which fields/endpoints have been empirically confirmed on Viper's actual data.

---

## Step 2 — Build `catalog-lookup` SKILL.md

**Goal:** A skill definition that tells Enzo when and how to invoke the CLI. Can be written before any Python exists — the skill describes the interface, the CLI implements it.

**Size:** M.

**Files touched:**
- `.claude/skills/catalog-lookup/SKILL.md` (new)

**Structure (decision tree, not docs):**

1. Front matter with trigger phrases
2. When to invoke / when NOT to invoke
3. Input classification (SKU vs named product vs part+chassis vs chassis vs multi-product)
4. CLI invocation patterns per case
5. Result interpretation decision tree (0 / 1 / 2-3 / 4-6 / 7+)
6. Clean-no path with compatibility check
7. Two-part output enforcement (guardrail #8)
8. Error handling — API failure routes uncertainty to internal note, never draft
9. Compatibility guardrail reminder (guardrail #9)

**Decisions open:**
- Trigger phrase specificity — start narrow (my lean), tighten later. Alternative: start broad, risk false positives on non-product messages.
- Clarifying-question wording: examples only vs verbatim templates (my lean: examples).

**Depends on:** Step 1a (so references are correct).

**If skipped:** No skill means Enzo won't know to query the catalog from `/draft-reply`. Python client sits unused. **This is a blocker, not an optional step.**

**Done when — outcome-based:**
- Given three test customer questions — (a) "Is SKU 11065 in stock?" (b) "Do you have rear tires for my Mega G+?" (c) "What builders kits do you carry?" — a Enzo reading only this skill produces a two-part output (clean draft + internal note) for each, invoking the correct CLI subcommand with correct params, without hedging phrases in the draft.

---

## Step 3 — `/teach` redesign + scaffolding files

**Goal:** `/teach` classifies knowledge as Pattern A (compatibility) / B (terminology) / C (response shape), enforces per-pattern guardrails, and files correctly.

**Size:** M.

**Files touched:**
- `.claude/skills/teach/SKILL.md` (rewrite)
- `knowledge/product-rules/chassis-compatibility.md` (new, empty scaffolding)
- `knowledge/product-rules/customer-terminology.md` (new, seed with 2-3 verified aliases from `tone.md`)
- `context/response-patterns.md` (new, seed with 2-3 patterns already in `tone.md`)

**New `/teach` flow:**

1. Receive the teach statement
2. Classify (A/B/C or ambiguous) via heuristics
3. If ambiguous → ask one disambiguating question
4. Apply per-pattern guardrails:
   - A: require source ("did you confirm this, or is it on the site?"). Save with source line. No source, no save.
   - B: save directly with date
   - C: save directly with date
5. File to the right location
6. Check for contradictions with existing rules
7. Confirm + prompt for more
8. Optional back-apply to a recent draft if relevant

**Decisions open:**
- Proactive teach prompts after LOW-confidence drafts (my lean: yes, end of draft only)
- Pattern-spanning teaches — split into multiple entries (my lean) or keep unified
- `context/response-patterns.md` in `context/` vs `knowledge/` — my lean: `context/`, since it's about voice/framing which is Dan's style baseline

**Depends on:** Step 1a (so `/teach` knows where compat rules should live per the spec).

**If skipped:** System can answer product questions (given Steps 2, 4, 5) but can't improve over time. First pilot email that surfaces a compat gap can't be captured as a rule. Learning system doesn't exist yet — we have a query system only. **Skippable for first working draft; not skippable for a learning system.**

**Done when — outcome-based:**
- Given three sample teaches — (a) "the V1 magnet clip fits V3, I just confirmed" (b) "when customers say 'brushless motor' they probably mean a Tyco-timed armature" (c) "if someone says they can't find something on the site, acknowledge they looked before answering" — the redesigned `/teach` correctly classifies each, asks for source on (a), files each to the right file, and confirms back.

---

## Step 4 — Build the Python client

**Goal:** Production read-only WooCommerce client Enzo calls via Bash.

**Size:** L. Depends heavily on the builder's Python + WooCommerce familiarity. If Michael has built an HTTP client in Python recently, lower end. Fresh start, higher end.

**Files to create in `integrations/woocommerce/`:**

| File | Purpose |
|---|---|
| `__init__.py` | Package marker, version |
| `config.py` | `.env` loading, validation, `WCConfig` dataclass, `ConfigError` |
| `client.py` | `WCClient` class: auth, retry, pagination, typed exceptions |
| `cache.py` | Category cache at `.claude/cache/wc-categories.json`, alias resolver |
| `cli.py` | Subcommands: `lookup`, `search`, `list`, `find`, `categories`, `get`, `variations` |
| `requirements.txt` | `requests`, `python-dotenv` |
| `README.md` | Setup, usage, debugging |

**Key behaviors (from spec, post Step 1a):**
- Always inject `status=publish` on `/products` queries
- Retry once on 429 (2s) and connection timeout (1s); fail fast on 4xx/5xx
- Log each call to `.claude/logs/wc-queries.jsonl`
- Strip HTML from descriptions, drop noise fields
- Standardized JSON envelope: `{ok, command, count, results, error?}`
- Exit 0 for success (including empty results); exit 1 for real errors

**Decisions open:**
- argparse (my lean) vs click
- Include descriptions in default output (my lean: no) vs require `--include-descriptions`
- pytest smoke tests (nice-to-have, not required)

**Depends on:** Step 1a.

**If skipped:** No live catalog data. Enzo can't answer product questions with current data. **Hard blocker.**

**Done when — outcome-based:**
- Running `python integrations/woocommerce/cli.py find --chassis "Mega G+" --part "rear tires"` returns a JSON envelope with `ok: true`, `count` between 5 and 15, and the top result's `name` contains "Mega G+" or is clearly a Mega G+ rear-tire product — within 3 seconds on a warm cache. All 7 manual tests from `implementation-spec.md` §10 pass.

---

## Step 5 — Wire `catalog-lookup` into `/draft-reply`

**Goal:** When Dan/Abby pastes a customer email, Enzo automatically decides whether catalog data is needed and fetches it silently.

**Size:** M.

**Files touched:**
- `.claude/skills/draft-reply/SKILL.md` (primary edit)
- Possibly `.claude/skills/draft-facebook-reply/SKILL.md` (deferred to later iteration — email only in v1)

**Orchestration model:** Silent. Dan/Abby paste email, get back draft + internal note. They don't see `catalog-lookup` ran.

**Changes to `/draft-reply`:**

1. Add classification step (catalog / policy / routing / tone / multi-topic)
2. If catalog needed, invoke CLI per `catalog-lookup` SKILL.md
3. Check `chassis-compatibility.md` + other rule files before drafting — never invent compat (guardrail #9)
4. Enforce two-part output (guardrail #8)
5. Confidence flag lives in note, not draft

**Decisions open:**
- Nested skill invocation vs internal orchestration — my lean: `/draft-reply` reads `catalog-lookup`'s content as orchestration guidance and invokes the CLI itself. One output per paste, not nested skill calls.

**Depends on:** Steps 2 and 4.

**If skipped:** The CLI and skill exist but `/draft-reply` doesn't use them. Customer questions continue answering from knowledge base only. **Hard blocker for v1.**

**Done when — outcome-based:**
- Q1 ("I broke my V3 magnet clip and I don't see them on your site") pasted into `/draft-reply` produces a two-part output matching the canonical example in `findings-log.md`: a clean customer-facing draft that gives the V1 Magnet Clip link without claiming V1 fits V3, AND an internal note with MEDIUM confidence and specific unknowns listed. No "let me check" phrases in the draft.

---

## Step 6 — Pilot against real customer emails

**Goal:** Validate the whole stack against real inbox content. Find and fix the real gaps.

**Size:** M–L depending on what we find.

**Process:**

1. Dan/Abby selects 10 real recent emails — 5 random + 5 "hard cases" they hand-pick
2. Run each through `/draft-reply`
3. Compare Enzo's draft to what was actually sent originally
4. Categorize failures:
   - Data gap → new `/teach`
   - Classification miss → tighten trigger phrases
   - Search failure → improve query logic
   - Tone drift → add response-pattern
   - Guardrail violation → fix decision tree
5. Apply fixes; re-test a subset
6. Repeat until Abby reports most drafts are send-ready with minor edits

**Decisions open:**
- Channel: email only in v1 (my lean) vs include Facebook
- Success measure: subjective Abby judgment ("would you send this?") until we have more data

**Depends on:** Steps 2, 4, 5. (Step 3 optional but recommended — without it, teach moments during pilot can't be captured.)

**If skipped:** Enzo ships to production without real-world validation. First bad draft goes to a real customer before anyone notices. **This is the validation gate. Don't skip.**

**Done when — outcome-based:**
- 10 real emails tested. At least 70% of drafts are send-ready with at most minor tone edits (Abby's judgment). Remaining failures are categorized, logged, and either fixed in this step or added to Phase 2 backlog. No guardrail #8 or #9 violations observed in any draft.

---

## Known risks

Likely failure modes and what we'd do about each.

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Search quality worse than expected in pilot | Medium | Medium | Q1-style iteration loop: categorize failures, improve `find` logic in CLI, re-test. Build Step 3 early so teach moments capture terminology fixes. |
| WooCommerce schema drift between sessions | Low | Medium | Category cache freshness check (7 days). Manual `categories` refresh available. Log shape surprises to `findings-log.md`. |
| `.env` accidentally committed or pasted in a logged command | Low | HIGH | `.env*` already in `.gitignore` (verified line 21). Audit logs explicitly exclude credentials. Rotate keys immediately if ever exposed. |
| Pilot emails come from Abby's "easy" folder, giving false confidence | Medium | Medium | Explicit 5 random + 5 hard mix in Step 6. Any category (warranty, multi-topic, etc.) missing from test set → flag and add. |
| Classification right 80% of the time, 20% silently fail without catalog data | Medium | HIGH | Every draft's internal note states whether catalog was queried. Reviewer sees the metadata. Track classification accuracy during pilot. |
| Sucuri WAF starts rate-limiting during pilot burst | Low | Medium | Client has retry logic. If pattern appears, reduce concurrency, add inter-request delay. |
| Customer-facing draft leaks hedging phrases despite guardrail #8 | Medium (during pilot) | Medium | Explicit review criterion in Step 6 — count violations across 10 drafts. If any occur, fix the skill's decision tree before proceeding. |
| Compat guesses creep in despite guardrail #9 | Medium | HIGH | Review every compat-related draft in pilot. Any unverified compat claim → immediately fix the skill. Don't ship with a single violation. |

---

## Kill switch — how to disable catalog-lookup fast

If a bad draft ships or the catalog integration starts producing errors:

1. **Immediate (< 1 minute):** Rename `.claude/skills/catalog-lookup/SKILL.md` to `.disabled-SKILL.md`. Enzo falls back to knowledge-base-only answers.
2. **Medium-term (< 5 minutes):** Comment out the classification step in `/draft-reply` SKILL.md that routes product questions to `catalog-lookup`. Keeps the skill file intact for debugging.
3. **Auth compromise:** Rotate `WC_CONSUMER_KEY` and `WC_CONSUMER_SECRET` in WooCommerce admin. Update `.env`. Delete `.claude/logs/wc-queries.jsonl` if any logged request contained sensitive context.

Every change above is reversible and doesn't break the vault. The integration re-enables by reversing the step.

---

## Open questions blocking progress

These are waiting on Dan. Note the answers in `findings-log.md` when they come in; update files per the "resolution path" column.

| # | Question | Blocking step | Interim assumption | How answer gets back in |
|---|---|---|---|---|
| 1 | "Dealer Exempt" category (218 products) — retail-visible? | 1a, 4, 5 | Filter out by default | Michael asks Dan → log in `findings-log.md` → update spec §8.5 + CLI default in Step 4 |
| 2 | Chassis compatibility families — what counts as "inline"? etc. | 3, 5 | No pre-seeded rules; wait for teaches | Dan teaches each family individually → `/teach` saves to `chassis-compatibility.md` |
| 3 | Draft custom orders — filter from API results? | 1a, 4 | Yes, via `status=publish` | Already handled by spec update in Step 1a |
| 4 | Motor terminology aliases (e.g., "brushless") | 3, 5 | None seeded; wait for real customer question | Dan teaches at first pilot email that surfaces it → `customer-terminology.md` |

---

## Sequencing

**Parallel tracks possible:**

- **Track A (solo doc/skill work, can start now):** 1a → 2 → 3. Me. No code dependency.
- **Track B (code, after Step 1a):** 4. Michael or me. Largest single block of focused work.
- **Track C (validation, after Steps 2/4/5):** 6. Team pilot.

**Sequential bottleneck:**
1a → (2, 3 in parallel with 1a if desired) → 4 → 5 → 6

**Minimum viable draft** (catalog-aware replies, but no learning loop): 1a + 2 + 4 + 5.
**Minimum viable learning system** (drafts + `/teach` captures new knowledge): 1a + 2 + 3 + 4 + 5.
**Production-ready:** all of the above + 6.

**Recommended starting point:** Step 1a. Fastest unblocker for everything else.

---

## Change log for this roadmap

- **2026-04-16** — initial version after empirical check + Q1 test
- **2026-04-16** — revised: outcome-based done criteria, size t-shirts instead of hours, consequences-of-skipping for each dependency, merged scaffolding into Step 3, split Step 1 into 1a/1b, added canonical example pointer, "not in scope for v1" section, known risks, kill switch, answered-how column on open questions
