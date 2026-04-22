---
name: response-format
description: When a message starts with [ENZO-CHAT], return a structured JSON response envelope for the browser chat UI. Activated only for chat UI requests — terminal users are not affected.
---

# Response Format for Enzo Chat UI

When a user message starts with `[ENZO-CHAT]`, you MUST respond with a JSON object. Do NOT include any text outside the JSON. Do NOT wrap it in markdown code fences. Return ONLY the raw JSON object.

## Format

```json
{
  "text": "Your natural language response. When mentioning a product you looked up, write its name inside curly braces like {Product Name}. These become clickable links in the UI.",
  "refs": [
    {
      "kind": "product",
      "name": "Product Name",
      "sku": "SKU-123",
      "price": 29.95,
      "stock": "In Stock",
      "url": "https://viperscaleracing.com/product/product-slug"
    }
  ],
  "stats": [
    {
      "label": "Metric Name",
      "value": "$1,234",
      "sub": "+12% vs prior",
      "tone": "good"
    }
  ]
}
```

## Rules

- **Always return valid JSON.** Close all braces and brackets.
- `text` is required. Write naturally in Enzo's voice — helpful, direct, knowledgeable.
- `refs` is optional. Include ONLY when you looked up real products via `bash scripts/wc.sh`. Never invent product data — every ref must come from an actual WooCommerce API result.
- `refs[].kind` can be: `"product"`, `"order"`, or `"link"`.
- For orders: `{ "kind": "order", "id": "VSR-12345", "customer": "Name", "items": "2 items", "total": 142.45, "date": "Apr 19", "status": "Shipped", "url": "https://viperscaleracing.com/admin/orders/VSR-12345" }`
- For general links: `{ "kind": "link", "name": "Link Text", "url": "https://..." }`
- `stats` is optional. Include ONLY for business/sales queries with real numbers.
- `stats[].tone`: `"good"` (green), `"bad"` (red), or omit for neutral.
- `{Product Name}` tokens in `text` MUST match a `refs[]` entry's `name` field exactly.
- If you cannot look up a product (e.g. wc.sh fails), respond with `text` only — no `refs`. The UI handles this gracefully.

## When NOT to use this format

- If the message does NOT start with `[ENZO-CHAT]`, respond normally (plain text).
- Terminal users never send `[ENZO-CHAT]`.
