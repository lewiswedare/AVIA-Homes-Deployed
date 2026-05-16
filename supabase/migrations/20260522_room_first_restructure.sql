-- Room-first spec restructure — Phase 1 (additive)
--
-- Adds:
--   product_categories                  (Tile, Stone, Tapware…)
--   spec_items.product_category_id      (reparent items to a product category)
--   spec_items.supplier / dimensions / description
--   variant_room_assignments            (variant × room × range → image, cost, inclusion)
--
-- Backfills existing data into the new shape without touching legacy read paths.

-- =====================================================================
-- 1. Product categories (Tile, Stone, Tapware, …)
-- =====================================================================

CREATE TABLE IF NOT EXISTS product_categories (
    id          text PRIMARY KEY,
    name        text NOT NULL,
    icon        text NOT NULL DEFAULT 'square.grid.2x2',
    sort_order  integer NOT NULL DEFAULT 0,
    image_url   text,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE product_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pc_read_all   ON product_categories;
DROP POLICY IF EXISTS pc_write_auth ON product_categories;
CREATE POLICY pc_read_all   ON product_categories FOR SELECT USING (true);
CREATE POLICY pc_write_auth ON product_categories FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

INSERT INTO product_categories (id, name, icon, sort_order)
VALUES ('uncategorized', 'Uncategorized', 'square.grid.2x2', 9999)
ON CONFLICT (id) DO NOTHING;

-- =====================================================================
-- 2. spec_items: supplier / dimensions / description / product_category_id
-- =====================================================================

ALTER TABLE spec_items
    ADD COLUMN IF NOT EXISTS product_category_id text REFERENCES product_categories(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS supplier            text,
    ADD COLUMN IF NOT EXISTS dimensions          text,
    ADD COLUMN IF NOT EXISTS description         text,
    ADD COLUMN IF NOT EXISTS sku                 text;

UPDATE spec_items
SET product_category_id = 'uncategorized'
WHERE product_category_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_spec_items_product_category
    ON spec_items(product_category_id);
CREATE INDEX IF NOT EXISTS idx_spec_items_supplier
    ON spec_items(supplier);

-- =====================================================================
-- 3. variant_room_assignments — the heart of the rebuild
--    A "variant" is a row in spec_product_colours.
--    A "room" is a row in spec_categories (legacy table, renamed in UI).
-- =====================================================================

CREATE TABLE IF NOT EXISTS variant_room_assignments (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    variant_id   text NOT NULL REFERENCES spec_product_colours(id) ON DELETE CASCADE,
    room_id      text NOT NULL REFERENCES spec_categories(id)      ON DELETE CASCADE,
    range_id     text NOT NULL REFERENCES spec_ranges(id)          ON DELETE CASCADE,
    image_url    text,
    cost         numeric NOT NULL DEFAULT 0,
    inclusion    text    NOT NULL DEFAULT 'included',   -- 'included' | 'upgrade'
    sort_order   integer NOT NULL DEFAULT 0,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT vra_unique UNIQUE (variant_id, room_id, range_id),
    CONSTRAINT vra_inclusion_chk CHECK (inclusion IN ('included', 'upgrade'))
);
CREATE INDEX IF NOT EXISTS idx_vra_room_range ON variant_room_assignments(room_id, range_id);
CREATE INDEX IF NOT EXISTS idx_vra_variant    ON variant_room_assignments(variant_id);

ALTER TABLE variant_room_assignments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS vra_read_all   ON variant_room_assignments;
DROP POLICY IF EXISTS vra_write_auth ON variant_room_assignments;
CREATE POLICY vra_read_all   ON variant_room_assignments FOR SELECT USING (true);
CREATE POLICY vra_write_auth ON variant_room_assignments FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- =====================================================================
-- 4. Backfill: every existing variant gets an assignment for its item's
--    current spec_category (= room) across all three ranges. Cost and
--    inclusion are derived from spec_range_item_products + spec_range_items.
--    (Earlier schemas stored a per-colour extra_cost; we no longer rely on
--    it here so the migration is portable across databases where that
--    column was never added or has since been dropped.)
-- =====================================================================

INSERT INTO variant_room_assignments (variant_id, room_id, range_id, image_url, cost, inclusion, sort_order)
SELECT
    pc.id                                      AS variant_id,
    si.category_id                             AS room_id,
    sr.id                                      AS range_id,
    pc.image_url                               AS image_url,
    COALESCE(
        srip.upgrade_price_override,
        sri.upgrade_price_override,
        0
    )                                          AS cost,
    CASE
        WHEN COALESCE(srip.inclusion_override, sri.inclusion, 'included') = 'upgrade' THEN 'upgrade'
        ELSE 'included'
    END                                        AS inclusion,
    COALESCE(pc.sort_order, 0)                 AS sort_order
FROM spec_product_colours pc
JOIN spec_products      sp ON sp.id = pc.product_id
JOIN spec_items         si ON si.id = sp.spec_item_id
CROSS JOIN spec_ranges  sr
LEFT JOIN spec_range_items sri
    ON sri.range_id = sr.id AND sri.spec_item_id = si.id
LEFT JOIN spec_range_item_products srip
    ON srip.range_id = sr.id
   AND srip.spec_item_id = si.id
   AND srip.product_id = sp.id
WHERE si.category_id IS NOT NULL
  AND COALESCE(srip.inclusion_override, sri.inclusion, 'included') <> 'unavailable'
ON CONFLICT (variant_id, room_id, range_id) DO NOTHING;

-- =====================================================================
-- 5. Updated-at trigger reuse
-- =====================================================================

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;

DROP TRIGGER IF EXISTS trg_pc_touch  ON product_categories;
CREATE TRIGGER trg_pc_touch  BEFORE UPDATE ON product_categories
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS trg_vra_touch ON variant_room_assignments;
CREATE TRIGGER trg_vra_touch BEFORE UPDATE ON variant_room_assignments
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
