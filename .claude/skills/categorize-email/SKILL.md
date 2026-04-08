---
name: categorize-email
description: Classify and triage incoming customer emails by type, routing, and urgency. USE WHEN categorize this email, what type of email is this, triage this, sort this email, classify email.
argument-hint: <paste customer email>
allowed-tools: Read, Glob, Grep
---

# /categorize-email

Classify an incoming customer email to speed up triage for Abby and Dan.
**Voice:** Use your persona from `.claude/src/assistant-persona.md` when communicating with the user. Keep it conversational — no file paths or system details in user-facing output.

---

## Step 1: Read the Email

Read the customer email from `$ARGUMENTS`. If the email contains multiple unrelated questions (common with the contact form stacking issue), classify each separately.

---

## Step 2: Classify Category

Assign one of 6 categories:

| Category | Signals |
|----------|---------|
| **product-question** | Asks about compatibility, recommendations, "what fits my chassis", product specs |
| **order-issue** | Wrong parts received, payment failure, order modification, cancellation |
| **warranty-return** | Item not working, defect report, "car slowed down", wants to return |
| **stock-availability** | "Do you carry X?", "Is X in stock?", "Can't find X on site" |
| **pre-sales** | New customer, track inquiry, "I saw you on Facebook", wants to talk before buying |
| **setup-support** | Timing system setup, software issues, assembly help, "how do I set up" |

If unclear, pick the closest match and note the ambiguity.

---

## Step 3: Determine Routing

| Route to | When |
|----------|------|
| **Abby** | Standard response available in knowledge base, routine question |
| **Dan** | Track sales over $500, complex product questions not in knowledge base, warranty decisions, anything Abby flags as uncertain |
| **John** | Drag racing questions, drag racing product compatibility |
| **Auto-response possible** | Simple link-to-product questions where we have the URL |

---

## Step 4: Assess Urgency

| Level | Criteria |
|-------|----------|
| **HIGH** | Customer is ready to buy and waiting on an answer. Track inquiries. Payment issues blocking an order. |
| **MEDIUM** | General product question, standard support request. Customer will wait a reasonable time. |
| **LOW** | Informational only, no purchase intent, FYI messages, already resolved. |

---

## Step 5: Output

```
Category: [category]
Route to: [person] ([reason])
Urgency: [HIGH / MEDIUM / LOW] — [brief explanation]
```

For multi-topic emails:

```
Topic 1: [brief description]
  Category: [category]
  Route to: [person]
  Urgency: [level]

Topic 2: [brief description]
  Category: [category]
  Route to: [person]
  Urgency: [level]
```
