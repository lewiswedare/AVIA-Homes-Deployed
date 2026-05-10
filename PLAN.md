# Spec catalogue v2: Slot → Products → Colours

## Mental model

- **Spec Item = slot** (e.g. "Kitchen Benchtop", "Front Entry Door"). Grouped by category (Kitchen, Bathroom, External). The slot itself is not a product anymore — it's a placeholder.
- Inside each slot, admins upload **multiple Products** (e.g. "Caesarstone Cloudburst", "Smartstone Statuario").
- Each Product is tagged per range (Volos / Messina / Portobello) as one of:
  - **Included** (free with that range)
  - **Upgrade** (available at extra cost)
  - **Unavailable** (not offered in that range)
- Each Product can carry a **base upgrade cost** per range, and each **Colour swatch** on the product can carry an additional **extra cost** on top.
- Client picks the Product first, then a Colour for it.

## Data model (already created in `20260517_spec_v2_phase1.sql`)

- `spec_products` — products inside a `spec_items` slot
- `spec_product_colours` — colours per product (needs `extra_cost numeric` added — phase 2)
- `spec_range_items` — per-range/per-slot inclusion + default product
- `spec_range_item_products` — when a range offers multiple products in a slot, the per-(range, slot, product) settings (`inclusion_override`, `upgrade_price_override`, `is_default`)
- `build_spec_selections` — already extended with `product_id`, `colour_id`, `upgrade_delta`, `manual_price_override`, `selection_state`

Phase 2 migration adds:
- `spec_product_colours.extra_cost numeric` — additional cost per colour on top of the product's range upgrade price.

## Admin flow

- **Catalog Management → Spec Range Items**: lists spec slots grouped by category (existing UI keeps working — it edits slot metadata + tier descriptions).
- New entry point on each slot row: **Manage Products** → opens product list for that slot.
- **Product list**: shows products inside the slot with name, brand, range badges (Included / Upgrade / Unavailable per Volos/Messina/Portobello). Add / Edit / Reorder / Delete.
- **Product editor**:
  - Basic: name, brand, model/SKU, description, image, dimensions, sort order
  - **Range matrix**: 3 rows (Volos / Messina / Portobello), each with:
    - Status: Included / Upgrade / Unavailable
    - Upgrade cost (AUD, only when status = Upgrade)
    - Default-for-range toggle (auto when only one product is Included for that range)
  - **Colours**: list of swatches with name, hex, image, brand/finish, default flag, **Extra cost (AUD)** per colour (added on top of the range upgrade)

## Client flow

- On the spec range page, each slot shows the Included product for that range.
- If the slot offers multiple products in this range (Included + Upgrades), client can tap to **swap product**, with upgrade cost shown.
- After choosing product, client picks **colour** from that product's swatches. Per-colour extra cost shown if any.
- Total upgrade delta = product upgrade cost (vs. range default) + colour extra cost.

## Tasks

- [x] Update PLAN.md to product-inside-slot model
- [x] Phase 2 migration: `extra_cost` on `spec_product_colours`
- [x] Swift models: `SpecProduct`, `SpecProductColour`, `SpecRangeItemProduct`
- [x] `SupabaseService` CRUD for products + colours + per-range membership
- [x] Admin: products list view inside spec slot
- [x] Admin: product editor with range matrix + colours-with-cost
- [x] Wire entry point from `AdminSpecItemsEditorView` rows
- [x] Run `runChecks`

Client-side range/colour pickers will be wired in a follow-up once admin can populate data.
