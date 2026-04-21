# WooCommerce Client — Implementation Spec

**Purpose:** Blueprint for the Phase 1 read-only WooCommerce client that Enzo calls at answer-time. Michael builds from this spec.

**Written:** 2026-04-16
**Last revised:** 2026-04-16 (Step 1a — rolled empirical findings into spec)
**Status:** Ready to implement. Pre-build empirical check complete (Section 0).

**Related docs:**
- `api-reference.md` — endpoint and field reference
- `use-cases.md` — customer questions → API call patterns
- `data-audit.md` — to be populated once the client is working
- `findings-log.md` — empirical findings from live-API queries (input to this spec revision)
- `integration-roadmap.md` — overall implementation workplan

**Verified:** `.env` is excluded from git via `.gitignore` line 21 (`.env*` glob). Credentials are safe to store in `.env` at vault root.

**Key empirical facts (from `findings-log.md`, 2026-04-16):**
- 681 published products; 204 categories across 3 pages
- Drafts leak without `status=publish` — MUST be passed on every product query
- Category-scoped queries (`?category=N&search=X`) are the workhorse; plain search on common tokens is unreliable
- Multiple categories share names ("Armatures" x6, "Electrical" x2) — slugs are the unique identifier
- Brands endpoint is empty; attributes mostly empty on simple products
- Compatibility info lives in product names (sometimes) and Dan's head (mostly) — not structured fields
- Sucuri WAF in front of the site (rate-limit source if we ever hit 429)

---

## 0. Pre-build empirical check ✅ COMPLETE (2026-04-16)

**Status:** Complete. Findings incorporated into the sections below. Full detail in `findings-log.md`.

**Summary of outcomes:**
- Auth, HTTPS, pagination, pretty-permalinks all work
- Search quality is mixed — fine for unique product names, unreliable for short chassis names with common tokens (`Super G`, `Mega G`). **Decision: category-scoped queries become the primary pattern.** New `find` subcommand added to the CLI in Section 7.
- Compatibility info lives primarily in product names and Dan's head — not structured fields. **Decision: chassis-compatibility knowledge file + /teach flow handles this outside the client.**
- Variable products present but not dominant — variation fetch is part of spec but not a hot path

Historical reference — the original pre-build query script is kept below for documentation. New instances of this integration do not need to re-run it.

---

## 0a. Original pre-build query script (historical, completed)

### Why

Several load-bearing decisions in this spec depend on how WC search actually behaves on Viper's catalog, not on docs:
- Whether fuzzy search quality is good enough for "do you have a pinion for a Mini-T?" patterns (Strategy A)
- Whether we need to parse chassis → category ID before every search (Strategy B)
- Whether compatibility info lives in categories, attributes, or descriptions
- Whether variable products are common enough that variation-fetching matters in Phase 1

If the data looks different than expected, adjust the spec **before** Michael writes code.

### How to run it

Michael (or whoever has curl + the credentials) runs these 10 queries. Save raw JSON responses to a scratch file or paste them into the audit doc.

```bash
# Use curl with Basic Auth. Replace ck_/cs_ with real values.
BASE="https://viperscaleracing.com/wp-json/wc/v3"
AUTH="ck_xxx:cs_xxx"

# 1. Baseline auth + pagination check
curl -s -u "$AUTH" "$BASE/products?per_page=1" -D -

# 2. Category taxonomy dump
curl -s -u "$AUTH" "$BASE/products/categories?per_page=100&hide_empty=true"

# 3-5. SKU lookups (pick 3 real SKUs from Dan — one in-stock, one OOS, one variable product)
curl -s -u "$AUTH" "$BASE/products?sku=KNOWN-IN-STOCK-SKU"
curl -s -u "$AUTH" "$BASE/products?sku=KNOWN-OOS-SKU"
curl -s -u "$AUTH" "$BASE/products?sku=KNOWN-VARIABLE-SKU"

# 6-10. Real customer phrasings — test search quality
curl -s -u "$AUTH" "$BASE/products?search=pinion+Mini-T&per_page=5"
curl -s -u "$AUTH" "$BASE/products?search=Magnet+Traction+Kit&per_page=5"
curl -s -u "$AUTH" "$BASE/products?search=rear+tires+Mega+G&per_page=5"
curl -s -u "$AUTH" "$BASE/products?search=HP7+armature&per_page=5"
curl -s -u "$AUTH" "$BASE/products?search=brushless+motor&per_page=5"
```

### What we're looking at in the output

For each response, answer:

1. **Auth + pagination:** Did query 1 return 200? Is `X-WP-Total` present in headers?
2. **Categories:** How many exist? Is there a category per car type? Flat or hierarchical?
3. **SKU lookups:**
   - Does SKU lookup return a single match reliably?
   - Does the variable product have `type: "variable"`, `manage_stock: false`, and a non-empty `variations` array?
   - Are `stock_status` values accurate for the known in-stock and OOS products?
4. **Fuzzy search quality:**
   - For each phrasing, is the top result obviously correct?
   - Are results ordered by relevance or something else?
   - Does search match descriptions or only names?
   - Is the HP7 query empty (confirming the clean-no rule) or does it surprise us?
5. **Compatibility info:** Pick 2-3 product responses and ask — where does "this fits the Mega G+" live? Category? Attributes? Description HTML? Nowhere?

### Decision gate

After running these, we meet (you + me) and decide:

