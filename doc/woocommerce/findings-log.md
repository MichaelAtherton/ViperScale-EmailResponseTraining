> ⚠️ **ENGINEERING DOCUMENT — NOT A PRODUCT REFERENCE**
>
> This file is a running log of test queries made against the live WooCommerce API during integration development. Any SKUs, prices, product names, stock states, or IDs captured here are **snapshots from the date of the test run** and will be stale the moment Dan changes the catalog.
>
> **Do NOT cite anything in this file in a customer draft.** For current product data, use the catalog-lookup skill against the live API. This applies to everything in `doc/`, `audit/`, `scratch/`, and any other engineering/test artifacts in the repo.

---

# WooCommerce API — Findings Log

**Purpose:** Running record of what we've learned from live queries against viperscaleracing.com. Append-only; dated entries; raw observations before they get polished into the spec.

**Started:** 2026-04-16
**Maintained by:** Enzo, during live-API exploration sessions

> This is where we capture what the data *actually* looks like. The spec (`implementation-spec.md`) is where we capture what we've decided to *build*. Findings here feed into spec revisions, not the other way around.

---

## 2026-04-16 — Initial 10-query empirical check

**Script:** `scripts/wc-empirical-check.sh`
**Output:** `scratch/wc-empirical-check/`

### Infrastructure — what works

- **HTTPS + Basic Auth:** works first try
- **Pretty permalinks:** enabled (no 404s on `/wp-json/wc/v3/`)
- **Pagination headers:** `X-WP-Total`, `X-WP-TotalPages`, `Link` all present and correct
- **Sucuri Cloudproxy WAF** in front of the site — noted. Could affect rate limits later. No 429s observed.
- **HTTP/2 + TLS** both active

### Catalog scale

- **681 published products** (from `X-WP-Total` on `/products?per_page=1`). Close to Dan's stated ~693.
- **204 categories total** across 3 pages — initial 100-category fetch missed 104 categories. **Spec impact: category cache must paginate.**

### Draft-product leak (CRITICAL)

- `GET /products?per_page=1` returned a **draft custom order** (`"Custom Order for Larry"`, $4,122.95, `status: draft`) as the first product. This is an internal line item — NOT something customers should ever see.
- **Implication:** `status=publish` must be passed explicitly on every product query. Default does NOT filter drafts.
- **Spec action:** update all endpoint examples and the CLI to pass `status=publish` automatically.

### Field surface

Actual fields returned per product (from sample query 03):
```
_links, aioseo_notices, attributes, average_rating, backordered, backorders,
backorders_allowed, brands, button_text, catalog_visibility, categories,
cross_sell_ids, date_created, date_created_gmt, date_modified, date_modified_gmt,
date_on_sale_from, date_on_sale_from_gmt, date_on_sale_to, date_on_sale_to_gmt,
default_attributes, description, dimensions, download_expiry, download_limit,
downloadable, downloads, external_url, featured, global_unique_id,
grouped_products, has_options, id, images, low_stock_amount, manage_stock,
menu_order, meta_data, name, on_sale, parent_id, permalink, post_password,
price, price_html, purchasable, purchase_note, rating_count, regular_price,
related_ids, reviews_allowed, sale_price, shipping_class, shipping_class_id,
shipping_required, shipping_taxable, short_description, sku, slug,
sold_individually, status, stock_quantity, stock_status, tags, tax_class,
tax_status, total_sales, type, upsell_ids, variations, virtual, weight
```

**Notable additions beyond the spec:**
- `brands` field — present (but empty on sampled products; see brands endpoint below)
- `price_html` — pre-formatted HTML price. Could be useful, but strip-or-ignore for now.
- `aioseo_notices` — SEO plugin noise. Ignore.
- `global_unique_id` — not GTIN/UPC necessarily; unclear purpose. Ignore for now.

### Brands endpoint — empty

- `GET /products/brands` and `/products/brands?search=jag` both return `[]` (2 bytes).
- Despite the `brands` field existing on product objects, no brand taxonomy is populated.
- **Implication:** cannot rely on brand lookups; must use category + name-based matching.

### "Dealer Exempt" category (218 products) — unknown purpose

