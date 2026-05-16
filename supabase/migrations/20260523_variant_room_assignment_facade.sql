-- Facade-scoped variant room assignments
--
-- Adds an optional `facade_id` to `variant_room_assignments` so that an
-- exterior variant can be made available only for builds with a specific
-- facade. NULL = applies to every facade (default, current behaviour).
--
-- This lets the External room surface different colour / finish options
-- depending on which Facade the client has chosen for their build.

-- facades.id is text in this project, so facade_id must also be text to
-- satisfy the foreign key constraint.
ALTER TABLE variant_room_assignments
    ADD COLUMN IF NOT EXISTS facade_id text
        REFERENCES facades(id) ON DELETE CASCADE;

-- Replace the legacy 3-tuple unique constraint with a 4-tuple that includes
-- facade_id. Postgres treats NULLs as distinct in unique constraints, which
-- is fine here: at most one "all-facades" row per (variant, room, range), and
-- additional rows scoped to specific facades coexist.
ALTER TABLE variant_room_assignments
    DROP CONSTRAINT IF EXISTS vra_unique;

-- Use a partial unique index for the facade-agnostic row (only one NULL row
-- allowed per variant/room/range), plus a regular unique constraint for
-- facade-scoped rows.
CREATE UNIQUE INDEX IF NOT EXISTS vra_unique_no_facade
    ON variant_room_assignments(variant_id, room_id, range_id)
    WHERE facade_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS vra_unique_with_facade
    ON variant_room_assignments(variant_id, room_id, range_id, facade_id)
    WHERE facade_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vra_facade ON variant_room_assignments(facade_id);
