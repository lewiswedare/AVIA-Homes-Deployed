# Simplify catalogue: one place for spec range items with colours built in

## What changes for admins

**Catalog Management hub becomes simpler.** The standalone "Selection Categories" and "Colour Selections" cards are removed. Admins now manage everything product-related from a single place: **Spec Range Items**.

Inside each spec range product, admins will now see a new **Colours** section where they can:
- Add colour swatches directly to that product (name, hex/colour image, brand/finish notes)
- Mark colours as included or as upgrades (with optional upgrade cost)
- Reorder and remove swatches inline
- Choose "No colour variants" for fixed-inclusion products that don't need a colour pick

Spec items remain grouped by category (Kitchen, Bathroom, External Finishes, etc.) for organisation — that grouping stays exactly as it is today, just managed implicitly through the product editor.

The old Colour Categories editor and Selection Categories editor are hidden from the hub. Existing shared colour palettes are auto-migrated into per-product swatches and the legacy shared categories are deleted — the per-product list is the only source of truth.

## What changes for clients

When a client confirms a spec range product, the **colour picker for that exact product** appears in their Stage 2 selections — pulling from the swatches the admin attached to it.

- Products with "No colour variants" skip the colour step entirely
- Products with multiple colours show the swatches the admin uploaded for that specific product
- The overall colour selections screen now lists one colour pick per approved spec product, in the same room/category groupings as today

## Pages affected

- **Admin → Catalog Management**: Two cards removed, info card updated to reflect the new flow
- **Admin → Spec Range Items → Edit Product**: New inline "Colours" section replaces the "Linked colour categories" chip grid
- **Client → Build → Colour Selections**: Pulls colours from each spec product directly instead of from the shared colour categories

## Migration (confirmed: clean slate)

Implemented in `supabase/migrations/20260516_migrate_to_per_product_colours.sql`:

- For each existing `spec_to_colour_mapping` link, copy the shared category's options into a per-product palette `spec_<spec_item_id>_colours` (merging when an item was linked to multiple shared categories, dedup by option id).
- Repoint mappings so each spec item points only at its own per-product palette.
- Delete every legacy shared `colour_categories` row.
- Wipe `build_colour_selections` — old in-flight builds are intentionally not carried over (confirmed acceptable: "old builds aren't important").