- Category id=336, count=218 — third-largest top-level category.
- Appears on many products across the catalog: JAG chassis, AFX cars, custom orders.
- **Unknown to Enzo:** are these wholesale-only products? Should they be filtered out of retail customer answers?
- **Action needed:** ask Dan.

### Variable products

- Parent product has empty `sku`, `manage_stock: false`, `stock_quantity: null`
- `attributes` on parent describes variation axis (e.g., `{name: "Color", variation: true, options: ["Blue", "Natural", ...]}`)
- `variations` array contains child IDs only
- Real stock + price lives on each variation via `/products/{parent_id}/variations`
- Examples found: guide pins (by color), endbells (by quantity), armatures
- **Spec confirmed:** variable-product handling as written is correct; must fetch variations to answer stock.

### Attributes on simple products

- Sample of 3 simple products: **all had empty `attributes` arrays**.
- Attributes appear to be used only on variable products (to define variation axes).
- **Implication:** compatibility info does NOT live in structured attributes for simple products. It lives in the product `name` and sometimes `description`.

### Categories observed in first 100

Key top-level categories (parent=0):

| id | Name | Count | Notes |
|---|---|---|---|
| 22 | Shop by Car Type | 359 | Parent of all chassis-specific categories |
| 336 | Dealer Exempt | 218 | ❓ Purpose unknown — ask Dan |
| 18 | Drag Racing/Accessories | 69 | |
| 496 | 2025' Viper V3 | 29 | Viper's own product line |
| 532 | Builders Kits | 5 | Cross-cutting; sub of Viper V platform |

Key chassis subcategories (parent=22):

| id | Name | Count |
|---|---|---|
| 26 | _Viper V Platform | 229 |
| 36 | Aurora/Tomy/AFX | 204 |
| 40 | Life Like | 73 |
| 213 | AutoWorld | 37 |
| 310 | Drag Cars | 20 |

### Search quality — the mixed story

Tested 5 customer-phrasing queries:

| Query | Results | Quality |
|---|---|---|
| `pinion Mini-T` | 0 | Correct empty — Mini-T is a Losi product; Viper doesn't carry |
| `Magnet Traction Kit` | 5 | Junk — matched "Kit" not "Magnet Traction" |
| `rear tires Mega G` | 5 | Junk — returned Mega G+ cars, not tires |
| `HP7 armature` | 0 | Correct empty — confirms clean-no rule |
| `brushless motor` | 0 | Correct empty — Viper doesn't use that term |

**Initial read:** search is weak.
**After further testing:** search is actually reasonable when terms appear in product names. Failures above are because those terms don't match Viper's naming conventions. See spot checks below for contrary evidence.

---

## 2026-04-16 — Spot check: Mega G+

**Script:** `scripts/wc-spot-mega-g.sh` and `scripts/wc-spot-mega-g-cat.sh`
**Output:** `scratch/wc-spot-mega-g/`, `scratch/wc-spot-mega-g-cat/`

### Category structure — rich and well-organized

"Mega G+" = category id=89 (66 products), slug=`mega-g-tomy-afx`, parent=36 (Aurora/Tomy/AFX). Important distinctions:
- "Mega G" (no plus) is a **separate** category id=78 (75 products). Different chassis generation.
- "+" does not appear in the slug — URL-encoded `+` in search can confuse things.

Child/related categories under Mega G+:
- id=80 Armatures (7) — slug `armatures-electrical-mega-g`
- id=79 Electrical (21) — slug `electrical-mega-g`
- id=90 Electrical (7) — slug `electrical-mega-g-tomy-afx` (variant)
- id=97 Front End Setups (11) — slug `front-end-setups-mega-g-tomy-afx`
- id=242 Guide Pins (4)
- id=243 Guide Pins (4) — duplicate name, different slug
- id=95 Magnets (2)
- id=106 Motor Brushes/Springs (5)

**Pattern:** chassis-specific part-type categories exist. Names duplicate across chassis (many "Armatures" categories), but slugs are unique. **Must use slug, not name, for category identity.**

### Combined category + search — the winning pattern

`GET /products?category=89&search=rear+tires` → 13 results, all actually rear tires / wheels / rear-end setups for Mega G+.

`GET /products?category=89&search=armature` → 1 result (a cross-cutting spacer). Actual armatures are in id=80 subcategory.

