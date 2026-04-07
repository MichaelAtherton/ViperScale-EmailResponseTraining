---
name: draft-reply
description: Draft customer email replies using the knowledge base and Dan's tone. USE WHEN draft reply, respond to this email, what should I say, customer email, draft a response, answer this email, help me reply.
argument-hint: <paste customer email>
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion
---

# /draft-reply

Draft an accurate, on-brand customer email response by searching the knowledge base for matching product information, past Q&A examples, and relevant policies.

---

## Step 1: Read the Email

Read the customer email from `$ARGUMENTS`. Identify:
- What they're asking about (product name, SKU, car type, chassis, order number)
- How many separate questions are in the email (contact form stacking is common — multiple unrelated topics in one thread)

If the email contains multiple unrelated questions, treat each as a separate draft section.

---

## Step 2: Categorize

Classify the email into one of 6 categories:
- **product-question** — "what tires fit my chassis?", "where can I find X?"
- **order-issue** — wrong parts, payment failure, order modification
- **warranty-return** — defect report, item not working, return request
- **stock-availability** — "do you carry X?", "is X in stock?", "I can't find X on your site"
- **pre-sales** — new customer, track inquiry, wants to talk before buying
- **setup-support** — timing system setup, software issues, assembly questions

---

## Step 3: Extract Key Entities

Pull out specific terms to search for:
- Product names and SKUs
- Car types and chassis references (AFX, Magnet Traction, Mega G+, etc.)
- Order numbers (if mentioned)
- Specific issues (wrong parts, slow car, tire compatibility)

---

## Step 4: Search the Knowledge Base

Search in this order. Stop and note what you find at each step:

1. **`knowledge/product-rules/`** — search for product compatibility, chassis info, discontinued items
2. **`knowledge/products/`** — search for specific SKUs, pricing, stock status
3. **`knowledge/email-examples/<category>/`** — search for similar past Q&A pairs in the matching category
4. **`knowledge/resources/links.md`** — find relevant URLs to include (product pages, YouTube videos, manuals)
5. **`context/policies.md`** — check for applicable policies (warranty, shipping, returns, payment)

Record which files you referenced. You'll report these.

---

## Step 5: Check Routing

Before drafting, check if this email should be routed:
- **Track sales or inquiries over $500** → "This looks like a track sale — Dan should handle this personally."
- **Drag racing questions** → "This is a drag racing question — route to John."
- **Complex technical questions with no knowledge base match** → "This needs Dan's expertise — I don't have enough product knowledge to answer accurately."

If routing is needed, still draft a holding response (acknowledge receipt, provide any relevant links) and flag the routing.

---

## Step 6: Draft the Response

Read `context/tone.md` before writing.

Draft the response following these rules:
- Match Dan's tone: direct, knowledgeable, efficient. No AI-speak.
- Include direct product links where you found them — never say "check our website"
- If you found a past Q&A example that matches, use Dan's actual phrasing as a guide
- If the product isn't in the knowledge base, say so explicitly — never make up product information
- For stock questions, note that stock data may not be current: "You can check current availability on the product page"
- For warranty/returns, follow the return-for-inspection flow — never promise a specific outcome
- For multi-topic emails, address each topic with a clear separator

---

## Step 7: Assess Confidence

Rate your confidence:
- **HIGH** — found matching Q&A examples, product rules confirmed, links verified
- **MEDIUM** — partial match, reasonable answer but Dan should review closely
- **LOW** — no matching knowledge, educated guess, or the question involves products/rules not in the vault

---

## Step 8: Output

Present the draft in this format:

```
Category: [product-question / order-issue / warranty-return / stock-availability / pre-sales / setup-support]
Confidence: [HIGH / MEDIUM / LOW]
Knowledge used: [list the files that were referenced]

---

Draft response:

[the actual email draft]

---

Notes for reviewer: [anything you're unsure about, products you couldn't verify, suggestions, routing recommendations]
```

---

## Guardrails

- NEVER fabricate product information — if a SKU isn't in the knowledge base, flag it
- NEVER make up pricing or availability
- NEVER promise a specific warranty resolution before inspection
- NEVER provide support for third-party software/OS issues — link to external resources
- If the email should go to a specific person (John for drag racing, Dan for track sales), say so
- Don't pad responses with filler — Dan's style is helpful but efficient
