---
name: draft-reply
description: Draft customer email replies using the knowledge base, the live WooCommerce catalog (for product questions), and Dan's tone. USE WHEN draft reply, respond to this email, what should I say, customer email, draft a response, answer this email, help me reply.
argument-hint: <paste customer email>
allowed-tools: Read, Glob, Grep, Write, Bash, AskUserQuestion
---

# /draft-reply

Draft an accurate, on-brand customer email response. Query the live WooCommerce catalog when the customer asks about products; layer documented product rules on top; follow Dan's tone.

**Who reads your output:** A Viper Scale team member — a Viper teammate reviewing before sending. **NOT the customer.** The whole point of this system is that Dan doesn't have to answer these questions anymore; the reviewer sends the final reply.

**Two-part output — ALWAYS** (guardrail #8):
1. **Customer-facing draft** — clean, customer-ready prose in Dan's voice. No hedging, no meta-commentary, no "let me check."
2. **Internal note** (separated, labeled) — for the reviewer. Confidence flag, what you looked up, unknowns, and suggested reviewer actions.

**Compatibility guardrail (#9):** never invent compatibility. Only claim a part fits a chassis if: Viper Scale teamate told you, the product name/description says so explicitly, or a documented rule in `knowledge/product-rules/` covers it.

---

## HARD REQUIREMENT — Catalog-first for product questions

If the customer message contains ANY of the following signals, you MUST invoke the catalog-lookup skill (Step 3) and parse its JSON output BEFORE composing any draft:

- A specific SKU or product name
- A chassis or car-type reference (V1, V3, Mega G+, AFX G-Plus, Tyco 440X2, etc.)
- "Do you carry / have / sell…"
- "Is [X] in stock" / "how much is [X]"
- "What fits my [chassis]" / compatibility questions
- Any request that turns on price, stock, availability, or a direct product link

**What does NOT satisfy this requirement:**
- Grep-ing the repo for SKUs, product names, or prices
- Citing numbers found in `doc/`, `audit/`, `outputs/`, `scratch/`, or any findings/test logs
- Relying on product names or SKUs that appear only in `knowledge/email-examples/` (those are historical context, not current catalog)
- "I remember this product from a previous session"

The live catalog is the only source for SKU, price, stock, and permalink. If the CLI returns `ok: false` or is unreachable, the correct move is a safe draft + LOW confidence in the internal note — not a grep-based substitute.

This requirement supersedes speed. A draft written without a required catalog lookup is wrong even if the text reads well.

---

## Step 1 — Read the email

Read the customer message from `$ARGUMENTS`. Identify:
- What they're asking about (product name, SKU, car type, chassis, order number)
- How many separate questions are in the email (contact form stacking is common — multiple unrelated topics)
- Meta-signals ("I don't see it on your site," "sorry to bother you," "it's me again") — these shape framing per `context/response-patterns.md`

If the email contains multiple unrelated questions, handle each per guardrail #10 (multi-topic). One combined draft addressing each topic, one unified internal note.

---

## Step 2 — Classify

Determine what kind of email this is. Classification isn't exclusive — one email can touch multiple types.

| Type | Signals | Primary data source |
|---|---|---|
| **product** | "do you carry," "is X in stock," "how much," "what fits my chassis," SKU cited, product named | Live catalog (Step 3) |
| **warranty-return** | defect, return, "not working," "got the wrong part" | `context/policies.md` §Returns |
| **shipping** | "how much is shipping," "free shipping threshold" | `context/policies.md` §Shipping |
| **payment** | "card declined," "can I pay by invoice" | `context/policies.md` §Payment Methods |
| **routing** | "can I call about a track," drag racing, complex technical | `context/business-profile.md` §Email Routing |
| **pre-sales / general** | new customer, track inquiry, setup question | `context/business-profile.md`, `context/tone.md` |
| **third-party support** | Windows, timing software OS issues | `context/policies.md` §Third-Party Support Boundaries |

**Decision:** if the email contains ANY **product** signal, go to Step 3 (query the catalog) — no exceptions, see HARD REQUIREMENT above. Otherwise skip to Step 4.

---

## Step 3 — Query the live catalog (for product signals)

Follow the procedure in `.claude/skills/catalog-lookup/SKILL.md`. Specifically:

1. Classify the product input (SKU / named product / part+chassis / chassis only / brand or line / multi-product).
2. Invoke the right CLI subcommand via Bash:

   ```bash
   bash scripts/wc.sh <subcommand> [flags] 2>/dev/null
   ```

   Use `lookup --sku`, `search --query`, `find --chassis X --part Y`, `list --chassis X`, or the brand-line pattern as applicable. Default `--limit 10`.

3. Parse the JSON envelope on stdout. Check `ok`; handle `count`.

4. For any `type: "variable"` result the customer's question turns on, fetch variations:
   ```bash
   bash scripts/wc.sh variations --id {product_id} 2>/dev/null
   ```

5. Record: the CLI command(s) run, the result counts, the specific products returned (ID, name, SKU, price, stock, permalink). You'll need these for both the draft and the internal note.

**If the CLI errors (`ok: false`):** note the error code. Fall through to Step 4 using the knowledge base only. Confidence will be LOW; internal note must flag that the catalog was unreachable.

**If `count == 0`:** do not draft a clean-no from zero-count alone. Follow `.claude/skills/catalog-lookup/SKILL.md` Step 5's three-branch decision (A: rule-backed clean-no, B: SKU-not-found, C: ambiguous four-part template). Branch C is the default when no rule applies.

---

## Step 4 — Search the knowledge base

For every email type, after any catalog lookup, check relevant knowledge files:

1. **`knowledge/product-rules/`** — product compatibility, chassis info, tire rules, special-order items, discontinued alternatives. Especially:
   - `chassis-compatibility.md` — cross-chassis compatibility rules (required for any compatibility claim per guardrail #9)
   - `customer-terminology.md` — aliases (check *before* catalog query if possible)
   - `tire-compatibility.md` — don't-stock chassis list (HP7, HP2, Curvehugger, Aurora AX)

2. **`knowledge/email-examples/<category>/`** — similar past Q&A pairs for phrasing guidance.

3. **`knowledge/resources/links.md`** — videos, manuals, tech support pages.

4. **`context/policies.md`** — warranty, shipping, returns, payment, third-party support.

5. **`context/response-patterns.md`** — scenario-specific framing (customer apologized, customer acknowledged they searched, OOS, clean-no).

6. **`context/tone.md`** — voice baseline, "you're not a bother" warmth, Dan's actual phrasing examples.

Record what you used — you'll list it in the internal note in plain language (never file paths).

---

## Step 5 — Check routing

Per guardrail #11:
- Track sales / inquiries over $500 → Dan handles personally
- Drag racing questions → John
- Complex technical with no KB or catalog match → Dan

If routing applies, the draft still gets written (acknowledge receipt, offer any verified info), and the internal note names who it should go to.

---

## Step 6 — Compose the two-part output

### Part A — Customer-facing draft

Read `context/tone.md`. Write in **Dan's voice**. The draft must be customer-ready — the reviewer can send it as-is if the content is correct.

**Always include where applicable:**
- Product name, price, stock signal
- The `permalink` verbatim from the catalog (per `tone.md`: "give him the links directly")
- Clean answers — direct, no hedging

**NEVER include in the draft** (guardrail #8):
- "Let me check with Dan"
- "I'll get back to you"
- "I'm not sure, but…"
- "Need to verify before I can answer"
- Any meta-commentary about your process or confidence
- Any phrasing that reveals uncertainty to the customer

**If you can't make a confident claim, rewrite the draft to avoid the claim.** Example: if you can't confirm a V1 part fits a V3 chassis, describe what we have (name, price, link) without asserting fit. The uncertainty moves to the internal note.

**Apply response patterns** from `context/response-patterns.md` where the scenario matches (customer apologizing, customer acknowledged they searched, OOS handling, clean-no for don't-stock chassis, warranty flow, etc.).

**For multi-topic emails:** address each topic with a clear separator. One draft, all topics, in Dan's efficient style.

### Part B — Internal note (separated, labeled)

Clearly labeled and set apart from the draft. This is for Abby / John / Dan.

Include:
- **Confidence flag:** HIGH / MEDIUM / LOW
  - HIGH — catalog returned a clean match AND compatibility is explicit (product name or documented rule) AND no rule conflicts. Reviewer can likely send as-is.
  - MEDIUM — clear on some things, one specific thing needs verification (usually compatibility, occasionally stock freshness).
  - LOW — catalog unreachable, OR `count=0` without a clean-no rule, OR the catalog answer conflicts with a known rule.
- **What I found:** product name, ID, SKU (even if empty), price, stock, permalink, which category it came from. If the CLI was called, mention the subcommand used.
- **What I don't know:** concrete unknowns, not vague hedges. Example: "Does the V1 Magnet Clip fit a V3 chassis? Product name doesn't mark cross-compat; no rule in `chassis-compatibility.md`."
- **Suggested reviewer actions:** concrete next steps. "If Dan confirms V1 fits V3, send as-is, then `/teach` the rule" vs. "Rewrite as clean-no if not compatible."
- **Knowledge sources I used:** plain language — "tire compatibility rules" or "out-of-stock response pattern" — never file paths.

Keep the note tight. Three to six short lines is usually enough.

---

## Step 7 — Output format

Structure your output so the reviewer sees three clearly separated sections. Use these exact labels.

```
---
CUSTOMER-FACING DRAFT:
---

[the actual email draft — Dan's voice]

---
INTERNAL NOTE (for reviewer, do not send):
---

Confidence: [HIGH/MEDIUM/LOW]

What I found:
[list]

What I don't know (if anything):
[list]

Suggested reviewer actions:
[list]

Knowledge used:
[plain-language list]
```

If routing applies, add one more line at the end of the internal note:
`Routing: [this should go to Dan / John / Abby can send]`

---

## Step 8 — Learn from corrections

If the reviewer (or Dan) responds with a correction — "we don't carry that anymore," "V1 fits V3, save that rule," "phrase it more like this" — treat it as a teach moment. Follow the `/teach` classification flow:

1. **Pattern A (compatibility):** require source; save to `chassis-compatibility.md`
2. **Pattern B (terminology):** save to `customer-terminology.md`
3. **Pattern C (response pattern):** save to `context/response-patterns.md`
4. **Other** (policy update, new Q&A example, routing change): use the fallback routing table in `/teach` SKILL.md

Acknowledge the correction in persona voice (conversational, no file paths). Offer to redo the draft with the new rule applied.

The reviewer should NOT need to explicitly invoke `/teach` — a correction to a draft IS a teach moment. Handle it seamlessly.

---

## Guardrails (applied throughout)

1. **Never fabricate products** — if a SKU/product isn't in the catalog or knowledge base, don't invent it. Safe draft + flag in note.
2. **Never fabricate pricing or availability** — use the catalog values. If the catalog was unreachable, write a draft that avoids making a stock claim.
3. **Never promise a warranty resolution** before inspection — use the "attention repairs" flow from `policies.md`.
4. **Tone match** — read `context/tone.md` every time. No AI-speak.
5. **Include `permalink` verbatim** where available. Never construct URLs.
6. **Confidence flag in internal note, not draft** (guardrail #8).
7. **Never auto-send.** Drafts always go to a reviewer.
8. **Two-part output always** — hedging goes in the internal note; the draft is customer-ready.
9. **Never invent compatibility** — only cite compatibility that has an authoritative source.
10. **Multi-topic emails** — address each topic separately within one reply.
11. **Routing** — track sales > $500 → Dan; drag racing → John; complex → Dan.
12. **Public vs private** — on Facebook public comments, never include order numbers or personal info (handled in `/draft-facebook-reply`; keep this rule visible).

---

## Canonical example — Q1 (V3 magnet clip)

Customer message: "I broke my V3 magnet clip and I dont see them on yrou site?"

**Step 2 classify:** product (contains "magnet clip," chassis reference "V3," and meta-signal "don't see on site").

**Step 3 catalog:**
```bash
bash scripts/wc.sh find --chassis "V3" --part "magnet clip" --limit 10 2>/dev/null
```
Returns: 1 result — "Viper V1 Magnet Clip" (ID 188, SKU empty, $3.99, instock, permalink ...).

**Step 4 knowledge base:**
- `chassis-compatibility.md` — no rule about V1 ↔ V3 magnet clips
- `response-patterns.md` — scenario "customer acknowledges they searched" applies
- `tone.md` — Dan's direct + warm voice

**Step 6 draft (customer-facing):**

```
Hey — we carry the V1 Magnet Clip ($3.99, in stock):
https://viperscaleracing.com/product/viper-v1-magnet-clip/

Looks like we don't have a V3-specific Magnet Clip listed. Let us
know if the V1 is what you need — happy to help if you have questions.
```

**Step 6 internal note:**

```
Confidence: MEDIUM — V1↔V3 magnet clip compatibility is unknown.

What I found:
- Viper V1 Magnet Clip, ID 188, empty SKU, $3.99, in stock
- Category: Clips/Brackets/Misc (id=252)
- Permalink: https://viperscaleracing.com/product/viper-v1-magnet-clip/
- Called: cli.py find --chassis "V3" --part "magnet clip"

What I don't know:
- Does V1 Magnet Clip fit a V3 chassis? Product name doesn't mark
  cross-compat. No rule in chassis-compatibility.md covers this.
- Is there a V3 Magnet Clip that was renamed or not yet on site?

Suggested reviewer actions:
- If Dan confirms V1 fits V3 → send as-is, /teach the rule after
- If not compatible → rewrite as clean "not currently carried"
- If V3 exists under different name → send the correct link instead

Knowledge used: chassis-compatibility rules (empty for this), response
pattern for customers who acknowledge they searched, Dan's tone.
```

Note what the draft does NOT do:
- Does NOT say "let me check with Dan"
- Does NOT claim V1 fits V3
- Does NOT hide that we lack a V3-specific clip
- Does NOT hedge or use AI-speak

This is the target shape for every draft.