- **All 10 queries behave as spec assumes** → proceed with Phase 1 as written
- **Search quality is weak** → add category-ID resolution to Phase 1 (Strategy B), not Phase 2
- **Compatibility lives only in descriptions** → add description parsing to Phase 1
- **Variable products are rare** → deprioritize variation handling, ship simpler client
- **Something we didn't anticipate** → revise spec before build

**Estimated time:** 30 minutes for Michael to run + 30 minutes for us to review. Total: 1 hour to de-risk the whole Phase 1 build.

---

## 1. Scope

### In scope (Phase 1)
- Read-only WooCommerce REST API v3 access
- CLI with subcommands: `lookup`, `search`, `list`, **`find`**, `categories`, `get`, `variations`
- JSON output on stdout, errors on stderr
- Skill wrapper (`catalog-lookup`) that Enzo invokes
- `.env`-based credential loading
- Structured error handling (auth, network, 5xx)
- Category cache with name/slug/alias resolution (mandatory, not optional)
- All `/products` queries default to `status=publish` (drafts excluded by default)

### Out of scope (Phase 1)
- Caching / offline mirror
- Order or customer data
- Write operations
- Webhooks or real-time sync
- Dry-run / fixture mode

---

## 2. File layout

```
viper-second-brain/
├── integrations/
│   └── woocommerce/
│       ├── __init__.py
│       ├── cli.py              # CLI entry point — subcommands
│       ├── client.py           # HTTP client + WC wrapper
│       ├── config.py           # .env loading + validation
│       ├── requirements.txt    # requests, python-dotenv
│       └── README.md           # quick setup/usage notes
│
├── .claude/
│   └── skills/
│       └── catalog-lookup/
│           └── SKILL.md        # trigger phrases + how Enzo invokes the CLI
│
├── .env                        # credentials (gitignored — confirm in .gitignore)
└── .env.example                # committed template, no real values
```

### Rationale
- `integrations/woocommerce/` groups all WC code. Future integrations (Mailchimp, Gmail) land as siblings.
- `.claude/skills/catalog-lookup/SKILL.md` is a thin wrapper — tells Enzo when to invoke the CLI. No Python lives here.
- `.env` at vault root for credentials. `.env.example` documents the variables.

---

## 3. Credentials

### `.env` (vault root, gitignored)
```
WC_BASE_URL=https://viperscaleracing.com
WC_CONSUMER_KEY=ck_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
WC_CONSUMER_SECRET=cs_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
WC_TIMEOUT_SECONDS=15
```

### `.env.example` (committed)
```
WC_BASE_URL=https://your-store.com
WC_CONSUMER_KEY=ck_...
WC_CONSUMER_SECRET=cs_...
WC_TIMEOUT_SECONDS=15
```

### `.gitignore` check
Confirm `.env` is in `.gitignore`. Add if missing. Never commit credentials.

---

## 4. Dependencies

### `integrations/woocommerce/requirements.txt`
```
requests>=2.31,<3
python-dotenv>=1.0,<2
```

### Python version
3.11+ (for modern type hints, `tomllib` availability if needed later).

### Install
```bash
cd integrations/woocommerce
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Or install into the user's preferred environment — up to Michael.

---

## 5. `config.py` — credentials & settings

**Responsibilities:**
- Load `.env` (search from CWD up to root — `python-dotenv` handles this)
- Validate required variables are set
- Expose a typed config object

**Interface:**
```python
from dataclasses import dataclass

@dataclass(frozen=True)
class WCConfig:
    base_url: str
    consumer_key: str
    consumer_secret: str
    timeout_seconds: int = 15

def load_config() -> WCConfig:
    """Load WC credentials from .env. Raises ConfigError if missing or malformed."""
    ...

class ConfigError(Exception):
    """Raised when required env vars are missing or invalid."""
```

**Validation rules:**
- `base_url` — must start with `https://`, no trailing slash (strip if present)
- `consumer_key` — must start with `ck_`
- `consumer_secret` — must start with `cs_`
- `timeout_seconds` — int, default 15, must be >0

Raise `ConfigError` with a clear message if any rule fails. CLI converts this to `{"ok": false, "error": "config_error", "message": "..."}` on stdout + exit 1.

---

## 6. `client.py` — HTTP client

**Responsibilities:**
- Build authenticated requests to `{base_url}/wp-json/wc/v3/{path}`
- Handle pagination (for `list`-style operations)
- Map HTTP errors to structured exceptions
- Return parsed JSON

**Interface:**
```python
class WCClient:
    def __init__(self, config: WCConfig): ...

    def get(self, path: str, params: dict | None = None) -> tuple[list | dict, dict]:
        """GET {base}/wp-json/wc/v3/{path}. Returns (body, headers)."""
        ...

    def get_paginated(self, path: str, params: dict | None = None, max_pages: int = 20) -> list:
        """GET with automatic pagination. Concatenates results across pages. Default per_page=100."""
        ...

# Exceptions
class WCError(Exception): ...
class WCAuthError(WCError): ...          # 401, 403
class WCNotFoundError(WCError): ...      # 404 (usually pretty-permalinks)
class WCRateLimitError(WCError): ...     # 429
class WCServerError(WCError): ...        # 5xx
class WCNetworkError(WCError): ...       # timeouts, DNS, connection refused
```

### Auth
Basic Auth via `requests`:
```python
session.auth = (config.consumer_key, config.consumer_secret)
```

