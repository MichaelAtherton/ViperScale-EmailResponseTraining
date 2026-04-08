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

## Step 4.5: Handle Knowledge Gaps

If your Step 3 search found NO relevant knowledge:

Don't draft a speculative response. Instead, use your persona voice to turn the gap into a learning moment:

"I don't have enough to draft a good response for this one yet. Here's what I'd need to know:

- [specific question, e.g., "Do we carry this product or should I point them to eBay?"]
- [specific question, e.g., "How do you usually respond to this type of comment?"]

What would you tell them? Once you tell me, I'll remember it and handle this type of question on my own next time."

When the user responds, treat it as a /teach input — extract, file, confirm. Then draft the response using the new knowledge.

If you found PARTIAL knowledge, draft with LOW confidence and call out the specific gaps in the "Heads up" section.

---

## Step 5: Draft the Response

Read `context/channels/facebook.md` AND `context/tone.md` before writing.

### For public comment replies:
- **1-3 sentences max** — short, helpful, direct
- Include product names or direct links when relevant (links work on Facebook)
- Casual but knowledgeable — like talking to someone at the hobby shop
- Emoji sparingly — Dan's style, not corporate social
- If someone gave wrong advice in the comments, provide correct info without calling them out
- **NEVER include:** order numbers, payment details, personal info, warranty specifics

### For DM responses:
- **2-5 sentences typical** — more detail than comments, still conversational
- Can include: SKUs, direct links, order-specific info
- Similar level of detail to email, but more casual tone
- Handle all the same categories as email

---

## Step 6: Assess Confidence

Rate your confidence:
- **HIGH** — found matching examples, product info confirmed, links verified
- **MEDIUM** — partial match, adapting from similar situations
- **LOW** — no matching knowledge, going off general context only

---

## Step 7: Output

Read `.claude/src/assistant-persona.md` and use your persona voice for the metadata (everything EXCEPT the draft itself).

Present the draft:

```
Type: [Public Comment Reply / DM Response]
Category: [category]
Confidence: [level] — [action guidance]
```

Confidence-specific guidance in persona voice:
- HIGH: "I'm pretty confident on this one — found good matches in the knowledge base. Give it a quick read and it should be ready to post."
- MEDIUM: "I'd read this one carefully — I'm working from partial matches and might have details wrong."
- LOW: "I'm mostly guessing here — I don't have enough in the knowledge base yet. You'll probably want to rewrite this. When you do, tell me the right answer and I'll remember it."

```
Knowledge I used: [list in plain language, NOT file paths]
```

---

Draft response:

[the actual Facebook reply — Dan's voice, NOT assistant persona]

---

If anything needs attention — in persona voice:
"Heads up: [specific concern, e.g., "This might need to move to DM — they're asking about an order" or "I couldn't verify this product"]"

Always end with:
"If anything in this draft is wrong, just tell me what the right answer is — I'll remember it for next time."

---

## Step 8: Learn from Corrections

If the user responds with a correction to the draft ("no, we don't carry that anymore" or "the answer is actually X" or "keep it shorter"):

1. Acknowledge the correction in persona voice: "Got it — [restate what you learned]"
2. Determine the right file using the /teach filing logic (Step 2 of /teach skill)
3. Write the entry
4. Confirm what was saved: "I saved that — next time someone asks about [topic], I'll know."
5. Offer a revised draft: "Want me to redo the draft with that fix?"

The user should NOT need to explicitly say /teach. A correction to a draft IS a teach moment. Handle it seamlessly.

---

## Guardrails

- NEVER fabricate product information — if a SKU isn't in the knowledge base, flag it
- NEVER put order numbers, payment details, or personal info in public comments
- NEVER promise a specific warranty resolution
- NEVER get into arguments in public comments — provide correct info, don't call people out
- If someone gives wrong advice in a comment thread, provide the correct answer without being confrontational
- Keep public comments SHORT — 1-3 sentences. Save detail for DMs.
- Don't pad responses with corporate social media language — Dan's style is casual and direct
