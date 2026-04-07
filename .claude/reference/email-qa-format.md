# Email Q&A Pair Format

Use this format when creating files in `knowledge/email-examples/`. Skills `/teach` and `/ingest-emails` should produce output matching this structure.

## File Naming

Use a descriptive kebab-case slug: `replacement-sponge-tires-outlaw.md`, `wrong-parts-11200-vs-12000.md`, `payment-failure-klarna.md`

## Template

```markdown
# [Brief Description of the Question]

## Customer Question
[The customer's actual email text — preserve their exact words, including misspellings]

## Response
[Dan or Abby's actual response — preserve their exact phrasing.
If this is a new /teach entry rather than a real email, write the
response in Dan's tone following context/tone.md guidelines.]

## Category
[One of: product-question, order-issue, warranty-return, stock-availability, pre-sales, setup-support]

## Notes
- [Any context: special circumstances, product details, why this answer was chosen]
- [Related products, SKUs, or rules to cross-reference]
- [If this was a /teach entry, note: "Source: /teach — Dan, YYYY-MM-DD"]
```

## Guidelines

- **Preserve exact phrasing** — don't clean up or rewrite Dan's responses
- **One Q&A pair per file** — if an email thread has multiple exchanges, split them
- **Include context in Notes** — this helps the AI understand WHY this answer was given, not just WHAT it is
- **Category must match folder** — a file in `email-examples/order-issues/` must have `Category: order-issue`
- **Flag uncertainty** — if the response might be outdated or situation-specific, note it
