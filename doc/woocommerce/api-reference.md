# WooCommerce REST API — Viper Scale Racing Reference

**Purpose:** A curated API reference for the endpoints, parameters, and fields Enzo uses to answer customer-service questions. This is not a full WooCommerce API reference — only the surface area we actually touch.

**Source API:** WooCommerce REST API v3 (`/wp-json/wc/v3/`)
**Target site:** viperscaleracing.com
**Written:** 2026-04-16
**Status:** Initial draft based on official WooCommerce documentation. Live-API verification pending.

> **Verification legend** used throughout this doc:
> - `[VERIFIED 2026-MM-DD]` — checked against viperscaleracing.com's live API on that date
> - `[TBD — verify against live API]` — drafted from official docs, not yet confirmed on Viper's data
> - `[VIPER-SPECIFIC]` — a note about how Viper's data differs from the generic API

---

## 1. Overview

### What this doc is
A practical reference for Enzo (the customer-service AI assistant) to query Viper Scale Racing's product catalog via the WooCommerce REST API.

### Who it's for
- Michael (building the API client wrapper)
- Enzo (querying the API at answer-time)
- Future maintainers who need to understand why the integration looks the way it does

### Scope
- **In scope:** read-only product lookups (SKU, name, search, category, stock, price, variations)
- **Out of scope:** orders, customers, write operations, webhooks, the Store API (customer-facing `/wc/store/v1/`)

### How to use this doc
- Start with section 2 (Connection) to confirm auth works
- Use section 3 (Endpoints) for quick endpoint lookups
- Use section 5 (Cookbook) to map a customer question to an API call
- Flag anything marked `[TBD]` — it needs live-API verification before it's trusted

---

## 2. Connection

### Base URL
```
https://viperscaleracing.com/wp-json/wc/v3/
```
`[TBD — verify against live API: confirm base URL responds and pretty-permalinks are enabled]`

### Authentication
**Method:** HTTP Basic Auth with consumer key/secret over HTTPS.

```
Authorization: Basic base64("ck_xxxxxxxx:cs_xxxxxxxx")
```

- Username field = `ck_...` (consumer key)
- Password field = `cs_...` (consumer secret)
- Key must be **Read-only** (confirmed — generated read-only for Viper)
- Key's owning user must have Shop Manager or Administrator role
- HTTPS-only — confirmed for viperscaleracing.com

### Credential storage
Credentials live in `.env` at the vault root (already gitignored). Proposed variable names:
```
WC_BASE_URL=https://viperscaleracing.com
WC_CONSUMER_KEY=ck_xxxxxxxx
WC_CONSUMER_SECRET=cs_xxxxxxxx
```
`[TBD — confirm final variable names with Michael when he implements the client]`

### Minimal connectivity test
```
GET https://viperscaleracing.com/wp-json/wc/v3/products?per_page=1
Authorization: Basic base64("ck_...:cs_...")
```
Expected: HTTP 200 with a 1-element array of products.

`[TBD — capture actual response shape from viperscaleracing.com]`

---

## 3. Endpoint reference

### 3.1 `GET /products` — List / search products

**Purpose:** Full catalog sweep, fuzzy search, or filtered list.

**Query parameters (ones we actually use):**

