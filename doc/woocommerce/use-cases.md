# WooCommerce Use Cases — Customer Questions to API Calls

**Purpose:** Bridge between customer questions Enzo sees and the API calls that answer them. Defines what we build first and what success looks like.

**Written:** 2026-04-16
**Status:** Initial draft. Tiers and frequency estimates based on `context/` and existing `knowledge/email-examples/`. Refine after audit.

> **Read this with `api-reference.md`.** This doc says *why* we query; that doc says *how*.
>
> Verification markers used here:
> - `[TBD — verify against live API]` — query pattern drafted from docs, not yet tested on Viper
> - `[TBD — confirm with Dan]` — frequency or priority needs Dan's input
> - `[VIPER-SPECIFIC]` — Viper-particular note

---

## 1. How to read this doc

Each use case below includes:

- **Customer question pattern** — paraphrased, with example variants
- **Frequency estimate** — high / medium / low
- **Tier** — see section 2
- **API call(s)** — the endpoint + parameters
- **Interpretation logic** — how Enzo turns the response into an answer
- **Fallback** — what Enzo says if the API returns nothing or is ambiguous
- **Open questions** — things we don't know how to handle yet

---

## 2. Priority tiers

Use cases fall into four tiers. Tier 1 drives Phase 1 of the integration.

### Tier 1 — Must answer on day one
Simple lookups with clean inputs (SKU or specific product name). High volume, high confidence possible.
- Exact SKU lookup
- Exact product name lookup
- Fuzzy product search ("do you have a pinion?")
- Stock check
- Price check
- Link to product page

### Tier 2 — Answerable with clean data
Category-aware queries. Depend on audit findings — may require clean categories/attributes.
- "What products do you have for [car type]?"
- "What [part type] fits [chassis]?"
- OOS + alternatives
- Price comparisons

### Tier 3 — Requires rules on top of data
Diagnostic or multi-hop. Needs both catalog + knowledge base.
- Diagnostic → product recommendation
- Compatibility chains (tire → wheel → chassis)
- Upsell logic ("you're $3 from free shipping")
- Special-order products (sponge tires, etc.)

### Tier 4 — Not for the API
Policy, tone, or routing questions. Stays in knowledge base.
- Warranty / returns
- Shipping / free-shipping threshold
- Routing (track sales → Dan, drag racing → John)
- Payment issues
- Anything about third-party support (Windows, timing software)

---

## 3. Tier 1 use cases

### 3.1 Exact SKU lookup

**Customer question pattern:**
- "I need SKU ABC123"
- "Is item XYZ-456 available?"
- "How much is part #12345?"

**Frequency:** Medium `[TBD — confirm with Dan — repeat customers may use SKUs; new customers rarely]`

**API call:**
```
GET /products?sku={sku}
```

**Interpretation:**
- Empty array → SKU not in catalog. Flag as unusual ("couldn't find SKU — can you double-check?"). Don't assume it's discontinued.
- 1 result → return `name`, `sku`, `price`, `stock_status`, `permalink`
- If `type: "variable"` → fetch variations before reporting stock
- If `type: "simple"` and `manage_stock: true` → include `stock_quantity` if helpful

**Fallback:**
- SKU not found → ask customer to confirm. Don't guess or offer alternatives without verification.

**Open questions:**
- `[TBD — verify against live API]` SKU uniqueness — are there any duplicates?
- `[TBD — VIPER-SPECIFIC]` Do customers frequently cite SKUs with wrong prefixes/suffixes? If so, need normalization step.

---

### 3.2 Exact product name lookup

**Customer question pattern:**
- "Do you carry the Magnet Traction Kit?"
- "I need the Tyco 440X2 Armature"

**Frequency:** High

**API call:**
```
GET /products?search={quoted product name}&per_page=5
```

**Interpretation:**
- Exact name match in top result → confident yes
- Close match → use top result, flag MEDIUM confidence
- No match → fall to fuzzy search (3.3) or clean no
- Multiple similar-named products → present top 2-3, let customer pick

