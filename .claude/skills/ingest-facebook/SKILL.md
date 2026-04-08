---
name: ingest-facebook
description: Process Facebook comment and DM history into categorized response examples for the knowledge base. USE WHEN ingest facebook, process facebook messages, load facebook replies, import facebook comments, facebook training data.
argument-hint: <paste Facebook conversation, file path, or export>
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion
---

# /ingest-facebook

Process Dan's Facebook comment replies and DM responses in bulk, extracting Q&A pairs and filing them into the Facebook-specific knowledge base.
**Voice:** Use your persona from `.claude/src/assistant-persona.md` when communicating with the user. Keep it conversational — no file paths or system details in user-facing output.

---

## Step 1: Determine the Source

Facebook data can come in several forms. Ask if not clear from `$ARGUMENTS`:

- **Copy-pasted conversations** — user pastes a comment thread or DM exchange directly
- **Screenshot transcriptions** — user describes what's in a screenshot
- **Facebook data export** — JSON files from Facebook's "Download Your Information" tool (Settings → Your Information → Download Your Information → Messages)
- **Batch file** — a text/markdown file with multiple conversations separated by dividers

If the user isn't sure how to get the data, explain:
> "The easiest way is to scroll through your Facebook page and copy-paste conversations that show how you typically respond. Focus on the ones where you gave a good answer — product questions, troubleshooting, recommendations. Even 10-15 examples is enough to get started — we'll learn the rest over time with /teach."

---

## Step 2: Process Each Conversation

For each conversation thread:

1. **Identify the channel type:** public comment or private DM?
2. **Extract the Q&A pair:** customer question/comment → Dan's response
3. **If it's a comment thread with multiple people:** extract Dan's responses to specific questions, not the full thread chatter
4. **If it's a DM conversation with back-and-forth:** extract the core Q&A — what did the customer need, what was the resolution?
5. **Categorize** into the same 6 types as email:
   - product-question, order-issue, warranty-return, stock-availability, pre-sales, setup-support

---

## Step 3: Deduplicate

Same as email ingestion — if the same question type appears many times, keep the 2-3 best examples:
- Most representative of Dan's Facebook tone
- Most complete answer
- Best examples of DM redirect (for public comments that needed to move private)

---

## Step 4: Format Each Q&A Pair

Write each pair to the appropriate directory. Follow the format in `.claude/reference/email-qa-format.md` adapted for Facebook:

### For comment replies → `knowledge/facebook-examples/comment-replies/`

```markdown
# [Brief Description]

## Customer Comment
[The customer's comment — preserve their exact words]

## Context
[Was this on a product post? A Facebook Live? A general page comment? Note if other people were in the thread.]

## Response
[Dan's actual reply — preserve his exact phrasing]

## Category
[product-question / order-issue / warranty-return / stock-availability / pre-sales / setup-support]

## Notes
- [DM redirect used? What was the redirect phrase?]
- [Was someone else giving wrong info that Dan corrected?]
- [Related products, SKUs, or links included]
```

### For DM responses → `knowledge/facebook-examples/dm-responses/`

```markdown
# [Brief Description]

## Customer Message
[The customer's DM — preserve their exact words]

## Response
[Dan's actual DM response — preserve his exact phrasing]

## Category
[category]

## Notes
- [Was this redirected from a public comment?]
- [Related products, SKUs, or links]
- [Resolution: what happened?]
```

**File naming:** descriptive kebab-case slug: `tire-recommendation-afx-comment.md`, `wrong-parts-dm-resolution.md`

---

## Step 5: Extract Facebook-Specific Patterns

While processing, look for patterns unique to Facebook that should be captured in `context/channels/facebook.md`:

- **Dan's actual Facebook phrasing** — how he starts replies, signs off, uses emoji
- **DM redirect patterns** — what phrases he uses to move conversations private
- **Comment length** — how long his typical comment replies are
- **How he handles wrong information** in threads — does he correct directly? Politely redirect?
- **Any Facebook-specific product recommendations** — "I showed this on the Live last week"

Update `context/channels/facebook.md` with any new patterns found.

---

## Step 6: Report

```
Processed: X Facebook conversations
Filed: Y response examples
  Comment replies: N (in knowledge/facebook-examples/comment-replies/)
  DM responses: N (in knowledge/facebook-examples/dm-responses/)
  By category:
    - product-questions: N
    - order-issues: N
    - warranty-returns: N
    - stock-availability: N
    - pre-sales: N
    - setup-support: N
Duplicates removed: Z
DM redirects captured: W
Facebook tone patterns updated: [yes/no]

Flagged for review: [list any conversations where Dan's response was unclear or inconsistent]
```

---

## Guardrails

- Preserve Dan's actual Facebook phrasing — don't rewrite to sound more "professional"
- Skip automated Facebook notifications, ads, and non-customer interactions
- If a thread has trolling or spam, skip it — don't train on those interactions
- Flag conversations where Dan's response contradicts email response patterns (may indicate a policy difference on social vs email)
- If a DM conversation is very long (10+ messages back and forth), extract the key Q&A rather than the full transcript
