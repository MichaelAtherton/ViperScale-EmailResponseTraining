---
name: teach
description: Capture new knowledge from Dan's answers into the knowledge base so the vault learns over time. USE WHEN remember this, add this to the knowledge base, next time someone asks, teach, learn this, save this answer, when people ask about.
argument-hint: <what Dan is teaching you>
allowed-tools: Read, Glob, Grep, Write, Edit, AskUserQuestion
---

# /teach

Capture a new piece of knowledge from Dan (or Abby) and file it into the right place. Every answer Dan teaches once should never need to be asked again.

**Voice:** Use the persona from `.claude/src/assistant-persona.md` throughout. Be conversational — "Got it, I'll remember that" — not robotic.

**Never expose file paths or system details** in confirmations to Dan. "Saved to knowledge/product-rules/chassis-compatibility.md" is wrong. "Got it, I'll remember that V1 clip fits V3" is right.

---

## Step 1 — Classify the teach (A / B / C / other)

Read what Dan said. Classify it into one of three primary patterns. Use heuristics:

| Pattern | Signals | Example statements |
|---|---|---|
| **A — Compatibility** | Product name(s) + "fits" / "works with" / "compatible" / "doesn't fit" / cross-chassis claim | "The V1 magnet clip fits V3" • "That pinion only works on 440X2" • "We don't have anything for HP7" |
| **B — Terminology / alias** | "Customers say X" / "they mean" / "people call it" / describing a misspelling or informal term | "When someone says 'brushless motor' they mean Tyco-Timed armature" • "Customers call the Core #10 car the Cortin" |
| **C — Response pattern** | "Respond with" / "say" / "phrase it" / "when a customer does X, do Y" / "always mention" | "When someone apologizes for emailing, say 'that's our job'" • "For OOS items always mention the in-stock notifier" |

**Some teaches don't fit A/B/C** and go to other existing files (see Step 2 fallback table). Examples: new policy, new product in catalog, new email Q&A example, new resource link, routing rule.

**If ambiguous** (could be two patterns), ask ONE disambiguating question:

> "Is this about (1) which products fit what, (2) how customers phrase things, or (3) how we should word our response?"

**If still unclear after one question**, pick the best fit and confirm after saving.

---

## Step 2 — Apply per-pattern guardrails + route

### Pattern A (compatibility) — STRICT

**Before saving:** Every Pattern A entry needs a source. Ask Dan:

> "Got it. Did you confirm this yourself, or is it marked on a product page / in the product description?"

Accept only one of three sources:
1. **Dan confirmed directly** → source line: `Source: Dan, YYYY-MM-DD`
2. **Product name marks it** → source line: `Source: product name explicit` + quote the product name
3. **Product description says so** → source line: `Source: product description — "exact quote"` + the quote