**Fallback:**
- No result → check if it's a chassis we don't stock for (per `tire-compatibility.md`). If yes → clean no. If unclear → ask Dan.

**Open questions:**
- `[TBD — verify against live API]` Does WC search match on product name exactly or tokens?
- `[TBD — VIPER-SPECIFIC]` How well does search handle common misspellings? ("Cortin" for "Core 10", "tracked me" for "TrackMate")

---

### 3.3 Fuzzy product search

**Customer question pattern:**
- "Do you have a pinion for a Mini-T?"
- "I need rear tires for my HP7"
- "Looking for a brushless motor"

**Frequency:** High — most common "do you carry X?" pattern

**API call:**
```
GET /products?search={cleaned customer phrasing}&per_page=10
```

**Interpretation:**
- Top 1-3 highly relevant results → offer them
- Many weak matches → ask customer for more specifics (car type, scale, specific part)
- Empty → check clean-no rules (`tire-compatibility.md`) before declaring "we don't carry it"

**Fallback strategies:**
- Broaden: drop qualifiers ("pinion Mini-T" → "pinion")
- Narrow: add category filter if we know the car type
- Clarify: ask customer for SKU or more detail

**Open questions:**
- `[TBD — verify against live API]` Multi-word search behavior — AND or OR?
- `[TBD — VIPER-SPECIFIC]` Does search include description text or only name?
- `[TBD]` Do we need a pre-processing step to normalize common misspellings before searching?

---

### 3.4 Stock check

**Customer question pattern:**
- "Is SKU X in stock?"
- "When are you getting more of Y?"
- "Do you have [product] available?"

**Frequency:** High

**API call:**
```
GET /products?sku={sku}
# or
GET /products?search={name}&per_page=1
```

**Interpretation:**
| `stock_status` | Response |
|---|---|
| `instock` + `manage_stock: true` + count | "Yes, we have [count] in stock" |
| `instock` + `manage_stock: false` | "Yes, in stock" (no count) |
| `outofstock` | "Currently out of stock — sign up for the in-stock notifier, we restock weekly." |
| `onbackorder` | Explain based on `backorders` field + Dan's tone |

**Fallback:**
- Variable product → fetch variations; if any in stock, offer those specifically
- API unavailable → defer: "let me check with the team on current availability"

**Open questions:**
- `[TBD — VIPER-SPECIFIC]` Accuracy spot check — do known OOS/in-stock products match API? (Populated in `data-audit.md` section 8.3)
- `[TBD]` "When will it be back in stock?" — WC doesn't have this. Default answer: in-stock notifier + weekly restock.

---

### 3.5 Price check

**Customer question pattern:**
- "How much is [X]?"
- "What's the price of [SKU]?"

**Frequency:** Medium

**API call:**
```
GET /products?sku={sku}
# or
GET /products?search={name}&per_page=1
```

**Interpretation:**
- `price` → current selling price
- `sale_price` set + different from `regular_price` → mention sale: "$X (reg. $Y)"
- Variable product → show price range from variations
- Quote price + include `permalink`

**Fallback:**
- API unavailable → "check current pricing at {likely permalink}" only if we know the product path; otherwise defer

**Open questions:**
- `[TBD]` Do prices on Viper vary by variation frequently? Affects how we quote.

---

### 3.6 Link to product page

**Applies to all tier 1 use cases — always include `permalink` verbatim.**

Dan's explicit preference from `tone.md`: *"I would just give him the links directly. Make it as easy as possible for him."*

**Rule:** Never construct URLs manually. Always use the `permalink` field from the API response.

---

## 4. Tier 2 use cases

### 4.1 "What products do you have for [car type]?"

**Customer question pattern:**
- "What do you carry for a Tyco 440X2?"
- "Show me everything for the Mega G+"

**Frequency:** Medium

**API call:**
```
# Step 1 — find category ID
GET /products/categories?search={car type}

# Step 2 — list products in that category
GET /products?category={id}&stock_status=instock&per_page=100
```

