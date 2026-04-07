# Inventory & Catalog Structure

Source: Discovery call with Dan, 2026-04-06

## Platform
- **WooCommerce** (WordPress-based)
- Backend accessible at WooCommerce admin → Products

## Catalog Size
- **693 line items** in the product database
- Some are **variable listings** with multiple SKUs/variations inside (actual SKU count is higher than 693)
- Some listings are auction items

## Product Listing Types
- **Single SKU listings** — one product, one stock quantity shown directly
- **Variable listings** — multiple SKUs inside one listing, each with:
  - Individual SKU number
  - Enabled/disabled toggle
  - Individual price
  - Individual stock quantity
  - Individual reorder threshold

## Stock Management
- Stock quantities tracked per SKU in WooCommerce
- **Reorder threshold** set per item — when stock hits that number, a reorder alert is triggered
- Example: "SKU 358 — we would reorder four of those part numbers from this vendor"
- Reorder alerts include: SKU, quantity to reorder, vendor/supplier info

## Reorder Process (Current)
- Low inventory alert comes in
- Abby checks if she's already ordered from that vendor recently
- May batch orders: "I'm not going to re-order from them until Wednesday"
- Manual process — paper-based tracking alongside digital

## Integrations
- Shipping platform tied into WooCommerce (orders visible in shipping system)
- Order data flows: WooCommerce → Shipping platform (SKUs, quantities, customer info)
- Mailchimp integration for customer email collection (currently has backlog of 461 unprocessed)

## Inventory Philosophy
- Dan is "conscious of how much money we have in inventory"
- Tries to balance stock availability against cash tied up in inventory
- "We restock weekly"
- Out-of-stock items have in-stock notifier available