**REJECT as source (don't save):**
- "I assume" / "probably" / "should fit"
- Naming patterns ("other V1 parts fit V3 so this should too")
- Customer assertions ("a customer told me")
- Plausibility arguments

If Dan says something like "probably fits, let me check" — respond: "I'll wait until you confirm before I save it. Let me know when you've verified." Do NOT save.

**Route to:** `knowledge/product-rules/chassis-compatibility.md`

Use the template in that file. Include product ID and SKU (even if empty) so the rule is unambiguous.

**Never extrapolate.** If Dan says "V1 magnet clip fits V3," save exactly that. Do NOT also save "V1 magnet clip fits G+" or any other inference.

### Pattern B (terminology) — moderate

Lower-risk than A — Dan is telling us how his customers talk, which is his authoritative read.

**Route to:** `knowledge/product-rules/customer-terminology.md`

Save with:
- The customer term in quotes
- Catalog term(s) it maps to (specific SKUs, product names, or category IDs when possible)
- Source line: `Source: Dan, YYYY-MM-DD`
- Optional notes (context, frequency)

If the mapping is ambiguous ("customers say X" could map to several catalog items), ask Dan to specify which one — or save with all plausible targets listed.

### Pattern C (response pattern) — low-risk

Dan is telling us how to phrase a response. This is his voice, his call.

**Route to:** `context/response-patterns.md`

Save with:
- Scenario description
- Trigger (what in the customer message signals this scenario)
- Response shape (how to frame the reply)
- Why (the reason Dan gave — if he gave one; otherwise ask or mark "not specified")
- Source line: `Source: Dan, YYYY-MM-DD`
- Example phrasing (Dan's actual words if he used any)

### Other patterns — fallback routing

If the teach isn't A/B/C, use this table (preserved from the original `/teach`):

| Knowledge type | File |
|---|---|
| Tire/wheel compatibility rule | `knowledge/product-rules/tire-compatibility.md` |
| Chassis/car general info | `knowledge/product-rules/car-chassis-guide.md` |
| Product we don't carry (with alternative) | `knowledge/product-rules/discontinued-alternatives.md` |
| Special-order item rule | `knowledge/product-rules/special-order-items.md` |
| New email Q&A example | `knowledge/email-examples/<category>/` |
| New Facebook comment example | `knowledge/facebook-examples/comment-replies/` |
| New Facebook DM example | `knowledge/facebook-examples/dm-responses/` |
| Resource link (video, manual, URL) | `knowledge/resources/links.md` |
| Policy change (warranty, shipping, payment) | `context/policies.md` |
| General tone / voice note | `context/tone.md` |
| Facebook-specific tone note | `context/channels/facebook.md` |
| Website navigation | `context/website-navigation.md` |
| Routing rule (who handles what) | `context/business-profile.md` |

If nothing fits, propose a new file and confirm with Dan before creating it.

---

## Step 3 — Check for duplicates and contradictions

Before writing, search the target file (and related files) for the same topic:

1. **Exact duplicate** → read it back to Dan: "I already have [existing entry]. Replace or keep both?"
2. **Similar but different** → note the overlap: "Close to an existing rule on [X]. Is this an update to that, or a separate case?"
3. **Contradiction** → flag it explicitly: "You told me before that [old rule]. Now you're saying [new rule]. Which is correct?" — per the contradiction detection rule in `context/business-profile.md`.

Don't silently overwrite. Always let Dan decide.

---

## Step 4 — Write the entry

Match the style of existing entries in the target file. Specifically:

- **Pattern A:** use the template in `chassis-compatibility.md`. Include source line. No inference.
- **Pattern B:** use the template in `customer-terminology.md`. One customer term per entry.
- **Pattern C:** use the template in `response-patterns.md`. Include trigger, response shape, why, and source.
- **Other:** match the format already in the target file. Preserve Dan's phrasing.

For email and Facebook Q&A examples, follow the format in `.claude/reference/email-qa-format.md` (or the FB equivalent), and include `Source: /teach — Dan, YYYY-MM-DD` in the Notes.

---

## Step 5 — Confirm in persona voice

Read back what was saved in plain language. No file paths, no system jargon.

Format:

> "Got it — I'll remember that. Here's what I've written down:
>
> [the entry content in natural language — what Enzo will actually do with it next time]
>
> Next time someone asks about [topic], I'll know."

**Always read back the actual content** so Dan can verify. If it's wrong, fix it before moving on.

---

## Step 6 — Offer to back-apply (when relevant)

If this `/teach` was triggered by a recent draft Enzo produced — e.g., Dan is teaching you because he just corrected a LOW-confidence answer — offer to redo the draft with the new rule:

> "Want me to redo that [draft subject] with this rule? I can update the reply now."

Skip this step if the teach is standalone (not connected to an active draft).

---

## Step 7 — Prompt for related teaches

After a successful save, invite expansion. Examples:

- After a Pattern A compatibility teach: "Anything else about [chassis / product] I should know?"
- After a Pattern B terminology teach: "Any other terms customers use for that product?"
- After a Pattern C response pattern teach: "Any other scenarios where you want the response shaped differently?"

Don't force this — if Dan is clearly done, stop. But when Dan is on a roll teaching, capture as much as possible while it's fresh.

---

## Guardrails for every `/teach`

1. **Pattern A requires authoritative source.** No source, no save. Never invent compatibility claims (echoes guardrail #9).
2. **Don't rewrite Dan's phrasing.** Capture his actual words where possible. His voice is the knowledge.
3. **Never silently overwrite.** Always flag duplicates and contradictions explicitly.
4. **Always read back what was saved.** Trust-but-verify; Dan can correct before it ships.
5. **No file paths in responses to Dan.** Keep confirmations conversational.
6. **If the teach is vague** ("remember something about tires"), ask for specifics before saving.
7. **Never extrapolate.** If Dan teaches rule X, save exactly X — don't also save adjacent rules that "probably follow."

---

## Examples of classification (for your reference)

| Dan says | Pattern | Routes to | Notes |
|---|---|---|---|
| "The V1 magnet clip fits V3 too, I just confirmed" | A | chassis-compatibility.md | Ask source — he already gave it ("just confirmed" = Dan direct). Save with `Source: Dan, YYYY-MM-DD` |
| "When customers say 'brushless motor' they probably mean a Tyco-timed armature" | B | customer-terminology.md | Save directly |
| "If someone says they can't find something on the site, acknowledge they looked before answering" | C | response-patterns.md | Save directly |
| "440X2 is a child chassis under Tyco" | Other | car-chassis-guide.md | Not A/B/C — it's general chassis info |
| "The Magnet Traction page should never include clips" | Other | car-chassis-guide.md or new | Taxonomy / inventory note, not compat |
| "Track sales over $500 go to me" | Other | business-profile.md | Routing rule |
| "Here's how I answered a customer about X: [text]" | Other | email-examples/ | New Q&A example |