Always HTTPS (enforced in `config.py`).

### Pagination
- Default `per_page=100` (max)
- Read `X-WP-TotalPages` header after first request
- Stop at `max_pages` as a safety limit (default 20 → 2000 products, well above Viper's 700)
- Return concatenated results

### Timeouts
`requests.get(..., timeout=config.timeout_seconds)`. Apply to every request.

### Retries

**Implement minimal, targeted retry logic in the client.** Two specific cases get one retry each; everything else fails fast.

| Condition | Retry? | Delay | Max attempts |
|---|---|---|---|
| HTTP 429 (rate-limited) | Yes | 2s | 2 (1 retry) |
| Connection timeout | Yes | 1s | 2 (1 retry) |
| DNS/connection refused | No | — | 1 |
| 401 / 403 (auth) | No | — | 1 |
| 404 | No | — | 1 |
| 5xx | No | — | 1 |

Rationale:
- 429 and transient timeouts are genuine retry candidates — often resolve on second try.
- Auth errors are configuration problems; retrying masks the signal.
- 5xx without a retry strategy is intentional — Dan's host deciding to 500 means Enzo should degrade to knowledge base, not hammer the server.
- Single retry, not exponential backoff — Phase 1 is simple. Revisit if we see sustained issues.

Log each retry attempt to stderr at WARN level with the endpoint and status code.

### User-Agent header
Set `User-Agent: ViperSecondBrain-WCClient/0.1` so requests are identifiable in server logs if debugging is needed.

---

## 6.5 Logging and audit trail

Every API call Enzo makes should leave a trail. When a customer complains about a wrong answer, we need to reconstruct what the catalog said at the time.

### Log destinations

| Channel | Destination | Content |
|---|---|---|
| Debug / operational | stderr | INFO and above — start of request, HTTP status, retry attempts, errors |
| Audit trail | `.claude/logs/wc-queries.jsonl` | One JSON line per API call — append-only |

### Audit log format

One JSON object per line (`.jsonl` — append-only, easy to tail and grep):

```json
{
  "ts": "2026-04-16T14:32:11Z",
  "command": "search",
  "params": {"query": "pinion Mini-T", "category": null, "limit": 10},
  "endpoint": "/products",
  "status": 200,
  "result_count": 3,
  "duration_ms": 412,
  "error": null
}
```

On error, populate `error` with the error code (matching the envelope's `error` field) and leave `result_count: null`.

### What NEVER goes in logs
- Consumer key or secret (duh)
- Full product descriptions (noise, potentially customer-irrelevant HTML)
- Customer email contents (not the CLI's job to know — keep it scoped)

### Log rotation
Not Phase 1's problem. The `.jsonl` file grows append-only. Revisit if it exceeds ~10 MB (will take months at expected volume).

### Privacy
`.claude/logs/` should be in `.gitignore` — audit trail is machine-local, not vault content.

`[TBD — confirm `.claude/logs/` is gitignored, or add during build]`

---

## 6.6 Category-ID cache (mandatory)

Categories change rarely. The cache is not an optimization — it is the **primary way** Enzo resolves customer chassis mentions to category IDs, which is the keystone of every "X for chassis Y" query.

**Empirical facts driving this design (from `findings-log.md`):**
- Viper has **204 categories across 3 pages** at per_page=100. Pagination is mandatory.
- **Category names duplicate.** "Armatures" appears as 6 separate categories, "Electrical" as 2, "Chassis" as multiple. Slugs are the unique identifier.
- Customer terminology doesn't always match category names. "Mega G+" maps to a category with slug `mega-g-tomy-afx`, not `mega-g-plus`. An alias layer is required.

### Cache file

`.claude/cache/wc-categories.json` (gitignored — confirmed in `.gitignore` line 21 via the `.env*` glob doesn't cover this; a separate entry for `.claude/cache/` needs to be added during build).

Shape:
```json
{
  "fetched_at": "2026-04-16T14:00:00Z",
  "page_count": 3,
  "total_categories": 204,
  "categories": [
    {"id": 89, "name": "Mega G+", "slug": "mega-g-tomy-afx", "parent": 36, "count": 66},
    {"id": 69, "name": "Super G+", "slug": "super-g", "parent": 36, "count": 151},
    {"id": 38, "name": "440X2", "slug": "440x2", "parent": 37, "count": 97},
    {"id": 37, "name": "Tyco", "slug": "tyco", "parent": 22, "count": 97},
    {"id": 45, "name": "JAG", "slug": "jag", "parent": 16, "count": 19},
    {"id": 252, "name": "Clips/Brackets/Misc", "slug": "clips-brackets-misc", "parent": 27, "count": 21}
  ],
  "aliases": {
    "mega g+": 89,
    "mega g plus": 89,
    "super g+": 69,
    "super g plus": 69,
    "super g": 69,
    "tyco 440x2": 38,
    "tyco 440": 38,
    "tyco": 37,
    "jag hobbies": 45,
    "jag": 45,
    "v3": 496,
    "v1": 26
  }
}
```

### Cache rules

- **Pagination is mandatory.** Refresh fetches ALL pages by following `X-WP-TotalPages` or `Link: rel=next`. Do NOT stop at the first 100 results — Viper has 204 total, so 104 categories would silently be missing.
- **On startup of any CLI command** that needs category resolution: check if cache exists and `fetched_at` is <7 days old.
- **If stale or missing:** refresh via paginated `GET /products/categories?per_page=100&hide_empty=true` and rewrite the cache.
- **On explicit `categories` subcommand:** always refresh cache, then return.
- **Failure to refresh:** use the stale cache if available, emit a WARN to stderr. Better stale than nothing.

### Name resolution (3-layer)

The client exposes a helper:
```python
def resolve_category_id(text: str) -> int | None:
    """
    Resolve a chassis/brand/part-type string to a category ID.
    Tries three layers in order:
      1. Exact alias match (case-insensitive) against the `aliases` map
      2. Exact slug match against cached categories
      3. Exact name match (case-insensitive) against cached categories
    Returns None if no layer matches.
    """
```

Why three layers, in this order:
- **Aliases first** — customer-facing terminology ("Mega G+", "Super G") differs from slugs (`mega-g-tomy-afx`, `super-g`) and sometimes from names. The alias map is the translation layer.
- **Slug second** — slugs are unique globally; name matches are ambiguous when names repeat.
- **Name last** — fallback for cases where alias/slug don't apply. Risk: ambiguous names (6 "Armatures" categories) return the first match, which may be wrong. The alias layer should cover the cases that matter before name-matching is reached.

### Seed alias list

Ship with the 12-entry alias map in the example above. Add new aliases via `/teach` (Pattern B — customer terminology) as they're discovered in pilot emails. Do not pre-populate aliases beyond what's empirically verified.

### Cache location + gitignore
`.claude/cache/` and `.claude/logs/` — both gitignored, machine-local. **Action during build:** add these two entries to `.gitignore` explicitly (the existing `.env*` rule doesn't cover them).

---

## 7. `cli.py` — CLI entry point

**Responsibilities:**
- Parse subcommand + flags
- Invoke `client.py` methods
- Serialize results to the standard JSON envelope
- Map exceptions to structured error output
- Set appropriate exit code

### Invocation
```bash
python integrations/woocommerce/cli.py <subcommand> [flags...]
```

### Global flags (apply to all subcommands)
- `--limit N` — max results returned (default 10, max 100 for search/list)
- `--json` — always on, no pretty-print. Output is machine-readable.

### Subcommands

**IMPORTANT — default behaviors applied to every `/products` call:**
- `status=publish` is ALWAYS injected unless `--include-drafts` is explicitly passed (catches the draft-leak bug from `findings-log.md`)
- Dealer Exempt products (category id=336) are filtered from results by default unless `--include-dealer-exempt` is passed (interim policy — see Section 8.6)

#### `lookup` — exact SKU lookup
```bash
python cli.py lookup --sku ABC123
```
- Calls `GET /products?sku={sku}&status=publish`
- Expected: 0 or 1 result

#### `search` — fuzzy text search
```bash
python cli.py search --query "Tyco Timed Armature"
python cli.py search --query "rear tires" --category 89
python cli.py search --query "VSPEC Builders"
```
- Calls `GET /products?search={query}&category={id}&stock_status=instock&status=publish&per_page={limit}`
- Flags: `--query` (required), `--category ID`, `--in-stock`, `--limit N`
- **When to use:** customer cited a specific named product (e.g., "Tyco Timed Armature"). For part+chassis queries, prefer `find`.
- **Known limitation:** plain search on short chassis names with common tokens (e.g., `search=Super G`) returns unrelated results. Use `find` for chassis-scoped queries.

#### `find` — part + chassis (the workhorse) ⭐ NEW
```bash
python cli.py find --chassis "Mega G+" --part "rear tires"
python cli.py find --chassis "Super G+" --part "armature"
python cli.py find --chassis "Tyco 440X2" --part "clip"
python cli.py find --chassis "V3" --part "magnet clip"
```
- **What it does:** resolves the chassis name to a category ID via the cache, then runs a category-scoped search for the part.
- **Equivalent to:** `GET /products?category={resolved_id}&search={part}&status=publish&per_page={limit}`
- **Flags:** `--chassis STRING` (required), `--part STRING` (required), `--in-stock`, `--limit N` (default 10)
- **Resolution:** the chassis string matches (case-insensitive) against cached category names, slugs, and aliases. First match wins. If no match → `{"ok": false, "error": "chassis_not_found", "message": "..."}`.
- **Why this exists:** per `findings-log.md`, category-scoped queries are the only reliable pattern for "X for chassis Y" questions. This subcommand handles the chassis→category lookup so the caller doesn't have to.
- **Example success output:** for `find --chassis "Mega G+" --part "rear tires"`, returns ~13 results all scoped to Mega G+ category (id=89).

#### `list` — category listing
```bash
python cli.py list --category 89
python cli.py list --category 89 --in-stock --limit 50
```
- Calls `GET /products?category={id}&stock_status=...&status=publish&per_page={limit}`
- Flags: `--category ID` (required), `--in-stock`, `--limit N`
- **When to use:** customer asked "what do you have for [chassis]?" without specifying a part type. Returns up to 100 category products.

#### `categories` — list categories (paginated)
```bash
python cli.py categories
python cli.py categories --hide-empty
```
- Calls `GET /products/categories?per_page=100&hide_empty={bool}`
- Flags: `--hide-empty` (filters out categories with 0 products)
- **Pagination REQUIRED:** Viper has 204 categories across 3 pages. Must follow `X-WP-TotalPages` and/or `Link: rel=next` until exhausted. **Do not stop at 100.** Always refreshes the local cache.

#### `get` — fetch by ID
```bash
python cli.py get --id 12345
```
- Calls `GET /products/{id}`
- Expected: 1 result or 404
- Note: doesn't apply status filter since ID-lookup is explicit. If caller fetches a draft ID, they get the draft.

#### `variations` — fetch variations of a variable product
```bash
python cli.py variations --id 12345
```
- Calls `GET /products/{id}/variations?per_page=100`
- Expected: array of variation objects
- **When to use:** catalog returned a product with `type: "variable"` — fetch variations to report accurate stock/price.

---

## 8. Output format

### Success envelope
```json
{
  "ok": true,
  "command": "search",
  "count": 3,
  "results": [
    {
      "id": 12345,
      "name": "Example Pinion Gear 14T",
      "sku": "PIN-14T-MT",
      "price": "6.99",
      "regular_price": "6.99",
      "sale_price": "",
      "stock_status": "instock",
      "manage_stock": true,
      "stock_quantity": 42,
      "backorders": "no",
      "type": "simple",
      "categories": [{"id": 42, "name": "Mini-T", "slug": "mini-t"}],
      "attributes": [],
      "permalink": "https://viperscaleracing.com/product/example-pinion-gear-14t/",
      "variations": []
    }
  ]
}
```

### Error envelope
```json
{
  "ok": false,
  "command": "search",
  "error": "auth_failed",
  "message": "401 Unauthorized — check WC_CONSUMER_KEY and WC_CONSUMER_SECRET"
}
```

### Exit codes
| Exit | Meaning |
|---|---|
| 0 | Success (including empty results — empty is a valid answer) |
| 1 | Real error (auth, network, 5xx, config, bad args) |

### Error codes (in `error` field)
- `config_error` — missing/invalid env vars
- `bad_args` — bad CLI arguments
- `auth_failed` — 401/403 from WC
- `not_found` — 404 on endpoint (often permalinks)
- `rate_limited` — 429
- `server_error` — 5xx
- `network_error` — timeout, DNS, connection
- `unknown_error` — catch-all; include original message

### Result object — fields returned

Flatten the WC product shape to what Enzo actually uses (per `api-reference.md` section 4.1). Exclude noise fields (`total_sales`, `meta_data`, `tax_class`, `cross_sell_ids`, `upsell_ids`, images, dates).

For category objects in `categories`:
```json
{"id": 42, "name": "Mini-T", "slug": "mini-t"}
```

For variation objects (`variations` subcommand):
```json
{
  "id": 67890,
  "parent_id": 12345,
  "sku": "MOT-2000KV",
  "price": "19.99",
  "stock_status": "instock",
  "stock_quantity": 8,
  "manage_stock": true,
  "attributes": [{"name": "KV Rating", "option": "2000"}]
}
```

Strip HTML from `description` and `short_description` — use `html.unescape` + a simple regex or `html.parser` to remove tags. Don't include descriptions in default output (too noisy); add a `--include-descriptions` flag if needed later.

---

## 8.5 Disambiguation — when search returns many results

Broad customer queries return long result lists. "Do you have a pinion?" could return 30+ pinions. Dan's tone is direct and helpful — *not* "here are 30 things, pick one." Enzo needs a consistent disambiguation strategy.

### Result-count decision tree (Enzo applies this, not the CLI)

| Result count | Action |
|---|---|
| 0 | Apply clean-no rules from `knowledge/product-rules/`. Don't suggest alternatives unless rules allow. |
| 1 | Answer directly with name, SKU, stock, price, permalink. |
| 2-3 | Present all options briefly — "we've got X ($A), Y ($B), or Z ($C) — here are the links." |
| 4-6 | Group by a differentiator if obvious (car type, scale, variant). If no clean grouper, ask ONE clarifying question. |
| 7+ | Always ask ONE clarifying question before listing. Never dump a long list. |

### Clarifying questions Enzo should use

Pattern: **one specific question, not a menu.** Dan's voice.

- "What chassis are you running it on?" (when car type would filter)
- "Is this for a Mega G+ or an older chassis?" (when car generation matters)
- "Are you looking for stock or aftermarket?" (when variant class matters)
- "Do you know the SKU or roughly what it looked like?" (last resort)

### What Enzo should NOT do

- Paste a 30-item list in an email
- Say "here are all the options" then itemize
- Ask multiple clarifying questions at once ("what chassis? what scale? what color?")
- Guess the most likely intent — ask

### The CLI's role

The CLI just returns results capped at `--limit`. Enzo applies the decision tree against the returned count. Default `--limit 10` is a reasonable working ceiling — if all 10 are relevant, ask a clarifying question; if only 2-3 of 10 are relevant, filter client-side and present those.

### Canonical example — count > 0 but compatibility unclear

From `findings-log.md` spot check: customer asks "Which BeadLok wheels do you have for Super G cars?"

- Query: `find --chassis "Super G+" --part "BeadLok"` → 1 result
- Result: **"Python" BeadLok Billet Wheel Set for Inlines** ($42.95, in stock)
- Ambiguity: product is named "for Inlines," not "for Super G+" — is Super G+ an inline chassis? Unknown at catalog level.

**The disambiguation decision tree says "1 result → answer directly."** But guardrail #9 says don't invent compatibility. Resolution:

1. Check `knowledge/product-rules/chassis-compatibility.md` for a rule about Super G+ and inline wheels
2. **If a rule exists** → answer directly per the rule, HIGH confidence
3. **If no rule** → customer-facing draft presents what we found without claiming fit: *"We've got the Python BeadLok Billet Wheel Set — $42.95, in stock: [link]. Let us know if that's the one you want."* Internal note flags the unknown and suggests the reviewer verify with Dan before sending.

**This pattern generalizes:** whenever catalog returns products but compatibility with the customer's chassis isn't explicit in name/description and isn't covered by a rule, the draft stays factually tight (what we have) and the internal note surfaces the question. Never bridge the gap with inference.

---

## 8.6 Dealer Exempt category filtering (interim policy)

From `findings-log.md`: category id=336 "Dealer Exempt" contains 218 products. Purpose unknown (likely wholesale-only or internal), and we haven't asked Dan yet.

**Interim rule:** the CLI filters out products whose `categories` array contains id=336 by default. This prevents wholesale/internal products from appearing in customer-facing answers.

**Escape hatch:** `--include-dealer-exempt` flag on `search`, `find`, and `list` subcommands overrides the filter. Not used in normal customer-question flows; available for debugging or admin-facing queries.

**Open question:** Dan needs to confirm whether Dealer Exempt products should ever appear in retail customer answers. Once answered, either remove the filter (if retail-visible) or hard-code it (if never-retail) and remove the escape hatch. Track in `integration-roadmap.md` open-questions table.

---

## 9. `.claude/skills/catalog-lookup/SKILL.md`

### Purpose
Tell Enzo when to invoke the CLI and how to interpret output.

### Draft content

```markdown
---
name: catalog-lookup
description: Query the live Viper Scale Racing catalog for product existence, stock, price, and categories. Triggers on "do you carry", "is X in stock", "how much is", "what fits", "do you have", and any customer mention of a specific SKU or product name.
---

# Catalog Lookup — Decision Tree

You query the live WooCommerce catalog via CLI. Read this every time you invoke it. It is instructions, not docs.

## Trigger phrases (invoke when you see these patterns)

- "do you carry / have / sell …"
- "is … in stock / available"
- "how much is / what's the price of …"
- "what fits a / for my [chassis]"
- "what tires / pinions / armatures for …"
- Any specific SKU mentioned by the customer
- Any specific product name (e.g. "Magnet Traction Kit")

## Do NOT invoke for

- Warranty, returns, refunds → `context/policies.md`
- Shipping, free-shipping threshold → `context/policies.md`
- Routing (track sales, drag racing) → `context/business-profile.md`
- Tone / voice / greeting questions → `context/tone.md`
- Third-party tech support (Windows, timing software) → `context/policies.md`

## Step 1 — classify the input

| Customer gave you | Go to |
|---|---|
| An exact SKU | Step 2a |
| A specific product name ("Magnet Traction Kit") | Step 2b |
| A part + chassis ("pinion for Mini-T") | Step 2c |
| Just a car type ("what do you have for Mega G+") | Step 2d |
| Multiple products in one message | Run steps per product, combine in reply |

## Step 2a — SKU lookup

```bash
python integrations/woocommerce/cli.py lookup --sku {SKU}
```

Then go to Step 3.

## Step 2b — Product name search

```bash
python integrations/woocommerce/cli.py search --query "{exact product name}" --limit 5
```

Then go to Step 3.

## Step 2c — Part + chassis search

First resolve the chassis to a category ID (cheap — cached locally):
```bash
python integrations/woocommerce/cli.py categories --hide-empty
```
Find matching category, note its `id`. Then:
```bash
python integrations/woocommerce/cli.py search --query "{part type}" --category {id} --limit 10
```

If chassis isn't in category list → check `knowledge/product-rules/tire-compatibility.md` for clean-no rule. If listed there ("HP7, HP2, Curvehugger, Aurora AX"), skip the search entirely and go to Step 4 with count=0.

Then go to Step 3.

## Step 2d — Category browse

Resolve car type to category ID (Step 2c method), then:
```bash
python integrations/woocommerce/cli.py list --category {id} --in-stock --limit 20
```

Then go to Step 3.

## Step 3 — interpret the result

Check `ok` and `count`:

| `ok` | `count` | Do this |
|---|---|---|
| `true` | `0` | Go to Step 4 (clean-no path) |
| `true` | `1` | Answer directly: name, SKU, stock, price, permalink |
| `true` | `2-3` | Present all options briefly with prices and links |
| `true` | `4-6` | Group by differentiator if obvious, else ask ONE clarifying question |
| `true` | `7+` | Ask ONE clarifying question before listing anything |
| `false` | — | Go to Step 5 (error path) |

**For variable products** (`type: "variable"`): fetch variations before quoting stock.
```bash
python integrations/woocommerce/cli.py variations --id {product_id}
```

**Always include the `permalink`** in the draft reply. Dan's explicit preference.

## Step 4 — clean-no path (count=0)

1. Check `knowledge/product-rules/tire-compatibility.md` — is this chassis on the don't-stock list?
   - Yes → clean no: "Unfortunately, we don't offer anything for the [chassis]. Best bet's eBay." Confidence HIGH.
   - No → we may not carry it, OR search just didn't find it.
2. If the customer cited a SKU specifically → "I couldn't find SKU [X] in our catalog — can you double-check the number?" Confidence MEDIUM.
3. If fuzzy search came back empty → try broader terms once (drop qualifiers). If still empty, clean no. Confidence MEDIUM.
4. **Never** offer alternatives unless a rule in `knowledge/product-rules/` allows it for this chassis.

## Step 5 — error path (`ok: false`)

Drafts always go to a Viper team member for review — the reviewer (Abby, John, or Dan) is your reader for error cases, not the customer. Error information goes in the **internal note**, never in the customer-facing draft.

| `error` code | Action |
|---|---|
| `auth_failed` | Do not draft with fabricated data. Write the safest possible draft (or no draft) and put full detail in the internal note for the reviewer + Michael. |
| `not_found` | Endpoint issue (likely permalinks). Same as auth_failed — safe draft + flag in note. |
| `rate_limited` | CLI already retried once. Wait 30s, try again. If still failing, fall to knowledge base; mark confidence LOW in the note. |
| `server_error` | Fall to knowledge base, confidence LOW in the internal note. The note tells the reviewer "live catalog was unreachable; draft is based on knowledge-base rules only." Never put that language in the customer draft. |
| `network_error` | Same as server_error. |
| `config_error` | Surface to Michael via internal note. |

When falling back to the knowledge base: use rules from `knowledge/product-rules/` but **never fabricate stock status or prices** in the customer-facing draft. If stock is unverifiable, write a draft that avoids making a stock claim (e.g., "here's the product" + link, without "in stock"), and note to the reviewer: "catalog unreachable — reviewer should verify stock before sending."

## Clarifying-question patterns

Ask ONE question, never a menu. Dan's voice.

- "What chassis are you running it on?"
- "Is this for the Mega G+ or an older chassis?"
- "Do you know the SKU or roughly what it looked like?"
- "Stock or aftermarket?"

## Product rules override the catalog

Catalog answers existence + stock + price. It does NOT answer:
- Compatibility judgment ("will this fit?") — use `knowledge/product-rules/`
- Special-order flow (sponge tires) — rules override catalog OOS
- Recent corrections from Dan — `[Phase 2 concern — see note at end]`

When catalog and rules conflict, **rules win for compatibility**, **catalog wins for existence/stock**.

## Confidence flags on final draft

- HIGH — live API returned a clean single match AND no rule conflict
- MEDIUM — live API returned results but required judgment (disambiguation, rule overlay)
- LOW — API unavailable OR count=0 without a clean-no rule to cite

## Phase 2 note (not implemented yet)

Recent /teach corrections from Dan should override catalog answers (e.g., Dan said an item is actually OOS today even though catalog says in-stock). This override layer is not built in Phase 1 — if you know of a recent correction from the current conversation, apply it when drafting and surface the override in the **internal note** to the reviewer (never in the customer-facing draft). Phrase it as: "internal: applied today's correction from Dan that this SKU is OOS — verify before sending." Phase 1 cannot see corrections from prior sessions reliably; that's the full-override layer to design in Phase 2.
```

---

## 10. Manual test plan

After the build, run these smoke tests against the live API. Each test uses real SKUs and values discovered during the empirical check (see `findings-log.md`). If any fails, debug before proceeding.

### Test 1 — Config loads + pagination works
```bash
python integrations/woocommerce/cli.py categories --hide-empty
```
Expect: JSON success envelope with `count >= 200` (Viper has 204 categories across 3 pages). Proves `.env`, auth, HTTPS, pretty-permalinks, and pagination all work. **If `count == 100`, pagination is broken** — this is the mistake the original spec would have allowed.

### Test 2 — SKU lookup (known in-stock product)
```bash
python integrations/woocommerce/cli.py lookup --sku 11065
```
Expect: `count: 1`, `name: "6 ohm Tyco-Timed Armature"`, `price: "6.50"`, `stock_status: "instock"`.

### Test 3 — SKU lookup (non-existent)
```bash
python integrations/woocommerce/cli.py lookup --sku DEFINITELYNOTREAL123
```
Expect: `ok: true`, `count: 0`, `results: []`. Exit code 0.

### Test 4 — `find` subcommand (the workhorse)
```bash
python integrations/woocommerce/cli.py find --chassis "Mega G+" --part "rear tires"
```
Expect: `count` between 5 and 15, each `result` has `categories` containing id=89 (Mega G+), top result's `name` contains "Mega G+" OR is a generic rear-tire/wheel product. No Mega G cars should appear (those would be unrelated — proving search is correctly scoped via category).

### Test 5 — Search for exact-named product
```bash
python integrations/woocommerce/cli.py search --query "VSPEC Builders" --limit 5
```
Expect: exactly 2 results — "V3 VSPEC-X Builders Kit" and "V1 VSPEC Builders Kit". Both in stock.

### Test 6 — Draft products are excluded by default
```bash
python integrations/woocommerce/cli.py list --category 414 --limit 20
```
Expect: Custom Cars category results, but NONE should have `status: "draft"`. Specifically, the "Custom Order for Larry" draft (found in Step 0) must NOT appear. If it does, `status=publish` is not being injected — the critical bug.

### Test 7 — Dealer Exempt filtering
```bash
python integrations/woocommerce/cli.py search --query "JAG Hobbies" --limit 10
```
Expect: multiple JAG results, but NONE should have a category containing id=336 (Dealer Exempt). With `--include-dealer-exempt`, the result set should be larger.

### Test 8 — Bad auth (error path)
Temporarily break `WC_CONSUMER_SECRET` in `.env`.
Expect: `ok: false`, `error: "auth_failed"`, message includes "401". Exit code 1. Restore `.env` after.

### Test 9 — Variable product variations
```bash
# First find a known variable product via search (guide pins are variable by color)
python integrations/woocommerce/cli.py search --query "Viper Hybrid Extended Guide Pin"
# Parent will have type=variable, manage_stock=false, non-empty variations array. Pick its ID, then:
python integrations/woocommerce/cli.py variations --id {parent_id}
```
Expect: array of 5 variation objects (Blue, Natural, Purple, Red, Brass), each with its own SKU and stock_status.

### Test 10 — Chassis alias resolution
```bash
python integrations/woocommerce/cli.py find --chassis "super g" --part "rear rims"
```
Expect: results scoped to Super G+ category (id=69) — note the alias lowercase "super g" correctly resolves to Super G+ category, not confused with "Mega G+" or other G-containing categories. Top results should be rear rim products (e.g., from category 190 "Rear Rims - Super G").

### Test 11 — Network failure simulation
Disable wifi, run:
```bash
python integrations/woocommerce/cli.py categories
```
Expect: `ok: false`, `error: "network_error"`. Exit code 1. Re-enable wifi after.

### If any test fails

- **Tests 1, 8, 11** fail → infrastructure issue (auth, network, config). Fix and rerun.
- **Test 2, 3, 5, 9** fail → API interaction issue. Check HTTP details in the wc-queries log.
- **Test 4 (find)** fails → chassis resolution is broken. Check cache contents, alias map, and slug matching.
- **Test 6 (drafts)** fails → `status=publish` isn't being injected. **Critical bug — fix before any further progress.**
- **Test 7 (Dealer Exempt)** fails → filtering logic broken. Verify category id 336 is being excluded client-side.
- **Test 10 (alias)** fails → alias layer is broken. Check the seed alias map in the cache.

**If all 11 pass:** the client is ready for Enzo to integrate into `/draft-reply`. Next step is populating `data-audit.md` with real findings.

---

## 11. Open decisions Michael makes during build

These are small enough that Michael can decide without blocking.

1. **Argument parsing library** — `argparse` (stdlib, fine) or `click` (nicer). My lean: `argparse` to avoid another dep.
2. **HTML stripping library** — stdlib `html.parser` or a regex. Either fine for Phase 1.
3. **Test scaffolding** — not required for Phase 1, but if Michael wants a couple of `pytest` smoke tests, welcome. Put them in `integrations/woocommerce/tests/`.

(Logging is no longer a decision — see section 6.5. Stdlib `logging` to stderr for operational logs, append-only `.jsonl` to `.claude/logs/` for audit trail. Don't log credentials, ever.)

---

## 12. Done criteria

Phase 1 client is done when:

1. `.env` loads, auth succeeds against viperscaleracing.com
2. All 7 manual tests pass
3. `SKILL.md` exists and Enzo can find + invoke the CLI
4. `README.md` in `integrations/woocommerce/` documents setup for future maintainers
5. `.env.example` committed; `.env` is in `.gitignore`
6. No credentials in git history

After done: populate `data-audit.md` sections 2–8 from real API responses, update verification status in `api-reference.md` section 9.

---

## 13. Phase 2 concerns (flagged, not solved)

These matter for correctness but are deliberately out of Phase 1 scope. Revisit after Phase 1 ships.

### 13.1 Dan's recent corrections should override the catalog

The catalog is truth-as-of-last-sync from Dan's POS/fulfillment. When Dan has told Enzo something more recent via `/teach` (e.g., "that part is actually OOS today, shipped the last one"), that correction should override the live catalog answer.

**Problem:** No mechanism exists to reconcile `/teach` entries with live API responses. Enzo currently treats them as parallel knowledge sources.

**Proposed Phase 2 approach (sketch, not committed):**
- Teach entries that contain SKUs or product names get tagged with the SKU on save.
- At query-time, after getting catalog results, Enzo checks `knowledge/` for any recent (last 24-72 hours) teach entries mentioning that SKU or product.
- If found, prefer the teach entry's stock/availability claim, flag the reply with "based on recent team update."

**Why Phase 2, not Phase 1:** Requires indexing `/teach` entries by SKU, deciding on a freshness window, and building a reconciliation rule. Real work, not code. Ship Phase 1 first, observe where this actually bites us, then design the override layer against real examples.

**In the meantime:** If Enzo knows of a recent correction from conversation context, apply it manually and flag the draft for Dan's review with "my recent note says…"

### 13.2 Concurrent query batching

Phase 1 CLI spawns a new Python process per subcommand invocation. For multi-topic customer emails, Enzo may fire 3-4 queries sequentially — each paying startup cost and fresh auth handshake.

**Phase 2 options:**
- Batch subcommand that accepts a list of queries in one invocation
- Persistent daemon (overkill for our volume)
- MCP server replacement for the CLI (also overkill today, but worth knowing it's the natural evolution)

### 13.3 Caching beyond categories

Categories are cached (section 6.6). Phase 2 candidates for caching:
- Product-ID → name/SKU index (rarely changes, makes disambiguation faster)
- Full catalog snapshot for offline/degraded mode

Don't cache stock or price. Ever.

### 13.4 Write operations

Phase 1 is strictly read-only. If we ever add writes (creating draft products, updating stock), that's a new spec, new key with write permissions, and new guardrails — not an extension of this client.

### 13.5 Order + customer data

Same: separate integration entirely. Do not bolt it on.