**Lesson:** for part-type questions, need to resolve BOTH chassis ID AND the appropriate part-type subcategory. A single combined query against the chassis category misses part-type-scoped products.

### Cross-referencing: Mega G+ products' other categories

66 Mega G+ products are cross-listed heavily:
- "Gears" variants (ids 133, 141, 134, 136, 137, 142, 143) — 12-13 products each
- "Rear Axles" variants (ids 176, 175) — 8-12 products
- "Front End Setups" variants (96, 97, 209, 210, 211) — 9-11 products
- "Wheels/Tires/Gears/Axles" id=151
- "Dealer Exempt" — 16 products (!)

**Implication:** a Mega G+ product usually belongs to 4-8 categories simultaneously. The data is heavily cross-tagged, which means:
- Category queries over-return (one product appears in many queries)
- But also: intersecting categories might narrow well

---

## 2026-04-16 — Spot check: Tyco + VSPEC Builders Kits

**Script:** `scripts/wc-spot-tyco-vspec.sh`
**Output:** `scratch/wc-spot-tyco-vspec/`

### Tyco category hierarchy

- id=37 "Tyco" (97 products), parent=22 (Shop by Car Type)
- id=38 "440X2" (97 products) — child of Tyco

So 440X2 is the main Tyco product line. Other Tyco-era chassis (HP7, HP2, etc.) not present as categories — confirms existing clean-no rule.

### Armature categories — six of them

All named "Armatures" but slug-scoped by chassis:

| id | slug | count |
|---|---|---|
| 74 | armatures | 20 |
| 75 | armatures-electrical | 21 |
| 77 | armatures-electrical-440x2 | 11 |
| 80 | armatures-electrical-mega-g | 7 |
| 100 | armatures-electrical-m-chassis | 10 |
| 361 | armatures-electrical-shop-by-category | 30 |

**Pattern:** each chassis has its own "Armatures" sub-subcategory. Resolving "armature for [chassis]" requires knowing which specific Armatures category to hit.

### Search: "Tyco Timed Armature" — works great

`GET /products?search=Tyco+Timed+Armature` → 3 results:
1. Hand Wound 3" 36G Double wind .480 Ohm Neo armature (Brush Barrel Timed) — SKU `Hand Wind Tyco-MISC-X`, OOS, $125
2. **5.8 ohm Super Stock Balanced Tyco-Timed Armature** — SKU 11066, in stock, $19.95
3. **6 ohm Tyco-Timed Armature** — SKU 11065, in stock, $6.50

**Lesson:** multi-word search works well when all terms appear in product names. The `Tyco-Timed` hyphenated compound matches token `Tyco` AND `Timed` AND `Armature`.

### VSPEC Builders Kits — exact clean answer

`GET /products?search=VSPEC+Builders` → 2 results:
- **V3 VSPEC-X Builders Kit** (SKU 22807, in stock, $62.95)
- **V1 VSPEC Builders Kit** (SKU 22855, in stock, $49.95)

Perfect answer for the customer question. No junk, no ambiguity.

Broader `search=VSPEC` returned 20 relevant VSPEC products (cars, hard bodies, RTR configs). Zero junk.

### Builders Kits category — also clean

`GET /products?category=532` → 5 products:
- V3 VSPEC-X Builders Kit ($62.95)
- V1 VSPEC Builders Kit ($49.95)
- Viper Builders Kit Super 7 "HB" HO Slot Car (Colored Chassis) ($47.95)
- Viper Builders Kit Super 7 "HB" HO Slot Car ($46.95)
- Viper Builders Kit Super 7 SPEC7 HO Slot Car ($42.95)

**Lesson:** top-level "Builders Kits" category is comprehensive and clean. Good answer for "what builders kits do you have?"

---

## 2026-04-16 — Spot check: JAG Hobbies + BeadLok / Super G

**Script:** `scripts/wc-spot-jag-beadlok.sh` and `scripts/wc-spot-super-g-wheels.sh`
**Output:** `scratch/wc-spot-jag-beadlok/`, `scratch/wc-spot-super-g-wheels/`

### JAG — clean brand with a category

- `id=45 "JAG"` (19 products), parent=16 (Cars)
- Slug `jag`
- Search `JAG Hobbies` → 10 results, all relevant (TR3 chassis, NC-2 wheels, PR-5 wheels, DK-4 T-Jet Alternative, Replacement Motor Assembly)

