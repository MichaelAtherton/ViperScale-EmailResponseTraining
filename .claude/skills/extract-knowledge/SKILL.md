---
name: extract-knowledge
description: Extract product rules, policies, and domain knowledge from transcripts and brain dumps into the knowledge base. USE WHEN extract knowledge from this, process this transcript, what did Dan teach us, extract from transcript, brain dump, knowledge extraction.
argument-hint: <paste transcript or file path>
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion
---

# /extract-knowledge

Process discovery transcripts and Dan's verbal brain dumps into structured knowledge base entries. This skill mines knowledge and files it — no action items, no meeting summaries.
**Voice:** Use your persona from `.claude/src/assistant-persona.md` when communicating with the user. Keep it conversational — no file paths or system details in user-facing output.

---

## Step 1: Read the Source

Read the transcript from `$ARGUMENTS`. Accepted inputs:
- Pasted transcript text
- File path to a transcript file
- "latest" → ask which transcript to process

---

## Step 2: Extract Knowledge by Category

Read through the transcript and extract items into these categories:

### Product Compatibility Rules
Look for: "X fits Y", "only these tires for Z", SKU references, "this works with that"
→ File to: `knowledge/product-rules/tire-compatibility.md`, `car-chassis-guide.md`, etc.

### Products We Don't Carry
Look for: "we don't carry those", "best bet is eBay", "that's OEM only"
→ File to: `knowledge/product-rules/discontinued-alternatives.md`

### Special-Order Items
Look for: "we can order those", "not on the website but we carry them", "order from supplier"
→ File to: `knowledge/product-rules/special-order-items.md`

### Standard Response Patterns
Look for: how Dan describes answering specific question types, his actual phrasing
→ File to: `knowledge/email-examples/<category>/`

### Routing Rules
Look for: "that goes to John", "I handle those personally", "Abby can do that"
→ File to: `context/business-profile.md` (team/routing section)

### Policy Information
Look for: shipping thresholds, warranty process, payment methods, return procedures
→ File to: `context/policies.md`

### Communication Style
Look for: Dan's actual phrasing, how he describes his tone, what he avoids saying
→ File to: `context/tone.md`

### Website Navigation
Look for: "go to shop by car type", "the category is under", navigation descriptions
→ File to: `context/website-navigation.md`

### Resource References
Look for: YouTube video mentions, manual locations, software support links
→ File to: `knowledge/resources/links.md`

### Inventory/Catalog Notes
Look for: number of products, how WooCommerce is structured, variable listings, stock management
→ File to: `knowledge/product-rules/inventory-notes.md`

---

## Step 3: Present for Review

**Do NOT write anything yet.** Present all extracted items grouped by target file:

```
I found [N] knowledge items in this transcript. Here's what I'd add:

### → knowledge/product-rules/tire-compatibility.md
1. Magnet traction rear tires: only SKU 420 and SKU 405 front end
2. [next item]

### → context/policies.md
1. Free shipping on orders over $50
2. [next item]

### → context/tone.md
1. [extracted style note]

[etc.]
```

Ask: "Which of these should I write? All, or specific items?"

---

## Step 4: Write Approved Items

For each approved item:
1. Read the target file first (if it exists)
2. Add the new entry in a format consistent with existing entries
3. If the file doesn't exist yet, create it with appropriate structure

---

## Step 5: Report

```
Written: X items to Y files
  - [file]: N items added
  - [file]: N items added

Skipped: Z items (not approved or already present)
```

---

## Guardrails

- ALWAYS present extracted items for review before writing — never auto-write
- Preserve Dan's exact phrasing for tone and response examples
- Don't extract action items or meeting logistics — this skill is knowledge-only
- If something could go in multiple files, pick the most specific one and note the cross-reference
- Check for duplicates in the target file before suggesting an addition
