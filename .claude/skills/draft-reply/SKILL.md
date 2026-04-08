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

Record which files you referenced. You'll report these in plain language.

---

## Step 5: Check Routing

Before drafting, check if this email should be routed:
- **Track sales or inquiries over $500** → "This looks like a track sale — Dan should handle this personally."
- **Drag racing questions** → "This is a drag racing question — route to John."
- **Complex technical questions with no knowledge base match** → "This needs Dan's expertise — I don't have enough product knowledge to answer accurately."

If routing is needed, still draft a holding response (acknowledge receipt, provide any relevant links) and flag the routing.

---

## Step 5.5: Handle Knowledge Gaps

If your Step 4 search found NO relevant knowledge:

Don't draft a speculative response. Instead, use your persona voice to turn the gap into a learning moment:

"I don't have enough to draft a good response for this one yet. Here's what I'd need to know:

- [specific question, e.g., "Do we carry the XYZ chassis parts, or should I send them to eBay?"]
- [specific question, e.g., "What's the compatible tire for this car type?"]

What would you tell this customer? Once you tell me, I'll remember it and handle this type of question on my own next time."

When the user responds, treat it as a /teach input — extract, file, confirm. Then draft the response using the new knowledge.

If you found PARTIAL knowledge, draft with LOW confidence and call out the specific gaps in the "Heads up" section.

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

Read `.claude/src/assistant-persona.md` and use your persona voice for the metadata (everything EXCEPT the draft itself).

Present the draft:

```
Category: [category]
Confidence: [level] — [action guidance]
```

Confidence-specific guidance in persona voice:
- HIGH: "I'm pretty confident on this one — found good matches in the knowledge base. Give it a quick read and it should be ready to send."
- MEDIUM: "I'd read this one carefully — I'm working from partial matches and might have details wrong."
- LOW: "I'm mostly guessing here — I don't have enough in the knowledge base yet. You'll probably want to rewrite this. When you do, tell me the right answer and I'll remember it."

```
Knowledge I used: [list in plain language — e.g., "tire compatibility rules, Magnet Traction standard response" NOT file paths]
```

---

Draft response:

[the actual email draft — Dan's voice, NOT assistant persona]

---

If anything needs Dan's attention — in persona voice:
"Heads up: [specific concern, e.g., "I couldn't find this SKU in the product catalog" or "This might be a track sale — you usually handle those personally"]"

Always end with:
"If anything in this draft is wrong, just tell me what the right answer is — I'll remember it for next time."

---

## Step 9: Learn from Corrections

If the user responds with a correction to the draft ("no, we don't carry that anymore" or "the answer is actually X" or "say it more like this"):

1. Acknowledge the correction in persona voice: "Got it — [restate what you learned]"
2. Determine the right file using the /teach filing logic (Step 2 of /teach skill)
3. Write the entry
4. Confirm what was saved: "I saved that — next time someone asks about [topic], I'll know."
5. Offer a revised draft: "Want me to redo the draft with that fix?"

The user should NOT need to explicitly say /teach. A correction to a draft IS a teach moment. Handle it seamlessly.

---

## Guardrails

- NEVER fabricate product information — if a SKU isn't in the knowledge base, flag it
- NEVER make up pricing or availability
- NEVER promise a specific warranty resolution before inspection
- NEVER provide support for third-party software/OS issues — link to external resources
- If the email should go to a specific person (John for drag racing, Dan for track sales), say so
- Don't pad responses with filler — Dan's style is helpful but efficient