**Customer-question answer quality:** HIGH. `search=JAG+Hobbies` or `category=45` both work well.

### Super G+ — another well-structured chassis

- id=69 "Super G+" (151 products!), parent=36 (Aurora/Tomy/AFX)
- Slug `super-g` (note: no "+" in slug)

Rich subcategory tree:

| id | Name | slug | count |
|---|---|---|---|
| 250 | Chassis | chassis-super-g | 16 |
| 254 | Clips/Brackets/Misc | clips-brackets-misc-chassis-super-g | 8 |
| 67 | Electrical | electrical-super-g | 50 |
| 210 | Front End Setups | front-end-setups-wheels-tires-gears-axles-super-g | 15 |
| 143 | Gears | gears-wheels-tires-gears-axles-super-g | 28 |
| 245 | Guide Pins | guide-pins-super-g | 5 |
| 113 | Magnets | magnets-super-g | 19 |
| 259 | Pickup Springs | pickup-springs-electrical-super-g | 4 |
| 71 | Pickups and Hangers | pickups-and-hangers-electrical-super-g | 10 |
| 178 | Rear Axles | rear-axles-wheels-tires-gears-axles-super-g | 5 |
| 183 | Rear End Setups | rear-end-setups-wheels-tires-gears-axles-super-g | 8 |
| 190 | Rear Rims | rear-rims-wheels-tires-gears-axles-super-g | 5 |
| 267 | Spacers | spacers-wheels-tires-gears-axles-super-g | 3 |
| 140 | Wheels/Tires/Gears/Axles | wheels-tires-gears-axles-super-g | 59 |
| 262 | Bushings/Bearings | bushings-bearings-electrical-super-g | 10 |

**This is the most structured chassis taxonomy in the catalog.** If Enzo learns to resolve `Super G+` → 69 and `rear rims / wheels / rear end setups` → 190/140/183, customer questions about Super G+ wheels become trivial.

### Search failure case: `search=Super G`

`GET /products?search=Super+G&per_page=20` → 20 results that are mostly **NOT Super G+ products**:
- AFX Formula Mega G+ cars (matched on `G+`)
- Viper Hybrid Guide Pins (matched on something weak)
- V3 Armatures

**Lesson:** plain search on short chassis names with common tokens (`G`, `G+`, `Plus`) is unreliable. MUST use category-scoped search for Super G+ queries. The category cache + name resolver is not optional for this chassis.

### BeadLok — real answer requires compatibility judgment

Customer: "Which BeadLok wheels do you have for Super G cars?"

- `search=BeadLok` → 1 result globally: "Python" BeadLok Billet Wheel Set for Inlines, $42.95
- `category=69&search=beadlok` → same 1 result (the Python BeadLok is categorized under Super G+)
- `category=183 (Super G+ Rear End Setups)` → 8 products, including Python BeadLok and 3 other billet wheel sets (Diamondback, Rattler, Sidewinder) — all $39.95

**The catch:** the Python BeadLok is named "for Inlines," not "for Super G+." Is Super G+ an inline chassis? **I don't know** — that's tribal knowledge.

**Implication:** even with perfect category resolution, Enzo will hit cases where the product's name/description implies a compatibility detail the catalog doesn't explicitly encode. These need either:
1. A chassis-family knowledge file (`Super G+` = inline, `Mega G+` = inline, etc.)
2. Dan's judgment at draft-review time

**Spec action:** add chassis-family compatibility knowledge to `knowledge/product-rules/` before Phase 1 ships, OR flag these as MEDIUM confidence and defer to Dan.

---

## Consolidated findings so far

### What's solid
1. **HTTPS auth, pagination, pretty permalinks** — all working; no infra issues
2. **Category-scoped queries work reliably** when we know the category ID
3. **Well-structured chassis** (Mega G+, Super G+, Tyco, VSPEC) have rich taxonomies — parent category + part-type subcategories
4. **Multi-word search with specific names** works great (JAG Hobbies, VSPEC Builders, Tyco Timed Armature)
5. **SKU lookup** never fails when the SKU exists
6. **Drafts are excluded** when `status=publish` is passed

