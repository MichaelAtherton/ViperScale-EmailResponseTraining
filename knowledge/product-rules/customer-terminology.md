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

---

_Additional aliases added via `/teach` as Dan confirms them or as they're observed in real customer messages. Do NOT add entries based on assumption — only verified terminology._