**Interpretation:**
- If category exists → list top items by part type (tires, motors, etc.)
- Long list → group by subcategory or part type in the reply
- Empty → clean no (we don't stock for that chassis)

**Fallback:**
- Category doesn't exist → apply `tire-compatibility.md` clean-no rule for chassis we don't stock
- Category exists but empty → unusual; flag for Dan

**Open questions:**
- `[TBD — VIPER-SPECIFIC]` Does every "car type" map to exactly one category?
- `[TBD]` If a category has 50+ products, how should Enzo summarize? By subcategory? By part type?

---

### 4.2 "What [part type] fits [chassis]?"

**Customer question pattern:**
- "What rear tires fit a Mega G+?"
- "Do you have an armature for a Tyco 440X2?"
- "What pinions work with [chassis]?"

**Frequency:** High — most common real-world customer question

**API call:**
```
# Combined category + search
GET /products?search={part type}&category={chassis category id}
```

**Interpretation:**
- Narrow results → list them with stock/price
- Empty → check if chassis is on don't-stock list (then clean no) or if we just don't have that part type for that chassis

**Fallback:**
- If part compatibility info is actually in attributes or descriptions rather than category, this query misses. Needs data audit to confirm.

**Open questions:**
- `[VERIFIED 2026-04-16 — VIPER-SPECIFIC]` Compatibility storage: primarily in **product names** (sometimes cross-compat is explicit, e.g., `Life Like Low Rider Hard Body Clip V1/V3, SG+`), rarely in attributes (only populated on variable products for the variation axis), not consistently encoded. Must layer `knowledge/product-rules/chassis-compatibility.md` on top of catalog data.
- `[VERIFIED 2026-04-16]` For Viper, part+chassis queries work best via `find --chassis X --part Y` which does category-scoped search. Plain search is unreliable on short chassis names (see `findings-log.md`).

**Canonical "requires chassis-family knowledge" example:** Customer asks "Which BeadLok wheels do you have for Super G cars?" → `find --chassis "Super G+" --part "BeadLok"` returns 1 product ("Python BeadLok Billet Wheel Set for Inlines"). The product is named "for Inlines," not "for Super G+" — catalog can't confirm compatibility. Enzo must check `chassis-compatibility.md` for a Super-G+/inline rule; if absent, draft presents the product without claiming fit, internal note flags the question. See `implementation-spec.md` §8.5 for the full handling pattern.

---

### 4.3 OOS + alternatives

**Customer question pattern:**
- "[Product] is out of stock — any alternatives?"
- "When will [X] be back in stock?"

**Frequency:** Medium

**API call:**
```
# Confirm OOS
GET /products?sku={sku}

# Find alternatives in same category
GET /products?category={same id}&stock_status=instock&per_page=10
```

**Interpretation:**
- Same-category in-stock products → offer as alternatives ONLY if Dan's rules say they're compatible
- Otherwise default response: in-stock notifier + weekly restock

**Fallback:**
- Hard rule: don't invent alternatives. If we can't verify compatibility, don't recommend.

**Open questions:**
- `[TBD — VIPER-SPECIFIC]` Can we determine "these are interchangeable" from API data alone, or does this always require Dan-defined rules?

---

### 4.4 Price comparison

**Customer question pattern:**
- "What's the difference between [X] and [Y]?"
- "Which is cheaper, the [A] or the [B]?"

**Frequency:** Low `[TBD — confirm with Dan]`

**API call:**
```
GET /products?sku={sku1}
GET /products?sku={sku2}
```

**Interpretation:**
- Fetch both, compare `price`, `name`, key attributes
- Present side-by-side facts, not opinion

**Fallback:**
- Don't opine on "which is better" — that's Dan's domain

---

## 5. Tier 3 use cases (future work)

Brief sketches — implementation after Tiers 1 and 2 are stable.

### 5.1 Diagnostic → product recommendation
"My car stopped running — what do I need?" → diagnostic questions (knowledge base) + part lookup (API). Requires structured diagnostic rules.

### 5.2 Compatibility chains
"I have an X chassis with Y wheels — what tires fit?" → multi-step: identify chassis → find compatible wheels → find compatible tires. Requires compatibility graph.

### 5.3 Upsell logic
"You're $3 from free shipping — add [item]" → cart-aware, not just catalog-aware. Requires order context or cart context we don't currently have.

### 5.4 Special-order products
Sponge tires, etc. — catalog may say OOS or not-carried, but they're special-order per Dan. Requires a "special order" flag layered on top.

---

## 6. Tier 4 — explicitly NOT for the API

These questions come into the inbox but don't need catalog queries. Listed here so Enzo doesn't accidentally burn API calls on them.

| Question pattern | Handled by |
|---|---|
| "Where's my order?" | Order lookup (separate integration, not Phase 1) |
| "I want to return [X]" | `policies.md` — warranty/return flow |
| "How much is shipping?" | `policies.md` — $50 free shipping threshold |
| "Can I call you about [track sale]?" | Route to Dan per `business-profile.md` |
| "Drag racing registration?" | Route to John |
| "My Windows won't run the timing software" | Link to third-party support per `policies.md` |
| "Can I pay by invoice?" | `policies.md` — invoicing available |

---

## 7. Question → API call matrix

Quick-reference summary of Tier 1 and Tier 2.

| Customer question pattern | Tier | Primary endpoint | Key params | Success signal | Confidence |
|---|---|---|---|---|---|
| "I need SKU X" | 1 | `/products` | `sku=X` | 1 result | HIGH |
| "Do you carry [named product]?" | 1 | `/products` | `search=name` | Top result exact match | HIGH |
| "Do you have a [part] for a [car]?" | 1 | `/products` | `search=...` | Relevant top hits | MEDIUM `[TBD]` |
| "Is [X] in stock?" | 1 | `/products` | `sku=X` | `stock_status=instock` | HIGH |
| "How much is [X]?" | 1 | `/products` | `sku=X` | `price` field populated | HIGH |
| "What do you carry for [car type]?" | 2 | `/products/categories` → `/products` | `category={id}` | Non-empty | MEDIUM `[TBD]` |
| "What [part] fits [chassis]?" | 2 | `/products` | `search=... category=...` | Relevant results | MEDIUM `[TBD]` |
| "[X] is OOS — alternatives?" | 2 | `/products` | `category=...&stock_status=instock` | Curated list | LOW-MEDIUM |

Confidence marked `[TBD]` depends on data audit outcomes.

---

## 8. Known limitations

Things the API can't answer — Enzo should recognize and defer.

- **"When will X be back in stock?"** — No ETA field. Default: in-stock notifier + weekly restock.
- **"What's the best part for my setup?"** — Opinion territory. Defer to Dan or known product rules.
- **"Can you discount [X]?"** — Pricing decisions, not catalog.
- **"Does this work with [non-Viper product]?"** — Unless Dan has documented it, defer.
- **"What's the lead time for [back-ordered item]?"** — Not in API.
- **Order-specific questions** — Separate integration entirely.

---

## 9. Success criteria

Phase 1 is successful when Enzo can:

1. Answer "do you carry X?" correctly — including clean no — for any product currently in Viper's catalog, without hallucinating
2. Report current stock status and price for any SKU with HIGH confidence
3. Always include a `permalink` in replies where a product is referenced
4. Fall back gracefully when the API is unavailable (LOW confidence + knowledge base, never fabricated)

`[TBD — define Phase 2 success criteria after audit]`

---

## 10. Next steps

In order:

1. Michael builds minimal API client (Python, `.env` credentials, single `query_product(search_or_sku)` function)
2. First live queries → populate audit sections in `data-audit.md`
3. Update verification status in `api-reference.md` with real response samples
4. Refine confidence estimates in the matrix (section 7) based on audit
5. Identify Tier 2 use cases that are blocked by data issues — feed back to Dan for cleanup
6. Wire Enzo to call `query_product` at answer-time
7. Pilot on a few real customer emails, measure accuracy, iterate
