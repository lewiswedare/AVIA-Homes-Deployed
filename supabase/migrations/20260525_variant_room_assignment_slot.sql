-- Per-slot variant room assignments
--
-- Phase 6 follow-up: support the same variant appearing multiple times in
-- one room with different per-slot titles (e.g. one tile SKU used as both
-- "Floor Tiles" AND "Wall Tiles" in the Bathroom). Each "slot" is a stable
-- uuid that ties together the 3 range rows (Volos / Messina / Portobello)
-- of one logical client-facing line-item.
--
-- The client materialises one `build_spec_selections` row per slot, so a
-- room with two slots of the same spec item produces two selectable cards.

-- =====================================================================
-- 1. variant_room_assignments.selection_slot_id
-- =====================================================================

ALTER TABLE variant_room_assignments
    ADD COLUMN IF NOT EXISTS selection_slot_id uuid;

-- Backfill: one shared slot id across all 3 ranges of each existing
-- (variant, room, facade) triple. Treats NULL facade as a distinct group
-- from any facade-specific rows.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT DISTINCT variant_id, room_id, facade_id
        FROM variant_room_assignments
        WHERE selection_slot_id IS NULL
    LOOP
        UPDATE variant_room_assignments
        SET selection_slot_id = gen_random_uuid()
        WHERE variant_id = r.variant_id
          AND room_id    = r.room_id
          AND facade_id IS NOT DISTINCT FROM r.facade_id
          AND selection_slot_id IS NULL;
    END LOOP;
END $$;

ALTER TABLE variant_room_assignments
    ALTER COLUMN selection_slot_id SET DEFAULT gen_random_uuid();

ALTER TABLE variant_room_assignments
    ALTER COLUMN selection_slot_id SET NOT NULL;

-- Replace the slot-agnostic partial unique indexes with slot-aware ones so
-- multiple slots of the same (variant, room, range[, facade]) can coexist.
DROP INDEX IF EXISTS vra_unique_no_facade;
DROP INDEX IF EXISTS vra_unique_with_facade;

CREATE UNIQUE INDEX IF NOT EXISTS vra_unique_slot_no_facade
    ON variant_room_assignments(variant_id, room_id, range_id, selection_slot_id)
    WHERE facade_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS vra_unique_slot_with_facade
    ON variant_room_assignments(variant_id, room_id, range_id, facade_id, selection_slot_id)
    WHERE facade_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vra_slot ON variant_room_assignments(selection_slot_id);

-- =====================================================================
-- 2. build_spec_selections.selection_slot_id
-- =====================================================================
--
-- Nullable for backwards compatibility with legacy selections that haven't
-- been re-materialised against slots yet. New snapshots populate one row
-- per slot in the room.

ALTER TABLE build_spec_selections
    ADD COLUMN IF NOT EXISTS selection_slot_id uuid;

CREATE INDEX IF NOT EXISTS idx_bss_slot ON build_spec_selections(selection_slot_id);

-- Relax the legacy (build_id, spec_item_id) uniqueness so multiple slots of
-- the same spec item can coexist for a build. Postgres treats NULLs as
-- distinct, so split into two partial indexes:
--   • legacy rows (slot IS NULL): one per (build_id, spec_item_id)
--   • slot rows: one per (build_id, spec_item_id, selection_slot_id)
ALTER TABLE build_spec_selections
    DROP CONSTRAINT IF EXISTS bss_build_spec_unique;

CREATE UNIQUE INDEX IF NOT EXISTS bss_unique_no_slot
    ON build_spec_selections(build_id, spec_item_id)
    WHERE selection_slot_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS bss_unique_with_slot
    ON build_spec_selections(build_id, spec_item_id, selection_slot_id)
    WHERE selection_slot_id IS NOT NULL;
