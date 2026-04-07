---
name: teach
description: Capture new knowledge from Dan's answers into the knowledge base so the vault learns over time. USE WHEN remember this, add this to the knowledge base, next time someone asks, teach, learn this, save this answer, when people ask about.
argument-hint: <question type and Dan's answer>
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion
---

# /teach

Capture a new piece of knowledge from Dan (or Abby) and file it into the correct location in the knowledge base. This is how the vault learns — every question Dan answers once gets captured so it never needs to be answered from scratch again.

---

## Step 1: Understand the Input

The user provides a question type and answer. This can come in several forms:
- "If anyone asks about X, tell them Y"
- "Remember this — [product] doesn't fit [chassis]"
- "Next time someone asks about [topic], the answer is [answer]"
- "Add this to the knowledge base: [information]"
- A corrected draft from `/draft-reply` where Dan changed the answer

Extract:
1. **The topic** — what product, rule, or scenario is this about?
2. **The knowledge** — what should we tell customers?
3. **Any conditions** — "only for [chassis type]", "unless they want [alternative]"

---

## Step 2: Determine the Right File

| Knowledge Type | File Location | Examples |
|---------------|---------------|----------|
| Product compatibility rule | `knowledge/product-rules/tire-compatibility.md` | "SKU 420 fits Magnet Traction rear" |
| Chassis/car information | `knowledge/product-rules/car-chassis-guide.md` | "Mega G+ uses different axle than AFX" |
| Product we don't carry | `knowledge/product-rules/discontinued-alternatives.md` | "Magnum 44X2 → eBay" |
| Special-order item | `knowledge/product-rules/special-order-items.md` | "Outlaw sponge tires — order from supplier" |
| New email Q&A example | `knowledge/email-examples/<category>/` | An email question with Dan's approved answer |
| New Facebook comment example | `knowledge/facebook-examples/comment-replies/` | A Facebook comment reply Dan gave |
| New Facebook DM example | `knowledge/facebook-examples/dm-responses/` | A Facebook DM response Dan gave |
| Resource link | `knowledge/resources/links.md` | New YouTube video, manual, product page URL |
| Policy update | `context/policies.md` | Change to warranty, shipping, payment process |
| Tone/style note (email) | `context/tone.md` | "Never say X, instead say Y" |
| Tone/style note (Facebook) | `context/channels/facebook.md` | "On Facebook we keep it shorter" |
| Website navigation | `context/website-navigation.md` | New category path, search tip |
| Routing rule | `context/business-profile.md` | "Send X type of questions to John" |

**How to determine channel:** If the user mentions Facebook, a comment, a DM, or social media, file under `facebook-examples/`. If they mention email or don't specify a channel, file under `email-examples/`. If unclear, ask: "Is this for email responses or Facebook?"

If the knowledge doesn't fit any existing file, suggest creating a new file and confirm with the user.

---

## Step 3: Check for Duplicates

Before writing, search the target file (and related files) for the topic:
- If an entry already exists for this topic, show it and ask: "There's already an entry for this — update it or add alongside?"
- If a similar but different entry exists, note it so the user can decide

---

## Step 4: Write the Entry

Format the entry to match the style of existing entries in the target file:
- For product rules: use the `## Product Name` heading with bullet points for the rule
- For email examples: follow the format in `.claude/reference/email-qa-format.md` (Customer Question / Response / Category / Notes). Add `Source: /teach — Dan, YYYY-MM-DD` in the Notes section.
- For resources: add to the appropriate section of `links.md`
- For policies: add or update the relevant section

Write the entry to the file.

---

## Step 5: Confirm

Read back what was saved and where:

```
Saved to: [file path]

Entry:
[the entry as written]

This means next time someone asks about [topic], I'll include this in my response.
```

---

## Guardrails

- Always read back the saved entry — never just confirm blindly
- Don't rewrite Dan's phrasing — capture his actual words and style
- If the input is vague ("remember this about tires"), ask for specifics before writing
- Don't modify existing entries without asking — add new entries or ask to update
