---
name: ingest-emails
description: Bulk process email archive into categorized Q&A pairs for the knowledge base. USE WHEN ingest emails, process email archive, load email history, import emails, bulk email processing.
argument-hint: <path to email folder or file>
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion
---

# /ingest-emails

Process Dan's customer email archive in bulk, extracting Q&A pairs and filing them into the knowledge base by category.
**Voice:** Use your persona from `.claude/src/assistant-persona.md` when communicating with the user. Keep it conversational — no file paths or system details in user-facing output.

---

## Step 1: Locate the Source

Read the email source from `$ARGUMENTS`. Accepted formats:
- A folder of `.eml`, `.txt`, or `.md` files
- An `.mbox` file (Gmail export from Google Takeout)
- Pasted email text (for small batches)

If no path is provided, ask where the emails are.

---

## Step 2: Process in Batches

Read emails in batches of 10-20. For each email thread:

1. **Extract the Q&A pair:** customer question → Dan/Abby's response
2. **Skip non-Q&A content:** spam, internal-only emails, automated notifications (order confirmations, shipping alerts, payment receipts)
3. **Categorize** into one of 6 types:
   - product-question
   - order-issue
   - warranty-return
   - stock-availability
   - pre-sales
   - setup-support

---

## Step 3: Deduplicate

If the same question type has been answered many times (e.g., 15 different "what tires fit my AFX?"), keep the 2-3 best examples:
- Most complete answer
- Most representative of Dan's tone
- Most useful for training the AI

---

## Step 4: Format Each Q&A Pair

Write each pair as a markdown file in `knowledge/email-examples/<category>/`. Follow the canonical format in `.claude/reference/email-qa-format.md`:

```markdown
# [Brief Description of Question]

## Customer Question
[The customer's actual email text]

## Response
[Dan or Abby's actual response — preserve their exact words]

## Category
[category name]

## Notes
- [Any context: special circumstances, product details, why this answer was chosen]
- [Related products or rules to cross-reference]
```

**File naming:** Use a descriptive slug: `replacement-sponge-tires-outlaw.md`, `wrong-parts-11200-vs-12000.md`

---

## Step 5: Flag Issues

During processing, flag:
- Emails where Dan's response seems inconsistent with other answers (may indicate policy changed)
- Emails where the response contains information not yet in `knowledge/product-rules/` (extract it)
- Emails that reveal a new product rule or compatibility fact (suggest adding via `/teach`)

---

## Step 6: Report

After processing, report:

```
Processed: X emails total
Filed: Y unique Q&A pairs
  - product-questions: N
  - order-issues: N
  - warranty-returns: N
  - stock-availability: N
  - pre-sales: N
  - setup-support: N
Duplicates removed: Z
Flagged for review: W (list them)
```

---

## Guardrails

- Preserve Dan's actual responses — do NOT rewrite, summarize, or "improve" them
- Skip spam, internal emails, and automated notifications
- Flag inconsistent answers rather than silently choosing one
- If an email thread has multiple Q&A exchanges, extract each as a separate pair
