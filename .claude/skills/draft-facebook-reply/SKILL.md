---
name: draft-facebook-reply
description: Draft Facebook comment replies and DM responses using the knowledge base and Dan's social media tone. USE WHEN facebook reply, respond to this comment, facebook message, DM response, social media reply, reply to this post, facebook comment.
argument-hint: <paste Facebook comment or DM>
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion
---

# /draft-facebook-reply

Draft an accurate, on-brand Facebook response — either a public comment reply or a private DM — by searching the knowledge base and following Facebook-specific tone guidelines.

---

## Step 1: Read the Message

Read the Facebook comment or DM from `$ARGUMENTS`. Determine:
- **Channel type:** public comment or private DM?
- **Context:** is this a comment on a product post, a Facebook Live, a general page comment, or a Messenger conversation?
- What they're asking about (product, order, support, general question)
- If it's a comment, is there a thread? Are other people involved in the conversation?

If the channel type isn't clear, ask: "Is this a public comment or a private DM?"

---

## Step 2: Categorize

Same categories as email — the customer problem doesn't change by channel:
- **product-question** — compatibility, recommendations, "what fits my car?"
- **order-issue** — wrong parts, payment failure, order modification
- **warranty-return** — defect report, item not working
- **stock-availability** — "do you carry X?", "is X in stock?"
- **pre-sales** — track inquiry, new customer, wants advice
- **setup-support** — timing system, software, assembly

---

## Step 3: Search the Knowledge Base

Search the SAME knowledge base as email — product knowledge is shared:

1. **`knowledge/product-rules/`** — compatibility, chassis info, discontinued items
2. **`knowledge/products/`** — specific SKUs, pricing, stock status
3. **`knowledge/facebook-examples/`** — similar past Facebook Q&A pairs (check comment-replies/ or dm-responses/ based on channel type)
4. **`knowledge/email-examples/`** — ALSO check email examples. The answer content is the same; only the format changes for Facebook.
5. **`knowledge/resources/links.md`** — relevant URLs to include
6. **`context/policies.md`** — applicable policies

Record which files you referenced.

---

## Step 4: Check Routing and DM Redirect

### For public comments:
Before drafting, check if this question should move to DM:
- **Order details needed** (order number, shipping address, payment info) → redirect to DM
- **Warranty/return discussion** → redirect to DM
- **Payment issues** → redirect to DM
- **Anything with personal/account info** → redirect to DM

If redirect needed, draft a short public reply that moves the conversation:
> "Hey [name], shoot us a DM with your order details and we'll get that sorted out for you"

### For DMs:
Check standard routing:
- **Track sales over $500** → "Let me have Dan reach out to you directly on this"
- **Drag racing** → "John handles our drag racing — I'll pass this to him"

---

## Step 5: Draft the Response

Read `context/channels/facebook.md` AND `context/tone.md` before writing.

### For public comment replies:
- **1-3 sentences max** — short, helpful, direct
- Include product names or direct links when relevant (links work on Facebook)
- Casual but knowledgeable — like talking to someone at the hobby shop
- Emoji sparingly — Dan's style, not corporate social
- If someone gave wrong advice in the thread, provide correct info without calling them out
- Never include: order numbers, pricing disputes, warranty specifics, personal info

### For DM responses:
- **2-5 sentences** — more detail than a comment, but still more casual than email
- Can include SKUs, direct links, order-specific info
- Same knowledge base, same product answers — just adjusted tone and length
- Can handle complex product questions with more detail than a comment

---

## Step 6: Assess Confidence

Same as email:
- **HIGH** — found matching examples, product rules confirmed
- **MEDIUM** — partial match, review closely
- **LOW** — no matching knowledge, needs Dan's input

---

## Step 7: Output

```
Platform: Facebook [comment / DM]
Category: [category]
Confidence: [HIGH / MEDIUM / LOW]
Knowledge used: [files referenced]

---

Draft response:

[the response]

---

Notes for reviewer: [anything you're unsure about, DM redirect recommendation, routing]
```

---

## Guardrails

- **NEVER include personal/order info in public comment replies** — redirect to DM
- **NEVER fabricate product information** — same rule as email
- **NEVER engage in public arguments** — if someone is wrong, provide correct info calmly
- **NEVER use corporate AI-speak** — "Thank you for reaching out!" is banned
- **NEVER discuss pricing disputes in public comments**
- **Keep comment replies SHORT** — if your draft is more than 3 sentences for a comment, it's too long. Move detail to DM.
- Don't pad with fluff — Dan's social style is the same as his email style, just shorter
