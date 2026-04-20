# Customer Terminology — Alias Map

**Purpose:** Translations from how customers talk to how Viper's catalog is named. This is Pattern B in the `/teach` redesign.

Marshall consults this file *before* querying the catalog. If the customer used a known alias, Marshall translates first, then queries using Viper's terminology. Catches misspellings, informal names, and terminology that doesn't match product naming.

**Created:** 2026-04-16. Seeded with verified entries from `context/tone.md`.

---

## Hard rules for this file

1. **Verified aliases only.** Source must be either: (a) Dan/Abby confirmed, (b) documented in `context/tone.md` as a known customer pattern, or (c) observed multiple times in real customer messages.
2. **Not a synonym list.** This file maps customer-speak → catalog-speak for things customers get wrong or phrase differently. Don't add mappings like "rear tires → rear tires" — that's not translation.
3. **One customer term per entry.** If a customer term could mean two catalog items, list both options in the "Maps to" field.

---

## Entry template

```markdown
### "customer term"
- **Maps to:** [catalog term(s), SKU(s), or category ID(s)]
- **Source:** [Dan, YYYY-MM-DD] or [tone.md] or [observed N times in inbox]
- **Notes:** [optional — context, edge cases]
```

---

## Entries

### "Cortin"
- **Maps to:** Core #10 (AFX Formula Mega G+ HO Slot Car, SKU AFX-Core)
- **Source:** `context/tone.md` — "Customers frequently misspell products (e.g., 'Cortin' for Core 10, 'tracked me' for 'TrackMate')"
- **Notes:** Common misspelling. When customer says "Cortin," they probably mean the Core #10 livery car in the Mega G+ category.

### "tracked me"
- **Maps to:** TrackMate
- **Source:** `context/tone.md`
- **Notes:** Autocorrect / phonetic misspelling. Refers to the TrackMate timing system.

### "AFX G-Plus" / "Aurora G-Plus" / "Tomy G-Plus" / "G-Plus" / "G Plus"

- **Maps to:** Category 522 (Aurora G-Plus) — parent: Aurora/Tomy/AFX (id=36)
- **Source:** Customer email 2026-04-19 asked "armature for e AFX G Plus." CLI returned `chassis_not_found` because the category is named "Aurora G-Plus" on the site, not "AFX G-Plus." Council deliberation (see `doc/design/ambiguous-lookup-response.md`) determined this is a chassis-family alias issue, not a clean-no.
- **Notes:** Category currently has 2 products (Motor Magnets, Pickup Shoes — no armatures). Customers call this chassis by all three brand prefixes because Aurora was acquired by Tomy/AFX; the product naming didn't update when the brand did. Do NOT confuse with "Mega G+" (id=89) or "Super G+" (id=69) — different chassis. Seeded in `cache.py` SEED_ALIASES on 2026-04-20.

---

_Additional aliases added via `/teach` as Dan confirms them or as they're observed in real customer messages. Do NOT add entries based on assumption — only verified terminology._
