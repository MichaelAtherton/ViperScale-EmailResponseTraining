---
name: onboard
description: Conversational onboarding — populate the vault with your business context, product knowledge, and response examples through a guided interview. USE WHEN onboard, set up, get started, populate vault, configure, initialize, first time setup.
argument-hint: (no arguments — starts an interactive conversation)
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion
---

# /onboard

Walk the client through populating their vault via a guided conversation. No forms, no field names — just questions. The skill sorts answers into the right files.

> **This skill is designed to be run once during initial setup, with the client (or someone who knows the business) present.** It can be re-run to fill gaps or update information.

---

## Before Starting

1. Check what's already populated by reading `context/business-profile.md`, `context/tone.md`, `context/policies.md`, and `context/channels/facebook.md`
2. If files already have content (not just templates), note what's filled and skip those questions
3. Tell the client what to expect:

> "I'm going to ask you about your business, how you talk to customers, and what your customers typically ask about. This usually takes 30-60 minutes. I'll be saving everything as I go, so we can stop anytime and pick up later. Ready?"

---

## Section 1: Your Business

**Goal:** Populate `context/business-profile.md`

Ask conversationally — one question at a time, not a list:

- "What does your company do? What do you sell?"
- "What's your website?"
- "Who's on the team? Who handles customer service? Who handles [specific area they mention]?"
- "Where do customer messages come in? Email? Facebook? Both?"
- "Roughly how many customer messages do you deal with per day or week?"
- "What's the email address customers write to?"

**Write `context/business-profile.md` when this section is done** — not after each individual answer. Collect the full picture first, then write one coherent file. This keeps commits clean (one commit per section, not per question).

**Also write** the routing rules section based on who handles what.

---

## Section 2: How You Talk

**Goal:** Populate `context/tone.md` and `context/channels/facebook.md`

- "How would you describe your style when responding to customers?"
- "What do you want to sound like? What do you NOT want to sound like?"
- "Can you paste me 2-3 real email responses you've sent recently that sound like you?" (if they have them handy)
- "Do you respond differently on Facebook than in email? How?"
- "Any words or phrases you use a lot? Anything you never say?"

**Write when section is done:**
- `context/tone.md` — shared brand voice
- `context/channels/facebook.md` — update the tone section and "Dan's Actual Facebook Phrasing" section with any Facebook-specific differences and real examples

If they pasted real responses, save the best ones as examples in `knowledge/email-examples/` or `knowledge/facebook-examples/` depending on the channel.

---

## Section 3: The Rules

**Goal:** Populate `context/policies.md`

- "What's your shipping policy? Free shipping threshold?"
- "What happens when someone wants to return something or thinks they got a defective product?"
- "What payment methods do you accept? What do you tell someone when their payment fails?"
- "Is there anything you DON'T help with? Like, things that are someone else's problem?"
- "Any current promotions, sales, or special offers I should know about?"
- "Anything customers should NEVER be told? Any sensitive topics?"

**Write `context/policies.md` when this section is done.**

---

## Section 4: What Customers Ask About

**Goal:** Populate `knowledge/` — product rules, response examples, resource links

This is the most important section. The approach: **get the client talking about real customer interactions.**

Start with: "What are the most common questions you get from customers? Let's go through the top ones."

For each question type they describe:
1. "What's the question?"
2. "What do you usually tell them?"
3. "Are there specific products, links, or SKUs involved?"
4. "Does this come up a lot?"

**As they talk, write each answer to the appropriate file:**
- Product compatibility rules → `knowledge/product-rules/`
- Specific Q&A examples → `knowledge/email-examples/<category>/` or `knowledge/facebook-examples/`
- Resource links (YouTube, manuals, support pages) → `knowledge/resources/links.md`
- Products you don't carry → `knowledge/product-rules/discontinued-alternatives.md`
- Special-order items → `knowledge/product-rules/special-order-items.md`

**Follow the format in** `.claude/reference/email-qa-format.md` for Q&A pairs.

**Aim for 10-15 Q&A pairs in the first session** across the major categories. Don't try to capture everything — `/teach` handles ongoing learning after onboarding, and the ingestion skills can process bulk data later. Getting 10 solid examples with Dan's real phrasing is more valuable than 30 rushed ones.

After the conversational capture, ask about bulk data sources:

- "Do you have an email archive we could process? Like a Gmail export or a folder of past emails?" → explain how `/ingest-emails` works
- "Could you scroll through your Facebook page and copy-paste some of your best comment replies and DM conversations?" → explain how `/ingest-facebook` works
- "Do you have a product catalog export from your website? Like a CSV from WooCommerce or Shopify?" → explain how `/ingest-catalog` works
- "What's your website URL? I can crawl it to grab your product categories and any videos or manuals on your product pages." → explain how `/ingest-site` works

**Run any ingestion skills the client wants to do now.** Don't force all of them — some can happen later.

---

## Section 5: Website Navigation

**Goal:** Populate `context/website-navigation.md`

- "When a customer asks where to find a product, how do you tell them to navigate your website?"
- "What's the main way people browse? By category? By search? By product type?"
- "Does your site search work well, or do customers have trouble finding things?"
- "Are there any tricky navigation paths customers get confused by?"

If the client provided a website URL in Section 1, offer to run `/ingest-site` to auto-populate the navigation structure and resource links.

**Write `context/website-navigation.md` when this section is done.**

---

## Section 6: Let's Test It

**Goal:** Validate the knowledge base works. Build confidence.

> "Let's try it out. Paste me a real customer email or Facebook message — something from today or this week — and I'll draft a response using everything you just taught me."

Run `/draft-reply` (for email) or `/draft-facebook-reply` (for Facebook) against the knowledge base.

Present the draft to the client. Then:

- **If it's good:** "Great — the knowledge base is working. Let's try another one."
- **If it's wrong:** "What should the answer be?" → capture the correction via `/teach` immediately. Then re-draft to show it learned.
- **If it's missing info:** "I don't have enough information to answer this one. What would you tell them?" → capture via `/teach`.

**Repeat 3-5 times** across different question types. Each correction makes the vault smarter.

---

## Section 7: Wrap Up

After testing, summarize what was captured:

```
Onboarding complete! Here's what we set up:

Business profile: ✓ [company name, team, channels]
Tone & style: ✓ [email + Facebook]
Policies: ✓ [shipping, returns, payment, boundaries]
Product knowledge: X rules captured
Response examples: Y email examples, Z Facebook examples
Resource links: W links captured
Website navigation: [populated / needs site crawl]

What's still needed:
- [list any gaps identified during testing]
- [suggest running specific ingestion skills for bulk data]
- [remind about /teach for ongoing learning]

You're ready to start using /draft-reply and /draft-facebook-reply
for real customer messages. Every time you correct a draft or teach
me something new with /teach, the system gets smarter.
```

---

## Resuming a Partial Onboard

If the client needs to stop partway through:
- Everything written so far is saved (auto-committed by hooks)
- Running `/onboard` again will check what's populated and skip completed sections
- The client can jump to any section: "Let's do Section 4" or "I have Facebook examples now"

---

## What This Skill Does NOT Do

- Modify skills, hooks, or vault structure — it only populates content files
- Auto-send any customer responses — everything is draft for review
- Replace ingestion skills — it guides the client to them but doesn't duplicate their logic
- Require all sections to be completed — partial onboarding is fine, /teach fills gaps over time
