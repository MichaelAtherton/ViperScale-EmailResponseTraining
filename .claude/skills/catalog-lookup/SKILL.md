---
name: catalog-lookup
description: Query the live Viper Scale Racing catalog via the WooCommerce API for product existence, stock, price, categories, and variations. USE WHEN the customer message contains "do you carry", "do you have", "is X in stock", "how much is", "what fits", "what do you carry for", a specific SKU, or a specific product name.
argument-hint: <internal — invoked by /draft-reply, not user-facing>
allowed-tools: Bash, Read, Grep, Glob
---

# Catalog Lookup

**You are reading instructions for yourself.** Follow the decision tree below in order. This is not documentation — it's the step-by-step procedure you run every time you need live catalog data.

**Your output is always a two-part result per guardrail #8:** (a) a clean customer-facing draft in Dan's voice, and (b) a separate internal note for the reviewer. The draft never contains hedging phrases ("let me check," "I'll verify," "I'm not sure"). Uncertainty goes in the internal note only.

**Compatibility guardrail (#9):** never invent compatibility. Only claim a part fits a chassis if: Dan told you (via `/teach`), the product name/description says so explicitly, or a documented rule in `knowledge/product-rules/` covers it. Otherwise the draft states what we have without claiming fit, and the internal note flags the question.

---

## When to invoke

Invoke for customer messages that contain any of these signals:

- **Product existence:** "do you carry / have / sell / stock X"
- **Stock:** "is X in stock / available / back yet"
- **Price:** "how much is / what's the price of / cost of X"
- **Compatibility:** "what fits / works with / for my [chassis]"
- **Category browse:** "what do you carry for [chassis]"
- **SKU or product name** cited directly by the customer
- **Can't find on site:** "I don't see X on your site," "couldn't find X" — customer already searched

## When NOT to invoke

These have other homes. Don't query the catalog for them:

| Question type | Route to |
|---|---|
| Warranty / returns / refunds | `context/policies.md` |
| Shipping, free-shipping threshold | `context/policies.md` |
| Routing (track sales > $500, drag racing) | `context/business-profile.md` |
| Tone / greeting / apology | `context/tone.md` |
| Third-party tech support (Windows, timing software) | `context/policies.md` |
| Order status / "where's my order" | Not in v1 scope; route to reviewer |

---

## Step 0 — Translate customer aliases first

Before classifying or querying, read `knowledge/product-rules/customer-terminology.md` and substitute any known aliases in the customer's message with the catalog term. Example: if the customer wrote "Cortin," mentally substitute "Core 10" before Step 1.

This matters because:
- The resolver's alias layer (in `integrations/woocommerce/cache.py`) only covers chassis/brand names hardcoded there.
- Customer product nicknames, misspellings, and brand-cross names live in `customer-terminology.md` and grow via `/teach` as Dan confirms them.
- Skipping this step produces `chassis_not_found` or empty searches on known-alias inputs, cascading into a Branch C draft when the answer should have been a direct hit.

If the message contains no known alias, proceed to Step 1 unchanged. Do not narrate this step in the output — it's a silent pre-translation.

---

## Step 1 — Classify the input

Read the customer message (post-Step-0 translation). Identify what they gave you. Pick the first matching row:

| Customer gave you | Go to |
|---|---|
| An exact SKU (letters+numbers pattern, or customer said "SKU X") | **Step 2a** |
| A specific product name ("Magnet Traction Kit", "VSPEC Builders") | **Step 2b** |
| A part type + a chassis ("pinion for Mini-T", "rear tires for Mega G+") | **Step 2c** |
| Just a chassis ("what do you have for Super G+") | **Step 2d** |
| Multiple products in one message | Run the right step for each; combine results in Step 6 |
| A brand + maybe a part ("JAG Hobbies cars", "AFX armatures") | **Step 2e** |

---

## Step 2a — SKU lookup

```bash
bash scripts/wc.sh lookup --sku {SKU}
```

Interpret per Step 4. Then go to Step 5.

---

## Step 2b — Product name search

```bash
bash scripts/wc.sh search --query "{exact product name}" --limit 5
```

If the name is short or contains common tokens (single words like "motor", "clip"), expect noisy results — verify the top hit is actually relevant before using.

Interpret per Step 4. Then go to Step 5.

---

## Step 2c — Part + chassis (the workhorse)

Use the `find` subcommand. It resolves the chassis to a category ID via the cache, then runs a scoped search.

```bash
bash scripts/wc.sh find --chassis "{chassis}" --part "{part type}" --limit 10
```

Examples:
- `find --chassis "Mega G+" --part "rear tires"`
- `find --chassis "Super G+" --part "armature"`
- `find --chassis "Tyco 440X2" --part "clip"`

**If the CLI returns `error: "chassis_not_found"`:**
1. Check `knowledge/product-rules/tire-compatibility.md` — is this chassis on the don't-stock list (HP7, HP2, Curvehugger, Aurora AX, etc.)?
   - **Yes** → skip the rest of this step, go to Step 5 clean-no path.
   - **No** → try Step 2b with the customer's exact phrasing. If that also fails, proceed to Step 5 with `count=0`.

**If `count > 0` but NONE of the results match the part the customer asked about** (e.g., they asked for a "magnet clip" and results are builders kits and chassis, not clips):

The part likely lives in a cross-chassis part-type category. WooCommerce search on common tokens ("magnet", "clip", "motor") matches product **descriptions** too, which buries the actual part under cars and kits that mention those tokens. The reliable fallback is browsing cross-chassis part-type categories directly.

Try these in order:

1. **`Clips/Brackets/Misc` (id=252)** — home of cross-platform clips and small parts. Browse with:
   ```bash
   bash scripts/wc.sh list --category 252 --limit 30
   ```
   Filter the result client-side for the part term. Also check `Clips/Brackets/Misc - Super G` (id=254) for Super G+ variants.

2. **Chassis-specific part-type subcategories.** From `findings-log.md`, each major chassis has children like "Armatures" (slugs `armatures-electrical-mega-g`, `armatures-electrical-440x2`, etc.), "Electrical", "Front End Setups", "Magnets". If the customer asked for one of these specific parts and the scoped find missed it, try the chassis-specific part subcategory by ID.

3. **Plain text search** — usually worse than category browsing for these cases, but occasionally surfaces the product if its name contains all the query terms.

**If a matching product appears but is labeled for a different chassis** (e.g., "V1 Magnet Clip" when customer asked about V3):
- **Do NOT claim it fits** — guardrail #9.
- Go to Step 5: draft presents what we found without asserting fit; internal note flags the compatibility question for the reviewer.

**If none of the above surfaces a matching part** → treat as count=0 per Step 5 clean-no path.

Interpret per Step 4. Then go to Step 5.

---

## Step 2d — Chassis-only browse

```bash
bash scripts/wc.sh list --chassis "{chassis}" --in-stock --limit 20
```

(Or `list --category {id}` if you've already resolved the ID.)

Expect many results — you'll typically need to group or ask a clarifying question in Step 4.

Interpret per Step 4. Then go to Step 5.

---

## Step 2e — Brand or product-line search

Use this for brand questions ("JAG Hobbies cars") and product-line questions ("Builders Kits", "VSPEC", "Magnet Traction").

```bash
bash scripts/wc.sh search --query "{brand or line}" --limit 20
```

Or, if the brand/line has a known category:

```bash
bash scripts/wc.sh list --category {id} --limit 20
```

Known category IDs (from the cached alias map — expand over time):
- JAG → 45
- Builders Kits → 532
- Tyco → 37 (parent of 440X2)
- Drag Racing/Accessories → 18

Run `categories --hide-empty` first if you don't know whether the brand or line has a dedicated category. If it does, prefer `list --category` for cleaner results (search has false positives on common tokens).

Interpret per Step 4. Then go to Step 5.

---

## Step 3 — Handle variable products

For any result with `type: "variable"`:

```bash
bash scripts/wc.sh variations --id {product_id}
```

Use the variation data (not the parent) for stock and price in Step 5.

---

## Step 4 — Interpret `count`

The CLI returns `{ok, count, results}`. Apply this decision tree based on `count`:

| `count` | Action |
|---|---|
| `0` | Go to **Step 5 ambiguous-or-clean-no path** (decide per rule check) |
| `1` | Use the single result directly |
| `2-3` | Present all options briefly in the draft — name, price, link for each |
| `4-6` | Group by an obvious differentiator (variant, scale, chassis) if possible. If no clean grouper, present 2-3 most relevant and ask ONE clarifying question in the draft |
| `7+` | Always ask ONE clarifying question in the draft before listing anything. Never dump a long list |

**If `ok: false`:** go to **Step 5 error path**.

---

## Step 5 — Compose the two-part output

Always produce both parts. Never mix them.

### 5a — Customer-facing draft

In Dan's voice (read `context/tone.md` for email or `context/channels/facebook.md` for Facebook). The draft is customer-ready — the reviewer can send it as-is if they agree with it.

**Always include:** product name, price, stock signal (if in stock just say so; if OOS mention in-stock notifier + "we restock weekly"), and the `permalink` verbatim. Dan's explicit preference: "make it as easy as possible for him."

**Never include in the draft:**
- "Let me check with Dan"
- "I'll get back to you"
- "I'm not sure, but…"
- "Need to verify"
- Any meta-commentary about your confidence or process

**If you can't make a confident claim,** rewrite the draft to avoid the claim rather than hedging. Example: if you can't confirm a part fits a customer's chassis, describe what we have (name, price, link) without asserting fit.

### 5b — Internal note

Labeled and separated from the draft. For Abby / John / Dan (the reviewer).

Include:
- **Confidence flag:** HIGH / MEDIUM / LOW
  - HIGH — catalog returned a clean match, compatibility is explicit (via product name or a documented rule), reviewer can likely send as-is
  - MEDIUM — result is clear but one specific thing needs verification (typically compatibility)
  - LOW — API failed, or no rule to validate the claim the customer would need
- **What I found:** product name, ID, SKU (if present), price, stock, permalink, which category it came from
- **What I don't know:** the specific unknown questions (e.g., "Does V1 fit V3? Product name doesn't say; no rule exists")
- **Suggested reviewer actions:** concrete next steps (confirm with Dan, rewrite as clean-no, substitute alternative, etc.)

Keep the note tight. A good note is three to six short lines — not an essay.

---

## Step 5 — Ambiguous-or-clean-no path (count=0)

Zero results has three possible meanings. Decide in order — do not skip branches.

### Branch A — Rule-backed clean-no

Check rule files:
- `knowledge/product-rules/tire-compatibility.md` — chassis on the don't-stock list (HP7, HP2, Curvehugger, Aurora AX, or similar)?
- `knowledge/product-rules/discontinued-alternatives.md` — discontinued with a documented replacement?
- `knowledge/product-rules/chassis-compatibility.md` — cross-compat rule pointing to a different product?

**If a rule applies:**
- Draft: "Unfortunately, we don't carry anything for the [chassis]." Full stop. **No eBay, Amazon, or other-retailer suggestion** — superseded 2026-04-16 (`context/policies.md` §Never Redirect Customers to Other Retailers). If `discontinued-alternatives.md` has an in-house replacement, suggest that instead.
- Internal note: confidence HIGH. Cite rule source by plain name.

Branch A is the ONLY branch where the draft asserts we don't carry it.

### Branch B — Customer cited a specific SKU that isn't in the catalog

- Draft: "We don't have SKU [X] in our catalog — could you double-check the number?"
- Internal note: confidence MEDIUM. SKU may be customer-misremembered, discontinued, or Dealer Exempt (filtered by the CLI).

### Branch C — Ambiguous (default when no rule applies)

Most count=0 cases without an explicit rule land here. Never draft a clean-no from ambiguity.

**First, determine resolver state — the acknowledgment line depends on it:**

| Resolver state | Acknowledgment phrasing |
|---|---|
| Chassis resolved (`list` or `find` returned a `category_id`), but `count=0` or results don't match the part | "I looked under our [chassis] parts and didn't see [part] listed." The AI *did* look — this phrasing is honest. |
| `chassis_not_found` (resolver failed — no alias, slug, name, or unique token match) | "I don't have [chassis] in our parts index — which chassis family is it from?" The AI did NOT reach any product search — "I looked for X" would be misleading. |

This coupling matters: the phrasing must match what the tool actually did. Token-subset resolution (introduced 2026-04-20) widens the "resolved" column; the fallback row covers cases the resolver genuinely can't handle.

**Four-part template:**

```
Hey [name] —

[Acknowledgment line — per resolver state, referencing the customer's
terms verbatim where possible.]

Before I point you wrong, could you tell me [ONE variable — chassis
variant, year, or part nickname]?

In the meantime, here's our [category] page in case it's listed under
a name I didn't match: [permalink]
```

Rules:
- **One clarifying question.** Pick the single variable most likely to unblock the answer.
- **Category link as P.S., not pivot.** Use the best plausible category from the resolver state. If the resolver failed AND no plausible parent category exists, omit the P.S. and use the escalation fallback.
- **No "let me double-check with Dan."** That's theater — the reviewer hasn't acted yet.

**Escalation fallback** (use only when the clarifying question + category link won't plausibly resolve):

> "I'll flag this for Dan to take a look at and get back to you."

This maps to Abby's real Gmail pending-folder workflow (`context/business-profile.md:27`) — the reviewer moves the email to pending, Dan reviews on his next pass. It is a real mechanism, not invented. Do not use as the default; it taxes the reviewer.

**Internal note (Branch C):**
- Confidence: MEDIUM.
- Literal CLI commands run, terms passed.
- Resolver state (resolved to category X, or `chassis_not_found`).
- Closest near-matches (category ID, name, product count).
- Which variable the clarifying question is asking about and why.
- Suggested reviewer action: "If customer replies with [variant], re-run `find --chassis [variant] --part [part]`. If this phrasing recurs, `/teach` an alias to `customer-terminology.md` or propose a new SEED_ALIASES entry in `cache.py`."

### Do NOT (across all branches)

- Invent alternatives without rule backing.
- Guess at compatibility (guardrail #9).
- Say "let me double-check with Dan" — use the escalation fallback phrasing instead.
- Suggest eBay, Amazon, or any other retailer (`context/policies.md` §Never Redirect).
- Write "we don't carry it" unless Branch A applies.

---

## Step 5 error path (`ok: false`)

The CLI failed. Uncertainty goes in the internal note — never in the customer draft.

| `error` code | Draft approach | Internal note |
|---|---|---|
| `auth_failed` | Do not draft from fabricated data. Safest: no draft. | "Catalog auth failed — flag for Michael. Cannot verify product data." |
| `not_found` | Same as auth_failed — likely endpoint/permalinks issue. | "Catalog endpoint returned 404 — likely server-side issue. Flag for Michael." |
| `rate_limited` | Wait 30 seconds. Retry once. If still failing, fall to knowledge base. | Confidence LOW. "Catalog rate-limited; draft based on knowledge base only." |
| `server_error` / `network_error` | Fall back to knowledge base. Draft should describe the product generically without specific stock/price claims. | Confidence LOW. "Catalog unreachable at [time]. Reviewer should verify current stock/price before sending." |
| `chassis_not_found` | Treat as ambiguous (Step 5 Branch C, resolver-failed row). Use "I don't have [chassis] in our parts index" phrasing. Scan cached categories for a plausible parent category for the P.S. link before drafting. | Record which phrasing failed to resolve. If it's a pattern, propose a new alias for `cache.py` SEED_ALIASES or a new entry in `customer-terminology.md` via `/teach`. |
| `config_error` | No draft. | "Catalog config error — flag for Michael." |

**Key principle:** the customer shouldn't know the API failed. A draft that says "we typically have this in stock, here's the link" is better than one that says "let me check current availability" — the reviewer can verify and send.

---

## Step 6 — Multi-product messages

If the customer asked about multiple products (SKUs, chassis, or parts), run the right step for each. Combine into:

- **One draft** with each product addressed — per guardrail #10, address each topic separately within one reply
- **One internal note** with confidence flags per product and combined reviewer actions

Don't split into multiple drafts unless the products require different channels or routing (e.g., one is a track sale > $500 that goes to Dan per guardrail #11).

---

## Cache and log locations

You don't interact with these directly — the CLI manages them — but know they exist for debugging:

- **Category cache:** `.claude/cache/wc-categories.json`. Refreshed automatically every 7 days or on explicit `categories` invocation.
- **Query audit log:** `.claude/logs/wc-queries.jsonl`. Append-only record of every API call with timestamp, params, status, result count. Useful when debugging a wrong answer.

Both are gitignored.

---

## Worked example — Q1 canonical

**Customer message:** "I broke my V3 magnet clip and I dont see them on yrou site?"

**Step 1:** Classify → part + chassis → Step 2c.

**Step 2c:**
```bash
bash scripts/wc.sh find --chassis "V3" --part "magnet clip" --limit 10
```
Returns: 1 result — "Viper V1 Magnet Clip" (ID 188, SKU empty, $3.99, in stock, permalink `.../product/viper-v1-magnet-clip/`).

**Step 4:** `count=1`. But — the product is named **V1**, customer asked for **V3**. Compatibility unclear.

**Step 5a (draft):**
```
Hey — we carry the V1 Magnet Clip ($3.99, in stock):
https://viperscaleracing.com/product/viper-v1-magnet-clip/

Looks like we don't have a V3-specific Magnet Clip listed. Let us
know if the V1 is what you need — happy to help if you have questions.
```

**Step 5b (internal note):**
```
CONFIDENCE: MEDIUM — V1↔V3 magnet clip compatibility is unknown.

Found: Viper V1 Magnet Clip (ID 188, empty SKU), $3.99, in stock.
Category: Clips/Brackets/Misc (id=252).

Unknowns:
- Does V1 Magnet Clip fit V3? Name doesn't mark cross-compat (other
  clips in the same category explicitly say "V1/V3, SG+"). No rule in
  chassis-compatibility.md covers this.
- Is there a V3 Magnet Clip that was renamed/discontinued/not yet on site?

Reviewer actions:
- If Dan confirms V1 fits V3 → send as-is; /teach the rule after
- If V1 does NOT fit V3 → rewrite as clean "not currently carried"
- If V3 exists under a different name → send the correct link instead
```

Note what the draft does NOT do:
- Does NOT say "let me check with Dan"
- Does NOT claim V1 fits V3 (guardrail #9)
- Does NOT hide the fact that V3 isn't listed
- Does NOT hedge or use AI-speak

---

## Confidence flag rules (summary)

| Flag | When |
|---|---|
| HIGH | Catalog returned a clean match AND no rule conflict AND no compat ambiguity. Reviewer can likely send as-is. |
| MEDIUM | Catalog returned results but one specific thing needs reviewer verification (usually compat, occasionally stock timing). |
| LOW | API failed, OR count=0 without a clean-no rule to cite, OR catalog answer conflicts with a rule Enzo is aware of. |

The flag lives in the internal note. It never appears in the customer-facing draft.
