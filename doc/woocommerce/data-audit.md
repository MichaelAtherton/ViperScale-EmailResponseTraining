> ⚠️ **ENGINEERING DOCUMENT — NOT A PRODUCT REFERENCE**
>
> This file is a point-in-time empirical audit of Viper's WooCommerce data, written for integration development. Any SKUs, prices, product names, counts, or field values captured here are **snapshots** and will be stale once Dan changes the catalog. **Do NOT cite anything in this file in a customer draft.** For current product data, use the catalog-lookup skill against the live API.

---

# WooCommerce Data Audit — Viper Scale Racing

**Purpose:** Empirical audit of Viper's actual WooCommerce data. Answers the question: *"Is this data clean enough for Enzo to answer customer questions against?"*

**Written:** 2026-04-16
**Status:** Template — all sections marked `[TBD]` until live API access is available.

> This doc is the **empirical counterpart** to `api-reference.md`. The reference doc says what the API *can* return; this doc records what Viper's catalog *actually* contains.
>
> Fill in during Phase 2 (data audit), after Michael has wired up a basic API client.

---

## 1. Audit goals

This audit answers specific questions that determine whether Enzo can safely rely on catalog queries:

- **Can we identify products by car type reliably?** (Otherwise "what fits my HP7?" can't be answered without hand-maintained rules.)
- **Can we answer "do you carry X?" without hallucinating?** (Requires clean SKUs, consistent names, or reliable search.)
- **Is stock data trustworthy?** (Requires `manage_stock` on products customers ask about, accurate counts.)
- **Where does compatibility information live?** (Categories? Attributes? Description text? Multiple places inconsistently?)
- **How messy are product names and descriptions?** (Affects fuzzy matching and how we quote products back to customers.)

### Audit verdict (filled in last)

`[TBD]` — Go / no-go / conditional for each customer-question pattern in `use-cases.md`.

---

## 2. Catalog shape

High-level facts about the catalog as a whole.

| Metric | Value | Notes |
|---|---|---|
| Total published products | `[TBD]` | `GET /products?per_page=1`, read `X-WP-Total` |
| Simple products | `[TBD]` | `GET /products?type=simple&per_page=1` |
| Variable products | `[TBD]` | `GET /products?type=variable&per_page=1` |
| Grouped products | `[TBD]` | `GET /products?type=grouped&per_page=1` |
| External/affiliate products | `[TBD]` | `GET /products?type=external&per_page=1` |
| Total variations | `[TBD]` | Sum of `variations.length` across variable products |
| Total categories | `[TBD]` | `GET /products/categories?per_page=1`, read `X-WP-Total` |
| Active categories (with products) | `[TBD]` | `GET /products/categories?hide_empty=true` count |
| Products with non-empty SKU | `[TBD]` % | Sample + count |
| Products with `manage_stock: true` | `[TBD]` % | Sample + count |

**Notes and surprises:** `[TBD]`

---

## 3. Category taxonomy

Understanding the category tree is critical — this is most likely where "car type" lives.

### 3.1 Top-level categories
`[TBD — list all top-level categories (parent: 0) with product counts]`

| Category | ID | Product count | Child categories |
|---|---|---|---|
| `[TBD]` | | | |

### 3.2 Structure
- **Hierarchical or flat?** `[TBD]`
- **Is "car type" a top-level category, a sub-category, or both?** `[TBD]`
- **Are the same products in multiple categories?** `[TBD]` — sample a few products to see

### 3.3 Car-type coverage spot check
For the top ~5 car types Dan sells, does each have a dedicated category with products in it?

| Car type (customer mention) | Matching category name | Category ID | Product count |
|---|---|---|---|
| Mega G+ | `[TBD]` | `[TBD]` | `[TBD]` |
| AFX | `[TBD]` | `[TBD]` | `[TBD]` |
| Tyco 440X2 | `[TBD]` | `[TBD]` | `[TBD]` |
| `[TBD — ask Dan which car types matter most]` | | | |

### 3.4 The key question
**Can we map a customer's mention of a car (e.g., "Mega G+") to a category reliably via exact name match?**
- `[TBD]` Exact name match works?
- `[TBD]` Need alias/synonym table? (e.g., "MGM+" → "Mega G+")
- `[TBD]` Need fuzzy name matching on category names?

### 3.5 Empty or malformed categories
`[TBD]` — any categories with 0 products that shouldn't exist? Any with weird names?

---

## 4. Attributes

Attributes are structured product specs (e.g., "Scale: 1/64", "Compatibility: Mega G+").

### 4.1 Attributes in use
`[TBD — list all attribute taxonomies found on products]`

| Attribute | % of products using it | Sample values | Notes |
|---|---|---|---|
| `[TBD]` | | | |

### 4.2 Where does compatibility live?
- **As an attribute?** `[TBD]` — if yes, what's it called and what values does it take?
- **As a category?** `[TBD]`
- **In the description?** `[TBD]` — free-text, templated, or both?
- **Multiple places inconsistently?** `[TBD]` — most likely answer based on experience

### 4.3 Practical impact
If compatibility lives in attributes/categories reliably, Enzo can answer "what fits X?" with a structured query. If it only lives in descriptions, Enzo needs text parsing and rules on top.

`[TBD — verdict after audit]`

---

## 5. SKU conventions

### 5.1 Coverage
- **% of products with non-empty SKU:** `[TBD]`
- **% of products with blank/null SKU:** `[TBD]` — these won't be findable by SKU lookup

### 5.2 Uniqueness
- **Are SKUs unique across products?** `[TBD]` — sample query for common SKUs and confirm
- **Are SKUs unique across variations too?** `[TBD]` — variations have their own SKUs

### 5.3 Patterns
- **Any naming convention?** `[TBD]` — prefix = vendor? Suffix = variant? Random?
- **Consistent case/formatting?** `[TBD]` — uppercase vs. mixed
- **Dashes, spaces, or clean?** `[TBD]`

### 5.4 Customer-facing SKU references
Do customers typically cite SKUs correctly? `[TBD]` — pull a few past email examples and check.

---

## 6. Product naming

### 6.1 Sample of 20 products
`[TBD — dump 20 random product names after first sync]`

| # | Name | Category | SKU |
|---|---|---|---|
| 1 | `[TBD]` | | |
| ... | | | |

### 6.2 Naming inconsistencies observed
`[TBD]` — common issues to watch for:
- Same chassis written different ways ("HP-7" vs "HP7" vs "H.P. 7")
- Abbreviations vs. full names ("MGM+" vs "Mega G+")
- Vendor prefixes (sometimes present, sometimes not)
- Part-type naming (e.g., "armature" vs "arm" vs "pancake armature")

### 6.3 Search implications
- **Does fuzzy search across names work acceptably?** `[TBD]` — test with common customer phrasings
- **Need an alias/synonym layer?** `[TBD]`
- **Need a canonical-name map for customer-facing replies?** `[TBD]`

---

## 7. Descriptions

### 7.1 Structure
- **HTML cleanliness:** `[TBD]` — clean `<p>` tags or cruft-heavy with inline styles?
- **Consistent templates?** `[TBD]` — "This product fits…" pattern, or free-form?
- **Any common sections (Fitment, Specs, Notes)?** `[TBD]`

### 7.2 Information only in descriptions
Some facts may only live in free text. Examples:
- `[TBD]` Compatibility notes?
- `[TBD]` "Sold as pair" / quantity notes?
- `[TBD]` Installation warnings?

### 7.3 Parseability
Can Enzo extract structured facts from descriptions reliably? `[TBD]` — or should we treat descriptions as unstructured quote material only?

### 7.4 Sample descriptions
`[TBD — pull 5 sample descriptions (both simple and HTML-rendered) after first sync]`

---

## 8. Stock data reliability

### 8.1 Stock management coverage
- **% of simple products with `manage_stock: true`:** `[TBD]`
- **% with real `stock_quantity` values:** `[TBD]`
- **% with only `stock_status` (no unit count):** `[TBD]`

### 8.2 Variable product stock
- **Parent `manage_stock`:** `[TBD]` — likely false
- **Variation `manage_stock`:** `[TBD]`
- **Can Enzo trust `stock_status` on a variable product parent?** `[TBD]`

### 8.3 Spot check
Pick 5 products Dan knows the status of (in-stock, OOS, backorder) and verify API matches.

| Product | Dan says | API says | Match? |
|---|---|---|---|
| `[TBD]` | | | |

### 8.4 Known stock data gaps
`[TBD]` — document any products where API stock is known unreliable (e.g., physical inventory not synced).

---

## 9. Edge cases observed

Running log. Each entry dated and short.

- `[TBD — populate during audit]`
- Example: "2026-05-01 — Found 3 products with identical SKUs — duplicate catalog entries from pre-migration, need Dan's input."
- Example: "2026-05-02 — 'Mega G+' category has 45 products, but `GET /products?search=Mega G+` returns 52. Some products mention Mega G+ in description but aren't categorized. Implication: category-based queries miss some matches."

---

## 10. Verdict

Final audit outcome. Filled in after all sections populated.

### 10.1 What Enzo can answer cleanly today

`[TBD]` — e.g., "Exact SKU lookups (stock, price) — HIGH confidence. Fuzzy product search — MEDIUM confidence."

### 10.2 What needs cleanup in WooCommerce

`[TBD]` — e.g., "Category Y has 3 orphaned products. Attribute Z is used on 40% of products but not the other 60% — inconsistent compatibility info."

### 10.3 What needs a translation layer in the vault

Things we solve with knowledge files on top of the API rather than by cleaning WooCommerce:
- `[TBD]` e.g., Alias table for car-type synonyms
- `[TBD]` e.g., Part-type synonyms ("armature" / "arm" / "pancake armature")

### 10.4 Go/no-go per customer-question pattern

Cross-reference against tiers in `use-cases.md`:

| Pattern | Verdict | Confidence | Notes |
|---|---|---|---|
| Exact SKU lookup | `[TBD]` | | |
| Stock check by SKU | `[TBD]` | | |
| Price check by SKU | `[TBD]` | | |
| Fuzzy product search | `[TBD]` | | |
| Products by car type | `[TBD]` | | |
| Part compatibility | `[TBD]` | | |
| OOS + alternatives | `[TBD]` | | |

### 10.5 Recommended next steps after audit

`[TBD]` — based on findings, what do we build first? What needs Dan's input? What can wait?