### What's fragile
1. **Plain search on short chassis names with common tokens** (`Super G`, `Mega G`) returns garbage
2. **Category names duplicate** across chassis ("Armatures" appears 6 times) — slugs are the unique identifier
3. **Brands endpoint is empty** — can't use it; brand information must come from category + name matching
4. **Compatibility info lives in product names, not attributes** — attributes are essentially unused on simple products
5. **Same product appears in 4-8 categories** — cross-listing is heavy; one category query over-returns

### What's unknown (needs Dan's input)
1. **"Dealer Exempt" category (218 products)** — what is it? Should retail customers see these products?
2. **Chassis family membership** — is Super G+ an "inline" for purposes of compatibility? Need a chassis-families map for common cross-compat judgments.
3. **Product naming conventions for motors** — customers say "brushless motor"; Viper's products are named "Tyco-Timed Armature" etc. Need synonym/alias layer.
4. **Draft products** — why is there a $4,122 "Custom Order for Larry" in the catalog? Is this normal workflow or should it be filtered?

### Architecture implications
1. **Category cache is mandatory, not optional** — must paginate all 204 categories, not 100
2. **Name-to-category-ID resolver** is the single most important data structure
3. **Category slugs are the unique key**, not names
4. **All product queries must pass `status=publish`**
5. **Chassis-family knowledge file** needed in `knowledge/product-rules/`
6. **"Dealer Exempt" filtering policy** needed before any live customer-facing replies

### Spec updates pending

Based on above findings, `implementation-spec.md` needs these updates (staging here until we do a spec revision pass):