| Param | Type | Default | Purpose |
|---|---|---|---|
| `search` | string | — | Free-text search across name/description. Enzo's primary "do you carry X?" tool. |
| `sku` | string | — | Exact SKU match. Returns a single-element array (or empty). |
| `category` | int | — | Filter by category ID. Must look up ID from `/products/categories` first. |
| `status` | enum | `publish` | Only published products (our default — we don't want drafts). |
| `stock_status` | enum | — | `instock` / `outofstock` / `onbackorder`. Filter by stock. |
| `per_page` | int (1-100) | 10 | Results per page. Use 100 for sweeps. |
| `page` | int | 1 | Page number (1-indexed). |
| `modified_after` | ISO8601 | — | Only products changed since given time — useful for future incremental sync. |

**Example request:**
```
GET /products?search=pinion&per_page=10
```

**Example response shape:**
```json
[
  {
    "id": 0,
    "name": "...",
    "sku": "...",
    "price": "0.00",
    "stock_status": "instock",
    "permalink": "https://viperscaleracing.com/product/...",
    ...
  }
]
```
`[TBD — replace with real response from viperscaleracing.com]`

**Response headers to capture:**
- `X-WP-Total` — total matching records
- `X-WP-TotalPages` — total pages at current per_page
- `Link` — `rel="next"` / `rel="prev"` URLs if paginated

**Viper-specific notes:**
`[VIPER-SPECIFIC — TBD: how does search handle common misspellings like "Cortin" → "Core 10"? Does WooCommerce search hit `description` and `short_description` too, or just `name`?]`

---

### 3.2 `GET /products?sku={sku}` — Exact SKU lookup

**Purpose:** Find a product by exact SKU. Enzo's primary reconciliation tool when a customer cites a specific SKU.

**Example request:**
```
GET /products?sku=ABC123
```

**Response:**
- Array of 0 or 1 products (SKU should be unique, but verify)
- Empty array = SKU not in catalog = clean "we don't carry this"

`[TBD — verify SKU uniqueness on Viper's catalog. Confirm no orphaned/duplicate SKUs.]`

---

### 3.3 `GET /products?search={term}` — Fuzzy text search

**Purpose:** Enzo's primary tool when a customer describes a product in their own words rather than citing a SKU.

**Example customer phrasings and their search terms:**
- "Do you have a pinion for a Mini-T?" → `search=pinion Mini-T`
- "I need a brushless motor" → `search=brushless motor`
- "Rear tires for my HP7" → `search=rear tires HP7`

**Considerations:**
- Search is server-side; we don't control the algorithm
- Results are ordered by relevance (WC default)
- Multi-word searches AND the terms (default WooCommerce behavior)
- `[TBD — verify search behavior on viperscaleracing.com: does it match partial words? Is it case-sensitive? Does it search descriptions?]`

**Fallback strategy:**
- Empty result with one search term → try broader terms (drop qualifiers)
- Too many results → add category filter if possible
- Ambiguous match (e.g., "pinion" returns 50 products) → ask customer for more detail

---

### 3.4 `GET /products/{id}` — Fetch by ID

**Purpose:** Fetch a single product when we already know its WC internal ID. Used for follow-up queries after a search.

**Example request:**
```
GET /products/12345
```

**Response:** Single product object (same shape as array elements from `/products`).

**When Enzo uses this:** Rarely directly — usually `/products?sku=` is what we want for known items. Useful for fetching variation parents.

---

### 3.5 `GET /products/{id}/variations` — Fetch variations

**Purpose:** For variable products (e.g., a motor that comes in 3 KV ratings), fetch the variation children to get per-variation stock and price.

**Example request:**
```
GET /products/12345/variations?per_page=100
```

**Response:** Array of variation objects.

**Why this matters:**
- On variable products, the parent has `manage_stock: false` and no meaningful stock
- Real stock data lives on each variation
- If Enzo reports "in stock" based only on the parent, it may be wrong
- `[TBD — identify top variable products on Viper and confirm stock-tracking pattern]`

---

### 3.6 `GET /products/categories` — List categories

**Purpose:** Discover the category taxonomy. Used to map customer mentions of "car types" to category IDs.

**Example request:**
```
GET /products/categories?per_page=100&hide_empty=true
```

**Response:** Array of category objects with `id`, `name`, `slug`, `parent`, `count`.

**Why this matters:**
- Customers reference car types by name ("Mega G+", "HP7", "Tyco 440X2")
- To filter `/products` by category, we need the numeric ID
- Category structure (flat vs. hierarchical) affects how we map names → IDs
- `[TBD — capture full category tree from Viper's catalog. Is "car type" the top-level taxonomy?]`

---

## 4. Product object — field reference

### 4.1 Fields Enzo cares about

| Field | Type | Enzo uses it for |
|---|---|---|
| `id` | int | WC internal ID — for follow-up queries |
| `name` | string | What to call the product in customer-facing replies |
| `sku` | string | Primary key for reconciling with customer references |
| `price` | string (decimal) | Current selling price |
| `regular_price` | string | Non-sale price — used to say "on sale from $X" |
| `sale_price` | string | Sale price if on sale |
| `stock_status` | enum | `instock` / `outofstock` / `onbackorder` — the primary stock answer |
| `manage_stock` | bool | Whether WC tracks a unit count. Matters for variable products. |
| `stock_quantity` | int \| null | Unit count (only meaningful when `manage_stock: true`) |
| `backorders` | enum | `no` / `notify` / `yes` — can it be backordered? |
| `categories` | array of objects | Which categories — Enzo maps to car type |
| `attributes` | array of objects | Specs (size, compatibility, color, etc.) |
| `description` | string (HTML) | Long description — strip HTML before quoting |
| `short_description` | string (HTML) | Short description — also HTML |
| `permalink` | string | Public product page URL — always include in replies |
| `images` | array | Product images — for visual confirmation |
| `variations` | array of int | IDs of variation children (variable products only) |
| `type` | enum | `simple` / `variable` / `grouped` / `external` |
| `status` | enum | `publish` / `draft` / `pending` / `private` |

### 4.2 Fields Enzo ignores
- `date_created`, `date_modified` — not user-facing
- `total_sales` — not our business
- `cross_sell_ids`, `upsell_ids` — future work if we do recommendations
- `meta_data` — plugin-specific, unpredictable
- `tax_class`, `tax_status` — not relevant to customer answers

### 4.3 Variable products — special handling

On a variable product (e.g., a motor with multiple KV ratings):
- Parent has `type: "variable"`, `manage_stock: false`, `stock_quantity: null`
- Parent's `stock_status` may aggregate — but don't trust it without verifying
- Real data is on variations via `/products/{id}/variations`
- Each variation has its own `sku`, `price`, `stock_status`, `stock_quantity`, `attributes`

**Enzo's rule:** If `type == "variable"`, fetch variations before reporting stock.

`[TBD — VIPER-SPECIFIC — confirm how Dan uses variable products. Common for motors, tires with sizes, gears with ratios?]`

### 4.4 Categories vs. attributes — where compatibility lives

**Open question to answer during audit:**
- Is a customer's car type (e.g., "HP7", "Mega G+") represented as a **category**, an **attribute**, or buried in the **description**?
- Or all three inconsistently?
- This determines how we answer "what products do you have for X?"

`[TBD — VIPER-SPECIFIC — audit a sample of 20 products across different car types. Document where compatibility lives.]`

---

## 5. Common query patterns (cookbook)

Recipe format: customer question → API call → interpretation → fallback.

### 5.1 "Do you carry [specific product]?"

```
GET /products?search={product name or description}&per_page=5
```
**Interpret:**
- Non-empty array → yes, we carry it. Use top result's `name`, `sku`, `permalink`, `stock_status`.
- Empty array → we don't carry it. Use clean-no response from `policies.md` / `tone.md`.

**Fallback:** If customer's phrasing is ambiguous, broaden search (drop qualifiers) before declaring no.

### 5.2 "Is SKU [X] in stock?"

```
GET /products?sku={sku}
```
**Interpret:**
- Empty array → SKU not in catalog. Flag as unusual — customer may have the wrong SKU.
- 1 result, `stock_status: "instock"` → yes, in stock. If `manage_stock: true`, include `stock_quantity`.
- 1 result, `stock_status: "outofstock"` → OOS. Recommend in-stock notifier, mention weekly restock.
- 1 result, `stock_status: "onbackorder"` → explain backorder timing (check `backorders` field).
- 1 result, `type: "variable"` → fetch variations for real answer.

### 5.3 "What's the price of [X]?"

```
GET /products?sku={sku}  # or search
```
**Interpret:**
- `price` = current selling price
- If `sale_price` set, mention the sale: "$X (regularly $Y)"
- Variable products: price range from variations

### 5.4 "What products do you have for [car type]?"

```
# First, find the category ID:
GET /products/categories?search={car type}

# Then list products in it:
GET /products?category={id}&per_page=100&stock_status=instock
```

`[TBD — VIPER-SPECIFIC — confirm this pattern works after category audit. May need fallback to `search` or attribute filter.]`

### 5.5 "Do you have [part type] for [car type]?"

```
GET /products?search={part type}&category={car type category id}
```
**Interpret:**
- Non-empty → list options (up to 3-5 for email, 1-2 for Facebook)
- Empty → we don't carry that combination. Apply clean-no from `tire-compatibility.md` if it's a chassis we don't stock for.

### 5.6 Out-of-stock + alternatives

```
GET /products?sku={sku}  # to confirm OOS
GET /products?category={same category}&stock_status=instock  # for alternatives
```
**Interpret:**
- If alternatives exist and match Dan's compatibility rules → offer them + in-stock notifier
- If no alternatives → just in-stock notifier + "we restock weekly"

### 5.7 Link to product page

Always include `permalink` verbatim in replies. Never construct URLs manually.

---

## 6. Error handling

### 6.1 HTTP status codes

| Code | Meaning | Enzo's response |
|---|---|---|
| 200 | Success | Proceed. Empty array is not an error — it's "no match". |
| 401 | Bad credentials | Escalate to Michael. Don't answer customer with stale data. |
| 403 | Insufficient role on key | Escalate to Michael. |
| 404 | Endpoint not found | Likely pretty-permalinks disabled. Escalate. |
| 429 | Rate-limited | Wait + retry once. If persists, fall back to knowledge base and flag LOW confidence. |
| 5xx | Server error | Fall back to knowledge base, flag LOW confidence, note "couldn't verify live catalog". |

### 6.2 Empty results vs. errors

**Empty result array is a valid answer, not an error.** `GET /products?sku=DOESNOTEXIST` returns `200 OK` with `[]`. This is how we answer "we don't carry that."

### 6.3 API unavailable

If the API is down or credentials fail, Enzo should:
- Fall back to rules in `knowledge/product-rules/` (less fresh but still valuable)
- Mark draft confidence as LOW
- Note in the draft: "couldn't verify against live catalog"
- Never fabricate stock/price data when the API is unreachable

---

## 7. Pagination

### When Enzo needs to paginate
- Rarely for customer answers — we usually want 1-5 results, not all 700
- Common for full-catalog sweeps (future incremental sync work)

### Mechanics
- Set `per_page=100` (max)
- Read `X-WP-TotalPages` header
- Iterate `page=1..N` if more than 1
- Prefer following `Link: rel="next"` URLs if the client supports it

### For Viper's ~700 products
Full sweep: 7 sequential requests. ~2-5 seconds. Safe to run single-threaded.

---

## 8. Known gotchas (Viper-specific)

This section fills in during data audit. Placeholder entries:

- `[TBD]` Which pretty-permalinks setting is viperscaleracing.com using?
- `[TBD]` Any Apache/LiteSpeed header-stripping issues? (symptom: "Consumer key is missing" errors)
- `[TBD]` SKU format conventions — prefixes, suffixes, consistency across old and new products
- `[TBD]` Product name inconsistencies (e.g., "HP-7" vs "HP7" vs "H.P. 7")
- `[TBD]` Categories: flat or hierarchical? Is car type a top-level category?
- `[TBD]` Attributes: which ones are used consistently vs. sparsely?
- `[TBD]` Variable products: which product lines use them? Motors? Tires with sizes?
- `[TBD]` Description content: plain HTML or cruft-heavy? Any parseable templates?
- `[TBD]` Stock accuracy: spot-check known in-stock and known-OOS products

---

## 9. Verification status

Living checklist. Each row marked `[VERIFIED 2026-04-16]` was confirmed directly against viperscaleracing.com via the scripts in `/scripts/wc-*.sh` during the Step 0 empirical check. Evidence files preserved in `scratch/` (gitignored).

### Endpoints

| Endpoint | Documented | Verified | Date | Evidence (file in `scratch/`) | Notes |
|---|---|---|---|---|---|
| `GET /products` | ✅ | ✅ | 2026-04-16 | `wc-empirical-check/01-baseline.json` | Returns 681 published products when `status=publish` is passed; draft products leak through without it |
| `GET /products?sku=` | ✅ | ✅ | 2026-04-16 | `wc-spot-tyco-vspec/` (SKU 11065 returned expected product) | Unique SKU → 1 result. Missing SKU → empty array + HTTP 200 |
| `GET /products?search=` | ✅ | ✅ | 2026-04-16 | Multiple scripts | Works well for exact product names; unreliable on short chassis tokens (`Super G` matches `Mega G+` cars). Must combine with `category=` for reliable results |
| `GET /products?category=N` | ✅ | ✅ | 2026-04-16 | `wc-spot-mega-g-cat/` | Scoping queries to a category is the reliable pattern. `category=89&search=rear tires` returns 13 relevant results |
| `GET /products/{id}` | ⚠️ | ⬜ | — | — | Not directly exercised in Step 0. Low risk (standard WP REST behavior) but marked unverified |
| `GET /products/{id}/variations` | ✅ | ⚠️ | — | `wc-empirical-check/04-sample-variable.json` (parent seen with non-empty `variations` array, variations endpoint not called) | Parent shape confirmed; variation endpoint itself not exercised in Step 0 |
| `GET /products/categories` | ✅ | ✅ | 2026-04-16 | `wc-spot-mega-g/01-categories-page2.json`, `02-categories-page3.json` | **204 categories total across 3 pages.** Pagination past 100 is mandatory |
| `GET /products/brands` | ⚠️ | ✅ | 2026-04-16 | `wc-spot-jag-beadlok/04-brands-search-jag.json`, `05-brands-all.json` | **Endpoint exists but returns empty arrays.** Brand taxonomy not populated at Viper. Cannot use for brand lookups |

**Verification legend:**
- ✅ = confirmed against live API on the date shown
- ⚠️ = partially verified or not directly exercised
- ⬜ = drafted from WooCommerce docs, not confirmed against Viper's data

### Product fields (on simple products)

| Field | Verified present | Notes (empirical) |
|---|---|---|
| `id` | ✅ | Always populated. Integer. |
| `name` | ✅ | Always populated. Strings like `"6 ohm Tyco-Timed Armature"` |
| `sku` | ✅ | **Frequently empty string.** Do not assume SKU uniquely identifies a product. Use `id` as the real primary key |
| `price` | ✅ | Decimal string, may be empty for Dealer Exempt / draft products |
| `regular_price` | ✅ | Decimal string |
| `sale_price` | ✅ | Decimal string (empty when not on sale) |
| `stock_status` | ✅ | Values seen: `instock`, `outofstock`. `onbackorder` documented but not observed in samples |
| `manage_stock` | ✅ | Observed true on simple products with real counts, false on variable parents |
| `stock_quantity` | ✅ | Int when `manage_stock: true`, `null` otherwise |
| `backorders` | ✅ | Observed value: `"no"` |
| `categories` | ✅ | Non-empty array of `{id, name, slug}` objects. **Products typically belong to 4-8 categories** (heavy cross-listing) |
| `attributes` | ✅ | **Empty on simple products.** On variable products, used only to describe the variation axis (Color, Qty) |
| `tags` | ✅ | Observed empty on sampled products |
| `brands` | ✅ | Observed empty on sampled products (see brands endpoint note above) |
| `description` | ✅ | HTML string. Strip tags before quoting to customers |
| `short_description` | ✅ | HTML string. Often empty |
| `permalink` | ✅ | **Always populated and customer-shareable.** Use verbatim — never construct URLs manually |
| `variations` | ✅ | Array of child IDs on variable products; empty on simple |
| `type` | ✅ | Values seen: `simple`, `variable`. `grouped`/`external` documented but not observed in samples |
| `status` | ✅ | Values seen: `publish`, `draft`. **Default query returns drafts unless `status=publish` is passed** |
| `slug` | ✅ | URL path segment, always unique |
| `images` | ✅ | Array with `src` URL. Only first image usually needed |

### Fields present in responses but NOT used by Enzo (confirmed noise)

Observed in `wc-empirical-check/01-baseline.json`. Listed here so the CLI's output filter doesn't miss anything.

- `_links`, `aioseo_notices`, `average_rating`, `backordered`, `backorders_allowed`, `button_text`, `catalog_visibility`, `cross_sell_ids`, `date_created`, `date_created_gmt`, `date_modified`, `date_modified_gmt`, `date_on_sale_from`, `date_on_sale_from_gmt`, `date_on_sale_to`, `date_on_sale_to_gmt`, `default_attributes`, `dimensions`, `download_expiry`, `download_limit`, `downloadable`, `downloads`, `external_url`, `featured`, `global_unique_id`, `grouped_products`, `has_options`, `low_stock_amount`, `menu_order`, `meta_data`, `on_sale`, `parent_id`, `post_password`, `price_html`, `purchasable`, `purchase_note`, `rating_count`, `related_ids`, `reviews_allowed`, `shipping_class`, `shipping_class_id`, `shipping_required`, `shipping_taxable`, `sold_individually`, `tax_class`, `tax_status`, `total_sales`, `upsell_ids`, `virtual`, `weight`

### Key empirical facts beyond field presence

From Step 0 (see `findings-log.md` for full detail):

- **681 published products** (`X-WP-Total` on `/products?per_page=1`)
- **204 categories across 3 pages** — pagination mandatory
- **Category names duplicate** (6 "Armatures" categories, 2+ "Electrical", etc.) — slugs are the unique identifier
- **Sucuri Cloudproxy WAF** fronts the site — potential rate-limit source (none observed in Step 0)
- **"Dealer Exempt" category (id=336)** has 218 products, purpose unknown — filtered by default per `implementation-spec.md` §8.6
- **Chassis→category alias required** — e.g., "Mega G+" → id 89 with slug `mega-g-tomy-afx`. Slug ≠ customer term ≠ display name
- **Compatibility info lives primarily in product names**, sometimes (e.g., `V1/V3, SG+` in a product name). Rarely in structured attributes. Often in Dan's head — needs `knowledge/product-rules/chassis-compatibility.md` layer

### Items still to verify in a future pass

Marked ⚠️ or ⬜ above. Priority order for follow-up:
1. `GET /products/{id}/variations` — exercise the endpoint directly, confirm variation shape (Step 4 test plan covers this)
2. `GET /products/{id}` — cheap to verify; do during Step 4 build
3. Onbackorder `stock_status` — sample products in that state (ask Dan for examples)
4. `grouped`/`external` product types — may not exist at Viper; confirm during Step 4 pilot

---

## 10. Sources

- `WOOCOMMERCE-INTEGRATION-HANDOFF.md` — prior research by Kai (2026-04-16)
- [WooCommerce REST API v3 Documentation](https://woocommerce.github.io/woocommerce-rest-api-docs/v3.html)
- [WooCommerce REST API — Developer Docs](https://developer.woocommerce.com/docs/apis/rest-api/)
