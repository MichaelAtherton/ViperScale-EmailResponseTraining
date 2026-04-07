---
name: ingest-catalog
description: Process WooCommerce product catalog export into structured knowledge files. USE WHEN ingest catalog, load products, process product data, import catalog, product CSV, WooCommerce export.
argument-hint: <path to CSV file>
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion
---

# /ingest-catalog

Process a WooCommerce product CSV export into structured product files organized by category.

---

## Step 1: Locate the Source

Read the CSV file path from `$ARGUMENTS`. This is a WooCommerce Products export (Products → Export from WooCommerce admin).

If no path provided, ask where the CSV is.

---

## Step 2: Parse the CSV

Extract for each product:
- **SKU** — unique product identifier
- **Name** — product title
- **Category path** — the full category hierarchy (e.g., "AFX > Magnet Traction > Tires")
- **Price** — regular price
- **Stock status** — in stock, out of stock, on backorder
- **Stock quantity** — if available
- **Description** — product description text
- **Variations** — for variable listings, list all variations with their own SKUs
- **Related/upsell products** — if present in the export

---

## Step 3: Group by Category

Organize products by their top-level car type / category:
- AFX (Magnet Traction, etc.)
- Mega G+
- Production Modified
- Tracks and Accessories
- (other categories as they appear in the data)

---

## Step 4: Write Product Files

Create one markdown file per category in `knowledge/products/`:

```markdown
# [Category Name] — [Subcategory]

Last updated: [date of export]

| SKU | Name | Price | In Stock | Notes |
|-----|------|-------|----------|-------|
| 420 | Rear Tire - Magnet Traction | $X.XX | Yes | |
| 405 | Front End - Magnet Traction | $X.XX | Yes | |
```

For variable listings, show the parent product and its variations:

```markdown
## [Parent Product Name] (Variable)
SKU: [parent SKU]

| Variation | SKU | Price | In Stock |
|-----------|-----|-------|----------|
| Color: Red | 420-R | $X.XX | Yes |
| Color: Blue | 420-B | $X.XX | No |
```

---

## Step 5: Cross-Reference Product Rules

After writing product files, check `knowledge/product-rules/` for:
- Products mentioned in compatibility rules that aren't in the catalog (flag these)
- Catalog products that have no compatibility rules yet (note for Dan to review)

---

## Step 6: Report

```
Loaded: X products across Y categories
Variable listings: Z (with W total SKU variations)
Categories created:
  - [category]: N products
  - [category]: N products

Cross-reference notes:
- [any mismatches between catalog and product rules]

⚠ Stock data is a snapshot from [export date]. For availability-critical answers,
  always say "check current stock on the website."
```

---

## Guardrails

- Stock data is a point-in-time snapshot — always note the export date
- Don't infer compatibility from product names — only state rules that are in `knowledge/product-rules/`
- If the CSV has unexpected columns or format, ask before proceeding
- Preserve exact pricing from the export — don't round or estimate
