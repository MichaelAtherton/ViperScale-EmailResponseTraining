# Viper Scale Racing — WooCommerce Integration

Read-only Python client + CLI for querying the live WooCommerce catalog at viperscaleracing.com. Called by Marshall (via the `catalog-lookup` skill) from `/draft-reply` at answer time.

## Setup

**Dependencies:** Python 3.11+ with `requests` and `python-dotenv`.

```bash
cd integrations/woocommerce
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**Credentials:** the client loads from `.env` at the **vault root** (not this directory). `.env` is gitignored. Required variables:

```
WC_BASE_URL=https://viperscaleracing.com
WC_CONSUMER_KEY=ck_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
WC_CONSUMER_SECRET=cs_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
WC_TIMEOUT_SECONDS=15
```

The consumer key must be **Read-only** and owned by a Shop Manager or Administrator account.

## Usage

Run from the vault root:

```bash
# From vault root, with venv activated:
python -m integrations.woocommerce.cli <subcommand> [flags]
```

### Subcommands

| Subcommand | Purpose | Example |
|---|---|---|
| `lookup` | Exact SKU match | `lookup --sku 11065` |
| `search` | Fuzzy text search | `search --query "VSPEC Builders"` |
| `list` | Category listing | `list --chassis "Mega G+"` |
| `find` | Chassis + part (workhorse) | `find --chassis "Mega G+" --part "rear tires"` |
| `categories` | Refresh category cache + list | `categories --hide-empty` |
| `get` | Fetch one product by ID | `get --id 12345` |
| `variations` | Fetch variations of a variable product | `variations --id 12345` |

### Common flags (apply to product subcommands)

- `--limit N` — max results (default 10)
- `--in-stock` — filter to in-stock only
- `--include-dealer-exempt` — include products in the Dealer Exempt category (filtered by default)
- `--include-descriptions` — include short/long descriptions in output (HTML stripped)

## Output

Every subcommand emits a JSON envelope on stdout:

**Success:**
```json
{"ok": true, "command": "find", "count": 3, "results": [...], "category_id": 89, ...}
```

**Error:**
```json
{"ok": false, "command": "find", "error": "auth_failed", "message": "..."}
```

Exit code is 0 for success (including empty results) and 1 for real errors (config, auth, network, 5xx, bad args).

## Key behaviors

- **Drafts excluded by default:** every `/products` query injects `status=publish` automatically.
- **Dealer Exempt filtering:** products in category id=336 are filtered out by default. Pass `--include-dealer-exempt` to include them.
- **Retry policy:** one retry on 429 (2s) and connection timeouts (1s). All other errors fail fast.
- **Category cache:** `.claude/cache/wc-categories.json`, 7-day TTL. Paginates all pages (Viper has 204 categories across 3 pages).
- **Audit log:** every API call is logged to `.claude/logs/wc-queries.jsonl` (append-only JSONL).

## Chassis name resolution

The `find` and `list --chassis` subcommands resolve chassis names to category IDs via a 3-layer resolver:

1. **Alias map** — case-insensitive lookup in the seed alias table (e.g., "Mega G+" → 89)
2. **Slug match** — exact match against category slugs
3. **Name match** — exact match against category display names

Aliases are seeded from `implementation-spec.md §6.6` and extended via `/teach` as new customer phrasings are observed.

## Debugging

- **Operational logs** go to stderr at WARN level.
- **Audit trail** at `.claude/logs/wc-queries.jsonl` — one JSON line per API call with timestamp, params, status, result count. Useful for reconstructing what happened on a bad draft.
- **Cache inspection:** `cat .claude/cache/wc-categories.json` to see the current category taxonomy.

## Related docs

- `doc/woocommerce/implementation-spec.md` — full design spec
- `doc/woocommerce/api-reference.md` — endpoint + field reference (verified against Viper's live API)
- `doc/woocommerce/findings-log.md` — empirical findings from the live API
- `doc/woocommerce/integration-roadmap.md` — overall implementation roadmap
- `.claude/skills/catalog-lookup/SKILL.md` — how Marshall invokes this CLI
