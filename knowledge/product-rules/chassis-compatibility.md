# Chassis Compatibility Rules

**Purpose:** Cross-chassis compatibility claims ("Part X fits chassis Y and Z"). This is Pattern A in the `/teach` redesign — the strictest knowledge type.

**Created:** 2026-04-16 (empty scaffolding — no pre-populated rules)

---

## Hard rules for this file

1. **Every entry must have a source line.** Acceptable sources:
   - `Source: Dan, YYYY-MM-DD` — Dan (or Abby relaying Dan) confirmed directly
   - `Source: product name explicit` — the product name itself marks cross-compat (e.g., "Life Like Low Rider Hard Body Clip V1/V3, SG+")
   - `Source: product description — "exact quote"` — the product description says so in its own text

2. **No inferred compatibility.** Do NOT save entries based on:
   - Naming patterns ("V1 parts usually fit V3")
   - Similar-product reasoning ("this looks like the same part")
   - Material/geometry plausibility
   - Customer assertions
   - Anything other than the three authoritative sources above

3. **Rules are read literally.** When Enzo reads this file at answer-time, the rule applies *exactly* to the product/chassis listed — no transitivity, no extension. If a rule says "X fits V1 and V3," Enzo does NOT also conclude "X fits G+" even if other V1/V3 things also fit G+.

4. **When in doubt, leave it out.** An empty file is safer than a wrong rule. An unverified claim saved here can cause customer-facing hallucination.

---

## Entry template

```markdown
### [Product name] ([SKU or "empty SKU"], ID [WC product ID if known])
- **Fits:** [chassis list]
- **Does NOT fit:** [optional — chassis explicitly excluded]
- **Source:** [one of the three forms above]
- **Notes:** [optional — edge cases, caveats, date of last verification]
```

---

## Entries

_None yet. Populated via `/teach` as Dan confirms cross-compat cases._

<!-- Example of what an entry will look like once Dan confirms V1 ↔ V3 magnet clip compatibility (see Q1 in doc/woocommerce/findings-log.md):

### Viper V1 Magnet Clip (empty SKU, ID 188)
- **Fits:** V1, V3
- **Source:** Dan, 2026-04-16
- **Notes:** customer asked about V3 clip; confirmed V1 part fits V3 chassis

This entry does NOT yet exist — shown here as template illustration only. -->