- [x] Section 3 — pass `status=publish` on all product queries by default *(done in Step 1a, 2026-04-16)*
- [x] Section 6.6 — category cache must paginate (3 pages, 204 categories for Viper) *(done in Step 1a)*
- [x] Section 6.6 — add slug-to-category-ID resolver alongside name-based *(done: 3-layer resolver — alias → slug → name)*
- [x] Section 8.5 — disambiguation decision tree now has a concrete counter-example to test against (BeadLok + Super G) *(done in Step 1a)*
- [x] Section 9 (SKILL.md) — add chassis-family rules lookup before judgment calls on compatibility *(handled via guardrail #9 reference + the `chassis-compatibility.md` rule-file pattern)*
- [x] New section — "Dealer Exempt" filtering policy *(added as §8.6 with interim "filter out by default, flag for Dan" rule)*
- [x] Add a chassis-name alias map (slug:category_id pairs) *(done: 12-entry seed in §6.6)*
- [x] Use-cases.md — mark "BeadLok for Super G" as the canonical "requires chassis-family knowledge" case *(done in Step 1a: §4.2 now has verified compatibility-storage findings and the canonical example)*

---

## Open questions for Dan (session end summary)

1. **"Dealer Exempt" category** (id=336, 218 products) — retail-visible or not?
2. **Compatibility families:** what counts as "inline"? What chassis are siblings in terms of interchangeable parts?
3. **Draft custom orders** — should the API client ignore them entirely, or are they sometimes relevant?
4. **Motor terminology** — customers often say "brushless motor"; Viper's products use different language. Is there a glossary/synonym list we should capture?

---

## 2026-04-16 — Customer question test: Q1 "V3 magnet clip"

**Script:** `scripts/wc-q1-v3-magnet-clip.sh` + `scripts/wc-q1-followup.sh`
**Output:** `scratch/wc-q1-v3-magnet-clip/`, `scratch/wc-q1-followup/`

### Customer message (verbatim)

> "I broke my V3 magnet clip and I dont see them on yrou site?"

### Entity extraction

| Field | Value |
|---|---|
| Chassis | V3 (Viper V3 platform) |
| Part | magnet clip |
| Implicit intent | Customer wants to buy replacement; already searched the site |
| Meta-signal | "I don't see them on your site" — customer acknowledges prior search effort |

### Query plan

1. Plain search `magnet clip` — establish broad catalog presence
2. Search inside `2025' Viper V3` category (id=496) for "clip" and "magnet"
3. Look for clip/bracket category slugs — found `Clips/Brackets/Misc` (id=252, parent=27 "Viper V Chassis"), 21 products
4. Search inside id=252 for "magnet"

### Winning query

```
GET /products?category=252&search=magnet&status=publish
```

### Actual results

**3 products returned:**
1. V3 Hybrid Brass Ultralight weight kit — SKU 22857 — name matches "magnet" only loosely
2. V1 VSPEC Builders Kit — SKU 22855 — name match loose
3. **Viper V1 Magnet Clip** — ID=188, SKU empty, $3.99, in stock, permalink `https://viperscaleracing.com/product/viper-v1-magnet-clip/`

The third is the only actual magnet clip. **Listed as V1, not V3.**

### Key catalog facts

- **V1 Magnet Clip exists; no V3-specific Magnet Clip is listed.**
- Name does NOT indicate cross-compatibility (compare: "Life Like Low Rider Hard Body Clip V1/V3, SG+" which explicitly marks V1/V3 in the name — different convention, different meaning).
- SKU is empty — can't reconcile via SKU.
- Permalink works and is customer-shareable.

### Compatibility analysis — applying guardrail #9

Is V1 magnet clip compatible with V3?

- **Product name doesn't say so.** Other clips in the catalog explicitly mark cross-compat (`V1/V3/SG+`) in their names — the magnet clip does not.
- **No rule exists in `knowledge/product-rules/`.** Nothing documents V1↔V3 magnet clip compatibility.
- **Dan hasn't told us.** No teach entry covers this.
- **Plausibility ≠ confirmation.** Even if V1 and V3 share magnet clip geometry (which we don't know), that's not authoritative.

**Therefore: compatibility is unknown. Do NOT claim the V1 fits V3 in the draft.**

### Two-part output — the correct answer

#### Customer-facing draft

```
Hey — we carry the V1 Magnet Clip ($3.99, in stock):
https://viperscaleracing.com/product/viper-v1-magnet-clip/

Looks like we don't have a V3-specific Magnet Clip listed. Let us know
if the V1 is what you need — happy to help if you have questions.
```

**Why this phrasing:**
- Acknowledges what we found (V1 Magnet Clip) with price + link per `tone.md`
- Honestly states we don't have a V3 listed — doesn't hide it
- Doesn't claim V1 fits V3 (would be an unverified compatibility claim per guardrail #9)
- Doesn't say "let me check with Dan" (guardrail #8 — that's internal, not customer-facing)
- Leaves the door open for the customer to clarify if V1 is wrong for them — matches Dan's "let us know" pattern from `tone.md`
- No hedging, no AI-speak

#### Internal note (for the reviewer)

```
CONFIDENCE: MEDIUM — compatibility between V1 and V3 magnet clips is unknown

What I found:
- Viper V1 Magnet Clip (product ID 188, empty SKU), $3.99, in stock
- Located in Clips/Brackets/Misc category (id=252)
- Permalink: https://viperscaleracing.com/product/viper-v1-magnet-clip/

What I don't know:
- Does the V1 Magnet Clip fit a V3 chassis? The product name does NOT mark
  it as V1/V3-compatible (other clips in the same category explicitly mark
  cross-compat in their names, e.g. "V1/V3, SG+"). No rule in
  knowledge/product-rules/ covers this.
- Is there a V3-specific Magnet Clip that's not in the catalog yet, or
  was one discontinued? Worth asking Dan.

Reviewer actions to consider:
- If Dan confirms V1 fits V3 → send the draft as-is, then use /teach to
  save the rule so I know for future
- If V1 does NOT fit V3 → rewrite as a clean "we don't currently carry
  a V3 Magnet Clip" response; consider eBay or a special-order offer
- If V3 magnet clips exist but were renamed/reshuffled — ask Dan what
  they're called now
```

### What this test revealed about the architecture

1. **Plain text search on common tokens is noisy.** `search=magnet+clip` returned cars and kits, none of them clips. Category-scoped search was essential.

2. **Chassis-family compatibility is the biggest unknown.** The catalog doesn't encode "V1 parts that also fit V3" in a structured way. Some product names mark it (`V1/V3, SG+`), most don't. Without a chassis-compatibility knowledge file (populated from Dan's teaches), Enzo can't answer cross-chassis questions confidently.

3. **Empty SKU fields exist and matter.** The V1 Magnet Clip has no SKU. SKU-based reconciliation won't work for every product. Name + ID + slug are fallbacks.

4. **Permalink is the golden field.** Every product has a working public URL. Enzo should always include it.

5. **Customer meta-signals ("I don't see them on your site") can guide response framing** — Enzo should acknowledge the customer's prior effort without admitting uncertainty. The draft above does this implicitly by being direct ("looks like we don't have a V3-specific Magnet Clip listed").

### Spec updates this test surfaced

- [x] Guardrail #9 (added this session) correctly applies to this case *(verified via canonical example; compat claim NOT made in draft)*
- [x] Category cache must include id=252 (Clips/Brackets/Misc) and id=254 *(cache now paginates all 208 categories)*
- [x] Need `knowledge/product-rules/chassis-compatibility.md` *(created empty in Step 3 with strict source rules)*
- [x] `/teach` redesign (Patterns A/B/C) *(redesigned in Step 3 with Pattern A source-required guardrail)*

---

## 2026-04-16 — End-to-end run of Q1 through `/draft-reply` (post-build verification)

**Context:** After building the Python client (Step 4) and wiring `catalog-lookup` into `/draft-reply` (Step 5), verified the system actually produces the canonical output for Q1 by running live CLI commands as Enzo would.

### Discovery during the live run

`bash scripts/wc.sh find --chassis "V3" --part "magnet clip" --limit 10` returned `count=8` — but **none were a dedicated magnet clip.** The results were cars, chassis, builders kits, and a weight kit, all matched on token overlap in product names/descriptions rather than actually being clip products.

The **Viper V1 Magnet Clip** (id=188) DOES exist in the catalog but lives in `Clips/Brackets/Misc` (category id=252) under parent "Viper V Chassis" (id=27) — NOT under the V3-specific category (id=496). The `find --chassis V3` scope correctly queried category 496 and correctly found no magnet clip there.

Worse: **plain text search for "Viper V1 Magnet Clip" also fails to surface it** as a top result. WooCommerce's search includes descriptions, so hardbody products that mention "magnet" and "clip" in their descriptions outrank the actual clip product.

### Implication for the skill

Added a new decision branch to `catalog-lookup` SKILL.md Step 2c: **when `find` returns count > 0 but no topical matches, the reliable fallback is to browse `Clips/Brackets/Misc` (id=252) and chassis-specific part-type subcategories directly, not to retry text search.**

Specifically documented:
- WooCommerce search on common tokens matches descriptions, which buries the actual part under cars/kits
- Cross-chassis parts live in categories like `Clips/Brackets/Misc` (id=252, id=254)
- Chassis-specific part subcategories exist for Armatures, Electrical, Front End Setups, Magnets — each scoped to a chassis via slug

### Final two-part output

**Customer-facing draft:**

```
Hey — we carry the V1 Magnet Clip ($3.99, in stock):
https://viperscaleracing.com/product/viper-v1-magnet-clip/

Looks like we don't have a V3-specific Magnet Clip listed. Let us know
if the V1 is what you need — happy to help if you have questions.
```

**Internal note:**

```
Confidence: MEDIUM — V1↔V3 magnet clip compatibility is unknown

What I found:
- find --chassis "V3" --part "magnet clip" → 8 results in V3 category,
  none are a dedicated magnet clip (builders kit, chassis, weight kit).
  No V3-specific Magnet Clip exists in catalog.
- Manually checked Clips/Brackets/Misc (id=252): Viper V1 Magnet Clip
  (ID 188, empty SKU), $3.99, in stock.
- Permalink: https://viperscaleracing.com/product/viper-v1-magnet-clip/

What I don't know:
- Does V1 Magnet Clip fit a V3 chassis? Product name doesn't mark
  cross-compat. No rule in chassis-compatibility.md.
- Is there a V3 Magnet Clip that was renamed or not yet on site?

Suggested reviewer actions:
- If Dan confirms V1 fits V3 → send as-is, /teach the rule after
- If V1 does NOT fit V3 → rewrite as clean "not currently carried"
- If V3 exists under different name → send the correct link instead

Knowledge used: chassis-compatibility rules (empty for V1↔V3),
response pattern for customers who acknowledge they searched,
Dan's tone baseline.
```

### Verdict

Output matches the canonical shape from the earlier Q1 test. The guardrails held — no "let me check" in the draft, no V1↔V3 compatibility claim. The live system produces the right answer on this question, with one documented skill update captured above.
