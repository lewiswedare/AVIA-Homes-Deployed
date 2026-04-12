# Spec Range–Dependent Colour Options with Admin Editing

## Summary
Make each individual colour option tied to specific spec ranges (Volos, Messina, Portobello). Clients will only see colour options available for their assigned spec range. Admins can manage which options belong to which spec ranges from the catalog editor. Options from higher tiers will show as requestable upgrades.

---

## Features

- **Per-option spec tier availability** — Each colour option (e.g. "Surfmist" in Roof) will have tags for which spec ranges it's available in (Volos, Messina, Portobello)
- **Client-side filtering** — When a client views their colour selections, they only see options available for their assigned spec range
- **Upgrade visibility** — Options from higher spec ranges appear with an "UPGRADE" badge so clients can request them
- **Admin editing** — When admins edit a colour category, each option has checkboxes for Volos / Messina / Portobello availability
- **No options selected by default** — New options start with no tiers assigned; admins must explicitly choose which spec ranges each option applies to
- **Existing options start blank** — All existing colour options will default to no tiers assigned, so you can set them up from scratch

---

## Design

### Admin: Colour Option Editor (updated)
- Each colour option row in the edit sheet gains **three small tier toggle chips** (V / M / P) below the existing hex/brand/upgrade fields
- Teal-filled chips for enabled tiers, outline-only for disabled — quick visual scan of availability
- A "Select All" shortcut button next to the tier chips for convenience

### Client: Colour Detail View (updated)
- Options not in the client's spec tier but available in a higher tier show with a subtle "UPGRADE" capsule badge and slightly dimmed appearance
- Options not available in any higher tier are hidden entirely
- A small info banner at the top: "Showing options for your [Messina] spec range"

---

## Changes

### 1. Model Updates
- Add `availableTiers: Set<String>` to `ColourOption` (values: "volos", "messina", "portobello")
- Add `available_tiers` field to `ColourOptionRow` (the database row struct)
- Add `available_tiers` field to the upsert row
- Update all conversion functions between row ↔ model

### 2. Database / Supabase
- The `colour_categories` table stores options as JSON — the `available_tiers` array will be added to each option object
- No new tables needed; existing upsert/fetch functions updated to include the new field

### 3. Filtering Logic
- Update `CatalogDataManager` to provide filtered colour categories that return only options matching the client's spec tier (plus higher-tier options marked as upgrades)
- Update `ColourSelectionViewModel` to use the new filtered options
- Remove the old hardcoded tier exclusion logic (removing "benchtops" for Volos, etc.) — this is now handled per-option

### 4. Admin Colour Editor
- Update `EditableColourOption` to include `availableTiers: Set<String>`
- Add tier toggle chips to each option row in `ColourCategoryEditSheet`
- Save the tier data through existing save pipeline

### 5. Client Colour Views
- `ColourDetailView` — filter the options grid to show only available + upgrade options
- `ColourOverviewView` — no changes needed (already uses filtered categories from view model)
- `GuidedColourFlowView` — uses same filtered data, works automatically
- `HomeFastSchemeView` — schemes already filter by available categories

### 6. Static Fallback Data
- Update `ColourData` static arrays to include `availableTiers` for each option (defaulting to empty set so admins set them up from scratch)
