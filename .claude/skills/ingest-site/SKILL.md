---
name: ingest-site
description: Crawl viperscaleracing.com to extract navigation structure, product descriptions, and resource links. USE WHEN ingest site, crawl website, load site data, map website, website navigation.
argument-hint: <base URL or "crawl all categories">
allowed-tools: Read, Glob, Grep, Write, Fetch, AskUserQuestion
---

# /ingest-site

Crawl key pages of viperscaleracing.com to map the category navigation tree, extract resource links, and document the product listing structure.

---

## Step 1: Determine Scope

From `$ARGUMENTS`, determine what to crawl:
- **"crawl all categories"** or no argument → start from homepage, map full category tree
- **Specific URL** → crawl that page and its children
- **"resources only"** → focus on finding YouTube videos, PDFs, manuals, support links

Base URL: `https://viperscaleracing.com`

---

## Step 2: Map the Category Navigation Tree

Start at the homepage. Find the "Shop by Car Type" menu (or equivalent main navigation).

For each car type, map the subcategory tree:

```
Shop by Car Type
└── AFX
    ├── Magnet Traction
    │   ├── Tires → viperscaleracing.com/product-category/afx/magnet-traction/tires/
    │   ├── Armatures → viperscaleracing.com/...
    │   └── (other subcategories)
    └── (other AFX variants)
└── Mega G+
    └── ...
```

Record the full URL for each category page.

---

## Step 3: Document Product Listing Anatomy

Visit 3-5 representative product pages. Note:
- What information is on a typical listing (title, price, description, related products, stock status)
- Where the "in-stock notifier" button appears
- Whether setup videos or manuals are embedded in the listing
- How variations are displayed (dropdowns, swatches, etc.)

Write a summary of the listing structure to help the AI know what customers see when they visit a product page.

---

## Step 4: Extract Resource Links

As you crawl, collect:
- **YouTube video embeds** — product assembly, track setup, feature demos
- **Downloadable PDFs** — manuals, guides, spec sheets
- **External support links** — software downloads, vendor support pages
- **Key product category URLs** — the most-linked-to category pages

---

## Step 5: Write Output Files

**`context/website-navigation.md`** — the full category tree with URLs and notes about search behavior:

```markdown
# Website Navigation — viperscaleracing.com

## How to Find Products
The primary navigation is "Shop by Car Type" — select a chassis type, then browse subcategories.
The site search is limited — category browsing is more reliable for finding products.

## Category Tree
[full tree from Step 2]

## Product Listing Anatomy
[summary from Step 3]
```

**`knowledge/resources/links.md`** — all resource links organized by type:

```markdown
# Resource Links

## YouTube Videos
- [Video Title](URL) — what it covers

## Manuals & Downloads
- [Document Name](URL) — for which product

## Product Category Quick Links
- [Category Name](URL)

## External Support
- [Service Name](URL) — when to link customers here
```

---

## Step 6: Report

```
Crawled: X pages
Category paths mapped: Y
Resource links found: Z
  - YouTube videos: N
  - Manuals/PDFs: N
  - External support: N
  - Product category pages: N

Files written:
  - context/website-navigation.md
  - knowledge/resources/links.md
```

---

## Guardrails

- This skill READS ONLY — never modifies the website
- Don't scrape customer data, admin pages, or checkout flows
- If the site structure seems different than expected, ask before continuing
- Note any broken links or 404s encountered
