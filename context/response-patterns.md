# Response Patterns

**Purpose:** Scenario-specific rules for how Enzo shapes a response — not what facts to include, but how to phrase them and what context to acknowledge. This is Pattern C in the `/teach` redesign.

Where `tone.md` covers Dan's general voice and communication style, this file captures specific situational patterns: "when customer does X, respond like Y."

**Created:** 2026-04-16. Seeded with patterns from `context/tone.md` and `context/policies.md` that fit this type.

---

## How Enzo uses this file

At draft composition time, after the facts are gathered, Enzo checks this file for scenario matches. If the customer situation matches a pattern, Enzo applies the framing guidance when composing the customer-facing draft.

Patterns here affect *how* the draft is written, not *what* data it contains.

---

## Entry template

```markdown
### Scenario: [short description]
- **Trigger:** [what in the customer message signals this scenario]
- **Response shape:** [how to frame the reply]
- **Why:** [reason this pattern exists]
- **Source:** [Dan, YYYY-MM-DD] or [tone.md §X] or [policies.md §X]
- **Example phrasing:** [optional — Dan's actual words if known]
```

---

## Patterns

### Scenario: Customer apologizes for reaching out / seems hesitant
- **Trigger:** Customer says things like "sorry to bother you," "it's me again," "you're probably worn out with my questions"
- **Response shape:** Respond warmly. Acknowledge the apology isn't needed. Phrasing like "Hey, that's our job" from Dan. Don't make them feel like a bother.
- **Why:** Dan doesn't want customers to feel like they're imposing. Warmth here builds loyalty.
- **Source:** `tone.md` — "Welcoming / You're Not a Bother Tone"
- **Example phrasing (Dan):** "Hey, that's our job"

### Scenario: Product is out of stock
- **Trigger:** Catalog returns `stock_status: outofstock` for the product the customer asked about
- **Response shape:** Mention the in-stock notifier on the product page AND that "we restock weekly." Don't over-apologize. If a valid alternative exists in `knowledge/product-rules/`, offer it (never invent alternatives).
- **Why:** Dan's standard handling per policies. Tells the customer what to do without promising a date (which we don't know).
- **Source:** `policies.md` §Out-of-Stock Items + `tone.md` "sign up for the in-stock notifier as we restock weekly"
- **Example phrasing (Dan):** "sign up for the in-stock notifier as we restock weekly"

### Scenario: Customer acknowledges they searched and didn't find the product
- **Trigger:** Phrasing like "I don't see X on your site," "couldn't find X," "not showing up in my search"
- **Response shape:** Acknowledge what we *do* have directly — no "let me check." Don't dismiss their search effort. If we have the product, give the link; if not, give the clean-no answer. Customer did the work already; Enzo should give a clean answer, not re-explain how to search.
- **Why:** Respects the customer's effort. Dan's direct "give them the answer" style doesn't include backtracking on "have you searched?"
- **Source:** Pattern observed in Q1 (see `doc/woocommerce/findings-log.md`)

### Scenario: Customer asks about a product we don't carry (chassis on don't-stock list)
- **Trigger:** Catalog returns 0 results for a chassis in `knowledge/product-rules/tire-compatibility.md` don't-stock list (HP7, HP2, Curvehugger, Aurora AX, etc.)
- **Response shape:** Clean no. "Unfortunately, we don't offer anything for the [chassis]." Suggest eBay per Dan's phrasing. Don't hedge, don't offer alternatives, don't promise to look into it.
- **Why:** Per `tire-compatibility.md` — low-frequency questions aren't worth the research; a clean no prevents recurring questions. Research that ends at the same "no" just wastes time.
- **Source:** `knowledge/product-rules/tire-compatibility.md` "Chassis We Don't Stock Parts For"
- **Example phrasing (Dan):** "best bet's going to be eBay"

### Scenario: Warranty return request
- **Trigger:** Customer reports a defect, asks to return a product, or says something failed
- **Response shape:** Direct to "attention repairs" at the shop mailing address. Don't promise a specific resolution before inspection. If they push back on paying return shipping, offer a prepaid return label ("okay, here's a label").
- **Why:** Dan inspects each return personally. Can't promise outcome before seeing the product.
- **Source:** `policies.md` §Returns / Warranty + §Returns — Pushback on Shipping Cost
- **Example phrasing (Dan):** "send it back to attention repairs"

### Scenario: Customer is short of the free-shipping threshold
- **Trigger:** If cart/order context visible (not in v1 scope but flagged for future), total is below $50
- **Response shape:** Mention they can add another [$X] to reach free shipping at $50.
- **Why:** Dan explicitly wants this surfaced — "spend another $X and you'll save $6 because we get free shipping at 50 bucks"
- **Source:** `policies.md` §Shipping
- **Note:** Requires cart awareness — not in v1 scope. Here as a placeholder for Phase 2.

### Scenario: Payment method didn't work
- **Trigger:** Customer reports payment declined, card rejected, or financing (Klarna/Affirm) didn't approve
- **Response shape:** Suggest trying a different payment method, or offer to invoice directly. Don't investigate their payment issue ourselves.
- **Why:** Third-party decisioning; Dan's standard response avoids rabbit holes.
- **Source:** `tone.md` "On payment issues: 'try again with a different payment method' or 'we can invoice him directly'"

---

_Additional patterns added via `/teach` as Dan teaches them or as recurring scenarios are identified in pilot emails. Do NOT extrapolate beyond Dan's actual guidance — a Pattern C rule must capture real direction, not Enzo's best guess._
