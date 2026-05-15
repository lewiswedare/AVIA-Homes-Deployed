# Room-first spec range restructure

Restructures the spec catalogue around the model described by the founder:

```
Product Category (e.g. Internal Tile, External Stone, Tapware)
  └── Item (SKU, Name, Supplier, Dimensions, Description)
        └── Variant (Colour Name, Variant SKU)
              └── Room Assignment (per Range)
                    ├── Image
                    ├── Cost
                    └── Inclusion: Included | Upgrade
```

Client flow becomes **Room first**: pick a room (Kitchen / Bath / Ensuite / Laundry / …), then see every item in that room split into Included vs Upgrades, each card showing the room-specific variant image and (if upgrade) the cost.

Admins manage Categories → Items → Variants once, then assign variants to rooms with per-room image & cost. Export is grouped by Supplier.

## Naming + mapping to existing tables

Existing concept | New concept | Why
--- | --- | ---
`spec_categories` (Kitchen, Bath, Laundry, External, Frame, …) | **Rooms** | UI rename only; same table, same IDs. Client already navigates by these.
*(new)* `product_categories` | **Product Categories** | New layer — Tile, Stone, Tapware, etc. Items reparent here.
`spec_items` (+ new supplier/dimensions/description) | **Items** | Adds `product_category_id`, `supplier`, `dimensions`, `description`. Original `category_id` (room) is retained for backfill compatibility but is no longer the canonical grouping.
`spec_product_colours` (+ existing `sku` column) | **Variants** | Each colour/finish row is a Variant. The intermediate `spec_products` row stays as the "product family" (one variant per spec_product is fine too).
*(new)* `variant_room_assignments` | **Room Assignments** | Join: `(variant_id, room_id, range_id)` → image, cost, inclusion. This is the heart of the rebuild.
`spec_ranges` (Volos / Messina / Portobello) | **Ranges** | Unchanged. Inclusion + cost are per range, as today.

## Phases

### Phase 1 — Foundation (schema, models, data migration) ✅
- [x] Migration `20260522_room_first_restructure.sql`:
  - [x] `product_categories` table
  - [x] `spec_items`: add `product_category_id`, `supplier`, `dimensions`, `description`
  - [x] `variant_room_assignments` table (variant × room × range → image, cost, inclusion)
  - [x] Backfill: every existing variant gets a row in `variant_room_assignments` for the item's current spec_category (= room) across all 3 ranges, deriving inclusion + cost from `spec_range_item_products` + `spec_product_colours.extra_cost`.
  - [x] Seed a default "Uncategorized" Product Category; backfill `spec_items.product_category_id`.
- [x] Swift models for `ProductCategory`, `VariantRoomAssignment`.
- [x] `CatalogDataManager` loads + indexes new tables (additive — old paths still work).

### Phase 2 — Admin
- [ ] Rename "Spec Categories" → "Rooms" in admin nav + screen titles.
- [ ] New "Product Categories" editor (CRUD).
- [ ] Item editor: add Supplier / Dimensions / Description fields; pick Product Category.
- [ ] Variant editor: room assignment matrix — per room toggle, per (room × range) image + cost + inclusion.
- [ ] Supplier-grouped export (PDF/CSV) listing every variant, SKU, supplier, room assignments, cost.

### Phase 3 — Client
- [ ] Selections home: pure room grid (already mostly there; data source changes from category-items to variants-assigned-to-room).
- [ ] Room detail: list every Item that has at least one variant assigned to this room, split into Included / Upgrades sections using the per-(variant, room, range) inclusion.
- [ ] Card image + cost pull from the room-specific assignment, not the product/colour defaults.
- [ ] Variant picker shows variants assigned to this room only.

### Phase 4 — Cleanup
- [ ] Hide legacy "selections" mapping screen.
- [ ] Drop `spec_items.category_id` dependency from client code paths (still kept in DB for safety).
- [ ] Remove tier-cost columns on `spec_items` once new assignments fully drive pricing.

## Migration safety
- Every new column / table uses `IF NOT EXISTS`.
- Existing read paths keep working until Phase 3 cutover.
- Builds that already chose `product_id` + `colour_id` keep resolving — the new `variant_room_assignments` only changes *display + pricing for new selections*, not stored selections.
