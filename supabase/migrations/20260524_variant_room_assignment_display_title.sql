-- Per-room display title override for variant room assignments
--
-- The same variant can now live in multiple rooms with a different
-- "selection title" in each room (e.g. one tile SKU surfaces as
-- "Floor Tiles" in the Bathroom and "Splashback" in the Kitchen).
-- The override is stored on the assignment row so it travels with
-- (variant, room, range, facade) — the existing uniqueness still
-- applies, so we treat all 3 ranges of one (variant, room) pair as
-- sharing the same display title in the admin editor.

ALTER TABLE variant_room_assignments
    ADD COLUMN IF NOT EXISTS display_title text;
