# WooCommerce Integration — Handoff Document

**Written:** 2026-04-16
**Written by:** Kai (Michael's PAI assistant) in a prior Claude Code session
**For:** Enzo, or whichever AI picks up this work next inside the Viper Scale Racing vault
**Status:** Pre-implementation. Research complete, scope confirmed, code not yet written.

---

## What this document is

Michael is building a read-only integration between Viper Scale Racing's WooCommerce store and this vault (`viper-second-brain`). The purpose is to give Enzo programmatic access to Dan's product catalog so Enzo can answer customer service questions like *"do you carry the pinion for a Losi Mini-T?"* or *"is that brushless motor back in stock?"* with real data instead of guesses.

Research has been completed. Scoping questions have been answered. Some implementation details are still open. **Read this document in full before proposing an implementation — it will save you from re-doing research and from rebuilding things Michael already has in place.**

---

## First Actions (do these before anything else)

When Michael restarts the thread, before writing any code:

1. **Read `CLAUDE.md`** to orient to the vault (you may have already done this at session start — confirm).
2. **Read this document in full.**
3. **Ask Michael these three questions — in this order:**
   1. "Is the Viper store served over HTTPS? What's the production URL?" *(Determines auth method — Basic Auth over HTTPS is trivial; OAuth 1.0a over HTTP is painful.)*
   2. "The existing consumer key — was it generated with **Read** permissions only, or Read/Write? If Read/Write, can we regenerate it as Read-only for safety before we build anything?" *(Principle of least privilege. A read-only key literally cannot damage the store if it leaks.)*
   3. "How do you want Enzo to consume the catalog — hit the live WC API on every question, or periodically sync into a local cache (files or SQLite) inside this vault?" *(Architecture-shaping question. See 'Architectural choices' section below.)*
4. **Do NOT start coding until those three questions are answered.**

---

## Business context

| Thing | Value |
|---|---|
| Business | Viper Scale Racing |
| Owner | Dan |
| Inbox handler | Abby (Dan jumps in on hard ones) |
| Drag racing specialist | John |
| Catalog size | ~700 products, organized by car type |
| Free shipping threshold | $50 |
| Warranty returns | "Attention repairs" |
| Enzo's role | Customer service AI teammate — drafts replies in Dan's voice |
| Existing catalog path | `/ingest-catalog` command loads products from **CSV** into `knowledge/products/` |

**Why this matters for the integration:** Enzo already has a CSV-based product knowledge pathway. The WooCommerce API is either (a) a replacement for that CSV path or (b) a supplement to it that keeps stock/availability fresher than manual CSV re-imports. Clarify this with Michael before proceeding.

---

## Integration purpose and scope

**In scope (Phase 1):**
- Read-only access to product catalog
- Query products by SKU, name, category
- Retrieve stock quantity, stock status, price, variations

**Out of scope (Phase 1):**
- Creating, updating, or deleting products
- Accessing orders or customer data
- Webhooks / real-time push
- Anything that requires write permissions

**Credentials status:** Michael has already generated a consumer key/secret pair from the WooCommerce site admin. Verify it's Read-only before using it.

---

## Architectural choices — decide with Michael

The read-only catalog-query requirement can be satisfied three ways. Trade-offs differ materially.

### Option A — Live API on every query
Enzo calls `/wp-json/wc/v3/products?search=…` each time a customer question arrives.
- ✅ Always fresh — stock counts accurate to the minute
- ✅ No cache invalidation logic to write
- ❌ Every customer email → ≥1 API call (latency, WP host load, host-level rate limits)
- ❌ Fails hard if WC site is down or slow

### Option B — Periodic cache sync
A scheduled task (cron, manual, or on-demand) pulls the full catalog and writes it to a local mirror (JSON files, SQLite, or Markdown files in `knowledge/products/`). Enzo reads the local mirror.
- ✅ Fast queries, no network dependency at answer time
- ✅ Survives WC downtime
- ✅ For ~700 products, a full sync is ~7 paginated requests (per_page=100) — trivial
- ❌ Stock data is as stale as the last sync
- ❌ Need to choose sync cadence and storage format

### Option C — Hybrid
Cache product metadata (name, SKU, category, description) locally and rarely refresh. Hit the live API only for stock-critical queries.
- ✅ Best of both worlds
- ❌ Most code to write

**Kai's recommendation (non-binding):** **Option B with a Markdown-file mirror in `knowledge/products/`**, written as one file per product or per category. This matches the vault's existing "files in `knowledge/`" pattern, makes catalog data git-tracked and diffable, and means Enzo's normal knowledge-lookup pathway works unchanged. A small `/sync-catalog` command can refresh it on demand or on schedule. But confirm with Michael — Dan's priorities (fresh stock vs speed) decide this.

---

## Technical reference

Everything below was verified against official WooCommerce documentation on 2026-04-16. If you're reading this much later, spot-check the "Sources" section at the bottom for any changes.

### API choice — use REST API v3, NOT Store API

WooCommerce exposes **two** REST APIs. They are different products with different purposes.

| | **REST API v3** ✅ use this | **Store API** ❌ don't use this |
|---|---|---|
| Base URL | `/wp-json/wc/v3/` | `/wp-json/wc/store/v1/` |
| Audience | Admin / server-to-server | Customer-facing storefronts |
| Auth | Consumer keys, App Passwords | Nonce / Cart Token |
| Scope | Full CRUD on products, orders, customers | Cart, checkout, public product reads |
| Rate limiting | None from WC | Opt-in (25 POST / 10s) |
| Good for Enzo? | **Yes — this is the one** | Too limited; public only |

REST API v3 has been the mainline since WooCommerce 2.6. No v4 announced as of April 2026. The old `/wc-api/v3/` (legacy, pre-WP-REST) was **removed in WooCommerce 9.0 in June 2024** — ignore any online tutorial that mentions it.

### Base URL
```
https://viperscaleracing.com/wp-json/wc/v3/<resource>
```
(Replace with the actual production domain Michael confirms in First Action #1.)

### Authentication

**Chosen method:** HTTP Basic Auth with the consumer key/secret pair, over HTTPS.

```
Authorization: Basic base64("ck_xxxxxxxx:cs_xxxxxxxx")
```

- Username field = `ck_...` (the key)
- Password field = `cs_...` (the secret)
- **Only works over HTTPS.** If the Viper site is plain HTTP, you'd need OAuth 1.0a with HMAC-SHA256 signing instead — that's a different ballgame (nonce generation, 15-min timestamp window, signature base strings). Confirm HTTPS in First Action #1.
- The key's **owning user must have Shop Manager or Administrator role**. Keys inherit the user's capabilities.
- **Do not commit the ck/cs pair to git.** Use a `.env` file (already in `.gitignore`) or the OS keychain.

**Alternative for later:** WordPress Application Passwords also work with WC REST v3. They offer per-app revocation and cleaner audit trails. Not necessary for Phase 1 but good to know.

### Endpoints Enzo will actually use

| Endpoint | Purpose |
|---|---|
| `GET /products` | List products (paginated) — used for full-catalog sync |
| `GET /products/{id}` | Fetch one product by WC internal ID |
| `GET /products?sku=XYZ` | Find product by SKU — Enzo will use this a lot |
| `GET /products?search=pinion` | Text search — Enzo's "do you carry X?" lookup |
| `GET /products/{id}/variations` | Fetch variations of a variable product (sizes, colors, ratios) |
| `GET /products/categories` | List categories — useful if Enzo wants to browse by car type |

Query parameters worth knowing: `modified_after=<ISO8601>` (incremental sync — only products changed since), `status=publish` (exclude drafts), `stock_status=instock`.

### Product object — fields Enzo should care about

On each product or variation:

| Field | Type | Meaning |
|---|---|---|
| `id` | int | WC internal ID |
| `name` | string | Product name |
| `sku` | string | Stock keeping unit — Enzo's primary key for reconciling with customer emails |
| `price` | string (decimal) | Current price |
| `regular_price` | string | Non-sale price |
| `sale_price` | string | Sale price if on sale |
| `stock_status` | enum | `instock` \| `outofstock` \| `onbackorder` |
| `manage_stock` | bool | Whether WC tracks stock for this product |
| `stock_quantity` | int \| null | Units in stock (only meaningful when `manage_stock: true`) |
| `backorders` | enum | `no` \| `notify` \| `yes` |
| `categories` | array | Category objects — which car type this fits |
| `attributes` | array | Attribute objects — specs, compatibility |
| `description` | string (HTML) | Long description |
| `short_description` | string (HTML) | Short description |
| `permalink` | string | Public URL — useful for pointing customers to the product page |
| `images` | array | Image objects |
| `variations` | array of int | IDs of variation children (if this is a variable product) |

### Pagination

- `per_page` — default **10**, max **100**, min 1
- `page` — 1-indexed
- Response headers:
  - `X-WP-Total` — total record count
  - `X-WP-TotalPages` — total page count
  - `Link` — includes `rel="next"` and `rel="prev"` URLs (follow these instead of building your own)
- **For ~700 products:** `per_page=100` → 7 sequential requests for a full sweep. ~2-5 seconds total. Single-threaded is fine.

### Rate limiting

- **REST API v3 has no WooCommerce-imposed rate limit.**
- Throttling comes from whatever runs in front of WordPress: the host (WP Engine, Kinsta, etc. have their own limits), Cloudflare if enabled, or security plugins like Wordfence.
- If you hit a 429 or a temporary block during sync, reduce `per_page`, add a small delay between requests, and/or ask Michael what host Dan is on so we know what limits to respect.

### Official client libraries

| Language | Package | Install |
|---|---|---|
| PHP | `automattic/woocommerce` | `composer require automattic/woocommerce` |
| Node.js | `@woocommerce/woocommerce-rest-api` | `npm i @woocommerce/woocommerce-rest-api` |
| Python | `woocommerce` | `pip install woocommerce` |

All three handle HTTPS Basic Auth and OAuth 1.0a HMAC-SHA256 signing. Ask Michael which language/runtime this vault's integration code should live in before picking one.

**Deprecated — do not use:** `woocommerce/wc-api-node` (old CommonJS client).

---

## Gotchas

1. **Pretty permalinks required.** WordPress `Settings → Permalinks` must be anything other than "Plain" (e.g., `/%postname%/`). If the Viper site is on "Plain", all `/wp-json/...` routes return 404. Fallback is `?rest_route=/wc/v3/products` query-string form, but fix the permalinks instead.
2. **`Authorization` header stripped.** Some Apache / LiteSpeed / CGI configurations drop the `Authorization` header before PHP sees it. Symptom: `"Consumer key is missing"` even with correct credentials over HTTPS. Fixes: send `consumer_key=…&consumer_secret=…` as query-string params, or add this to `.htaccess`:
   ```
   SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1
   ```
3. **Self-signed SSL certs** break SDK TLS verification. Only disable verification in development, never production. If the staging site has a self-signed cert, set `verify_ssl: false` in the SDK options for that environment only.
4. **Key owner's role matters.** If Michael's existing ck/cs was generated while logged in as a Customer-role user, it will 401/403 on admin endpoints. Verify the owning user is Shop Manager or Administrator.
5. **Draft products excluded by default.** `GET /products` only returns `publish`-status products unless you explicitly ask for drafts via `status=any`. Enzo probably doesn't want drafts.
6. **Stock on variable products is per-variation.** A variable product (e.g., a motor that comes in 3 KV ratings) has `manage_stock: false` on the parent and real stock data on each variation. Enzo should fetch variations separately when stock precision matters.
7. **HTML in descriptions.** `description` and `short_description` are HTML, not plain text. Strip tags before quoting to a customer.
8. **`modified_after` for incremental sync.** Pass ISO-8601 (e.g., `2026-04-15T00:00:00`) to fetch only products changed since. Cheap way to keep a local mirror fresh.

---

## Relationship to existing `/ingest-catalog` command

The vault already has an `/ingest-catalog` command that loads product data from **CSV** into `knowledge/products/`. This WooCommerce integration is either:

- **A replacement** for the CSV flow (WC API becomes the source of truth, no more CSV exports)
- **A supplement** to it (WC API updates stock/price only; CSV or manual edits control descriptions)

Check with Michael which model he wants. Do not silently break the existing `/ingest-catalog` path.

---

## Open questions to resolve with Michael (recap)

1. Is the Viper store served over HTTPS? Production URL?
2. Is the existing consumer key Read-only, or should it be regenerated?
3. Architecture: live API on every query, periodic cache sync, or hybrid?
4. Language/runtime for the integration code (Python? Node? Shell?)?
5. Relationship to the existing `/ingest-catalog` CSV flow — replace or supplement?
6. Sync cadence if Option B is chosen (nightly? on-demand? after every order?)?
7. Where does the ck/cs pair live? (`.env` in vault? system keychain? elsewhere?)

---

## Sources (all verified 2026-04-16)

- [WooCommerce REST API v3 Documentation](https://woocommerce.github.io/woocommerce-rest-api-docs/v3.html)
- [WooCommerce REST API — Developer Docs](https://developer.woocommerce.com/docs/apis/rest-api/)
- [WooCommerce REST API — User Docs](https://woocommerce.com/document/woocommerce-rest-api/)
- [Getting Started with WooCommerce APIs](https://developer.woocommerce.com/docs/apis/)
- [Store API (the other API — don't confuse with v3)](https://developer.woocommerce.com/docs/apis/store-api/)
- [Goodbye, Legacy REST API (May 2024)](https://developer.woocommerce.com/2024/05/14/goodbye-legacy-rest-api/)
- [WP REST API Pagination](https://developer.wordpress.org/rest-api/using-the-rest-api/pagination/)
- [WP Application Passwords integration guide](https://make.wordpress.org/core/2020/11/05/application-passwords-integration-guide/)
- [Improving API Queries for Low Stock Products](https://developer.woocommerce.com/2021/08/03/developer-advisory-improving-api-queries-for-low-stock-products/)
- PHP client: `github.com/woocommerce/wc-api-php`
- Node.js client: `github.com/woocommerce/woocommerce-rest-api-js-lib`
- Python client: `github.com/woocommerce/wc-api-python`

---

*End of handoff. If anything here is unclear, ask Michael — he commissioned this document and will remember the context.*
