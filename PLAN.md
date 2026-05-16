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

### Phase 2 — Admin ✅
- [x] Rename "Spec Categories" → "Rooms" in admin nav + screen titles.
- [x] New "Product Categories" editor (CRUD).
- [x] Item editor: add Supplier / Dimensions / Description fields; pick Product Category.
- [x] Variant editor: room assignment matrix — per room toggle, per (room × range) image + cost + inclusion.
- [x] Supplier-grouped export (PDF/CSV) listing every variant, SKU, supplier, room assignments, cost.

### Phase 3 — Client ✅
- [x] Selections home: pure room grid (already mostly there; data source changes from category-items to variants-assigned-to-room).
- [x] Room detail: list every Item that has at least one variant assigned to this room, split into Included / Upgrades sections using the per-(variant, room, range) inclusion.
- [x] Card image + cost pull from the room-specific assignment, not the product/colour defaults.
- [x] Variant picker shows variants assigned to this room only.

### Phase 4 — Cleanup
- [x] Hide legacy "selections" mapping screen. Client notification deep-links
      route to `SelectionsHomeView` instead of `SpecificationsOverviewView`;
      the legacy spec-item ↔ colour-category picker on the colour editor was
      already replaced by the per-item editor.
- [x] Drop `spec_items.category_id` dependency from client code paths. Client
      surfaces (`SelectionsHomeView`, `SelectionsRoomDetailView`,
      `BuildColourSelectionView`) navigate by `snapshotCategoryName` /
      `variant_room_assignments` only; `category_id` remains in DB + admin
      editors for compatibility.
- [ ] Remove tier-cost columns on `spec_items` once new assignments fully
      drive pricing. **In progress** — migration started:
  - [x] `AdminSpecItemsEditorView`: drop the per-tier upgrade-cost editor
        section; admins now set cost & inclusion per (variant, room, range)
        in the Variant editor. Legacy columns on the row are preserved on
        save for backwards compatibility.
  - [x] `AdminUpgradeQuoteView`: auto-cost now sources from
        `variant_room_assignments` (chosen variant in the selection's room +
        range, or cheapest upgrade variant for the item in that room +
        range). Legacy product/colour cost remains as a fallback.
  - [x] `SpecificationItemDetailView` removed. The whole legacy chain
        (`SpecificationsOverviewView` → `SpecificationCategoryDetailView`
        → `SpecificationItemDetailView`) was dead code after the Phase 4
        deep-link redirect and has been deleted.
  - [x] Whole-range tier-upgrade flow migrated. `SelectionsRoomDetailView`
        (per-item upgrade tiles) and `SpecificationViewModel.requestUpgrade`
        (whole-range bulk upgrade) now estimate tier upgrade cost from
        `variant_room_assignments` via
        `CatalogDataManager.cheapestUpgradeCost(forSpecItem:roomId:rangeId:)`
        (with a room-agnostic fallback for legacy items). Tier-cost columns
        on `spec_items` are no longer read by client tier-upgrade flows.
  - [ ] Once all consumers are migrated, drop `volos_to_messina_cost`,
        `volos_to_portobello_cost`, `messina_to_portobello_cost` columns
        and remove `SpecItem.upgradeCost(from:to:)`.

### Phase 5 — Facade-scoped exterior selections

Some exterior items (e.g. Render colour, Front door, Garage door trim) are
facade-specific: the options a client sees in the External room should
change depending on which Facade has been allocated to their build.

- [x] Migration `20260523_variant_room_assignment_facade.sql`: add nullable
      `facade_id` column to `variant_room_assignments` (`NULL` = applies to
      all facades; non-null = only that facade). Replaces the 3-tuple
      uniqueness with partial unique indexes that allow at most one
      facade-agnostic row plus N facade-scoped rows per (variant, room,
      range).
- [x] Swift model: `VariantRoomAssignmentRow.facade_id` + composite key
      includes the facade scope.
- [x] `CatalogDataManager` learns about facade context: `assignment(…)`,
      `variantIds(forRoom:rangeId:facadeId:)`, and `cheapestUpgradeCost(…)`
      all accept an optional `facadeId` and prefer facade-specific rows over
      the facade-agnostic default.
- [x] Client selections pipe the build's `selectedFacadeId` into the room
      detail view, the item card included/upgrade classification, and the
      product picker.
- [x] Admin Variant → Room Assignments matrix gains a per-room Facade
      picker (“All facades” or one of the configured facades).
      **Rolled back from All Products:** the picker + facade-scoped badges
      proved too confusing inside the unified "All Products" admin view.
      `AdminAllProductsView` and the variant Room Assignments editor it
      launches now only surface facade-agnostic rows. Existing facade-
      scoped assignments are preserved untouched in the database.
- [x] `SupabaseService.upsertVariantRoomAssignment` reworked to handle the
      partial unique indexes (NULLs are distinct in Postgres unique
      constraints).
- [ ] Dedicated "Facade-specific Products" admin editor for the handful of
      items whose variants change per facade (render colour, front door,
      garage door trim, etc.).

## Migration safety
- Every new column / table uses `IF NOT EXISTS`.
- Existing read paths keep working until Phase 3 cutover.
- Builds that already chose `product_id` + `colour_id` keep resolving — the new `variant_room_assignments` only changes *display + pricing for new selections*, not stored selections.
