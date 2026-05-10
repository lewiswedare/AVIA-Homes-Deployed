-- Phase 1 of the AVIA spec system rebuild.
-- Adds a normalized catalog model (Range -> Category -> Item -> Product -> Colour)
-- without breaking the existing iOS app, which still reads the per-tier columns
-- on `spec_items`. New tables sit alongside the legacy schema; sync triggers
-- keep them aligned in both directions.
--
-- Created tables:
--   spec_ranges, spec_products, spec_product_prices, spec_product_colours,
--   spec_range_items, spec_range_item_products, build_range_history
--
-- Added columns on builds: spec_range_id (-> spec_ranges)
-- Added columns on build_spec_selections: product_id, colour_id, price_at_contract,
--   upgrade_delta, manual_price_override, selection_state, is_valid_at_current_range,
--   spec_range_id
-- Plus unique constraint (build_id, spec_item_id) to prevent duplicate selection rows.
--
-- See SQL helper functions:
--   resolve_product_price(product_id, at_date)
--   compute_upgrade_delta(build_id, spec_item_id)
--   validate_selections_at_range(build_id, new_range_id)
--   apply_range_change(build_id, new_range_id, ...)
--
-- And the read-friendly view: v_build_selections_full
--
-- Sync triggers keep the new model and the legacy columns aligned:
--   sync_spec_item_tier_description (spec_range_items.inclusion_copy -> spec_items.{tier}_description)
--   sync_build_range_and_tier        (builds.spec_tier <-> builds.spec_range_id)
--   default_bss_spec_range_id        (build_spec_selections insert defaults)
--
-- This file is a no-op when applied on a database that already received the
-- equivalent migrations from the management API \u2014 every CREATE statement uses
-- IF NOT EXISTS / OR REPLACE for safety.

-- =====================================================================
-- 1. Catalog tables
-- =====================================================================

CREATE TABLE IF NOT EXISTS spec_ranges (
    id          text PRIMARY KEY,
    name        text NOT NULL,
    tier_order  integer NOT NULL,
    description text,
    base_price  numeric,
    image_url   text,
    is_active   boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE spec_ranges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS spec_ranges_read_all  ON spec_ranges;
DROP POLICY IF EXISTS spec_ranges_write_auth ON spec_ranges;
CREATE POLICY spec_ranges_read_all  ON spec_ranges FOR SELECT USING (true);
CREATE POLICY spec_ranges_write_auth ON spec_ranges FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE TABLE IF NOT EXISTS spec_products (
    id            text PRIMARY KEY,
    spec_item_id  text NOT NULL REFERENCES spec_items(id) ON DELETE CASCADE,
    brand         text,
    model         text,
    sku           text,
    name          text NOT NULL,
    description   text,
    image_url     text,
    dimensions    text,
    is_active     boolean NOT NULL DEFAULT true,
    sort_order    integer NOT NULL DEFAULT 0,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_spec_products_item ON spec_products(spec_item_id);
ALTER TABLE spec_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS spec_products_read_all  ON spec_products;
DROP POLICY IF EXISTS spec_products_write_auth ON spec_products;
CREATE POLICY spec_products_read_all  ON spec_products FOR SELECT USING (true);
CREATE POLICY spec_products_write_auth ON spec_products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE TABLE IF NOT EXISTS spec_product_prices (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id     text NOT NULL REFERENCES spec_products(id) ON DELETE CASCADE,
    cost           numeric NOT NULL,
    effective_from timestamptz NOT NULL DEFAULT now(),
    effective_to   timestamptz,
    notes          text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT spp_effective_window CHECK (effective_to IS NULL OR effective_to > effective_from)
);
CREATE INDEX IF NOT EXISTS idx_spp_product_active ON spec_product_prices(product_id, effective_from DESC);
ALTER TABLE spec_product_prices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS spp_read_all  ON spec_product_prices;
DROP POLICY IF EXISTS spp_write_auth ON spec_product_prices;
CREATE POLICY spp_read_all  ON spec_product_prices FOR SELECT USING (true);
CREATE POLICY spp_write_auth ON spec_product_prices FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE TABLE IF NOT EXISTS spec_product_colours (
    id          text PRIMARY KEY,
    product_id  text NOT NULL REFERENCES spec_products(id) ON DELETE CASCADE,
    name        text NOT NULL,
    hex         text,
    image_url   text,
    is_default  boolean NOT NULL DEFAULT false,
    is_active   boolean NOT NULL DEFAULT true,
    sort_order  integer NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT spec_product_colours_name_unique UNIQUE (product_id, name)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_spec_product_colours_one_default
    ON spec_product_colours(product_id) WHERE is_default = true;
ALTER TABLE spec_product_colours ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS spc_read_all  ON spec_product_colours;
DROP POLICY IF EXISTS spc_write_auth ON spec_product_colours;
CREATE POLICY spc_read_all  ON spec_product_colours FOR SELECT USING (true);
CREATE POLICY spc_write_auth ON spec_product_colours FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- spec_range_items: which inclusion (default-product, or open choice) a range gives
CREATE TABLE IF NOT EXISTS spec_range_items (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    range_id              text NOT NULL REFERENCES spec_ranges(id) ON DELETE CASCADE,
    spec_item_id          text NOT NULL REFERENCES spec_items(id)  ON DELETE CASCADE,
    inclusion             text NOT NULL DEFAULT 'included',          -- included | upgrade | unavailable
    selection_mode        text NOT NULL DEFAULT 'fixed',              -- fixed | choose
    default_product_id    text REFERENCES spec_products(id) ON DELETE SET NULL,
    upgrade_price_override numeric,
    inclusion_copy        text,
    notes                 text,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT spec_range_items_unique UNIQUE (range_id, spec_item_id)
);
CREATE INDEX IF NOT EXISTS idx_spec_range_items_range ON spec_range_items(range_id);
ALTER TABLE spec_range_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sri_read_all  ON spec_range_items;
DROP POLICY IF EXISTS sri_write_auth ON spec_range_items;
CREATE POLICY sri_read_all  ON spec_range_items FOR SELECT USING (true);
CREATE POLICY sri_write_auth ON spec_range_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- spec_range_item_products: when selection_mode = 'choose', the available products for that range/item
CREATE TABLE IF NOT EXISTS spec_range_item_products (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    range_id               text NOT NULL REFERENCES spec_ranges(id) ON DELETE CASCADE,
    spec_item_id           text NOT NULL REFERENCES spec_items(id)  ON DELETE CASCADE,
    product_id             text NOT NULL REFERENCES spec_products(id) ON DELETE CASCADE,
    is_default             boolean NOT NULL DEFAULT false,
    inclusion_override     text,                                      -- e.g. 'upgrade' even though range default is 'included'
    upgrade_price_override numeric,
    sort_order             integer NOT NULL DEFAULT 0,
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT spec_range_item_products_unique UNIQUE (range_id, spec_item_id, product_id)
);
ALTER TABLE spec_range_item_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS srip_read_all  ON spec_range_item_products;
DROP POLICY IF EXISTS srip_write_auth ON spec_range_item_products;
CREATE POLICY srip_read_all  ON spec_range_item_products FOR SELECT USING (true);
CREATE POLICY srip_write_auth ON spec_range_item_products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- =====================================================================
-- 2. Build linkage to ranges + range-change history
-- =====================================================================

ALTER TABLE builds ADD COLUMN IF NOT EXISTS spec_range_id text REFERENCES spec_ranges(id);

CREATE TABLE IF NOT EXISTS build_range_history (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    build_id      text NOT NULL,
    from_range_id text,
    to_range_id   text NOT NULL,
    cost_delta    numeric,
    changed_by    uuid,
    reason        text,
    changed_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_build_range_history_build ON build_range_history(build_id, changed_at DESC);
ALTER TABLE build_range_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS brh_read_all  ON build_range_history;
DROP POLICY IF EXISTS brh_write_auth ON build_range_history;
CREATE POLICY brh_read_all  ON build_range_history FOR SELECT USING (true);
CREATE POLICY brh_write_auth ON build_range_history FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- =====================================================================
-- 3. build_spec_selections: new product/colour/pricing columns + unique constraint
-- =====================================================================

ALTER TABLE build_spec_selections
    ADD COLUMN IF NOT EXISTS product_id            text REFERENCES spec_products(id),
    ADD COLUMN IF NOT EXISTS colour_id             text REFERENCES spec_product_colours(id),
    ADD COLUMN IF NOT EXISTS price_at_contract     numeric,
    ADD COLUMN IF NOT EXISTS upgrade_delta         numeric,
    ADD COLUMN IF NOT EXISTS manual_price_override numeric,
    ADD COLUMN IF NOT EXISTS selection_state       text DEFAULT 'included',
    ADD COLUMN IF NOT EXISTS is_valid_at_current_range boolean DEFAULT true,
    ADD COLUMN IF NOT EXISTS spec_range_id         text REFERENCES spec_ranges(id);

-- Allowed values for selection_state: included | upgraded | unavailable_at_current_range | custom
-- (Kept as text rather than enum to ease rollout.)

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'bss_build_spec_unique'
    ) THEN
        ALTER TABLE build_spec_selections
            ADD CONSTRAINT bss_build_spec_unique UNIQUE (build_id, spec_item_id);
    END IF;
END $$;

-- =====================================================================
-- 4. Helper functions and view
-- =====================================================================

CREATE OR REPLACE FUNCTION resolve_product_price(p_product_id text, p_at_date timestamptz DEFAULT now())
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
  SELECT cost
  FROM spec_product_prices
  WHERE product_id = p_product_id
    AND effective_from <= p_at_date
    AND (effective_to IS NULL OR effective_to > p_at_date)
  ORDER BY effective_from DESC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION compute_upgrade_delta(p_build_id text, p_spec_item_id text)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_range_id text;
  v_contract_date timestamptz;
  v_chosen_product text;
  v_manual_override numeric;
  v_included_product text;
  v_range_override numeric;
  v_chosen_price numeric;
  v_included_price numeric;
BEGIN
  SELECT b.spec_range_id, COALESCE(b.contract_date, now())
    INTO v_range_id, v_contract_date
  FROM builds b WHERE b.id = p_build_id;

  SELECT bss.product_id, bss.manual_price_override
    INTO v_chosen_product, v_manual_override
  FROM build_spec_selections bss
  WHERE bss.build_id = p_build_id AND bss.spec_item_id = p_spec_item_id;

  SELECT sri.default_product_id, sri.upgrade_price_override
    INTO v_included_product, v_range_override
  FROM spec_range_items sri
  WHERE sri.range_id = v_range_id AND sri.spec_item_id = p_spec_item_id;

  IF v_manual_override IS NOT NULL THEN RETURN v_manual_override; END IF;
  IF v_range_override  IS NOT NULL THEN RETURN v_range_override;  END IF;
  IF v_chosen_product IS NULL OR v_included_product IS NULL THEN RETURN 0; END IF;
  IF v_chosen_product = v_included_product THEN RETURN 0; END IF;

  v_chosen_price   := resolve_product_price(v_chosen_product,   v_contract_date);
  v_included_price := resolve_product_price(v_included_product, v_contract_date);
  RETURN COALESCE(v_chosen_price, 0) - COALESCE(v_included_price, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION resolve_product_price(text, timestamptz) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION compute_upgrade_delta(text, text)         TO anon, authenticated;

CREATE OR REPLACE FUNCTION validate_selections_at_range(p_build_id text, p_new_range_id text)
RETURNS TABLE (
  spec_item_id              text,
  current_product_id        text,
  available_at_new_range    boolean,
  inclusion_at_new_range    text,
  default_product_at_new_range text
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    bss.spec_item_id,
    bss.product_id,
    CASE
      WHEN bss.product_id IS NULL THEN true
      WHEN srip.product_id IS NOT NULL AND COALESCE(srip.inclusion_override, sri.inclusion) <> 'unavailable' THEN true
      ELSE false
    END,
    sri.inclusion,
    sri.default_product_id
  FROM build_spec_selections bss
  LEFT JOIN spec_range_items sri
    ON sri.range_id = p_new_range_id AND sri.spec_item_id = bss.spec_item_id
  LEFT JOIN spec_range_item_products srip
    ON srip.range_id = p_new_range_id
    AND srip.spec_item_id = bss.spec_item_id
    AND srip.product_id = bss.product_id
  WHERE bss.build_id = p_build_id;
$$;
GRANT EXECUTE ON FUNCTION validate_selections_at_range(text, text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION apply_range_change(
  p_build_id   text,
  p_new_range_id text,
  p_changed_by uuid DEFAULT NULL,
  p_reason     text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_old_range text;
  v_invalid_count int;
BEGIN
  SELECT spec_range_id INTO v_old_range FROM builds WHERE id = p_build_id;
  INSERT INTO build_range_history (build_id, from_range_id, to_range_id, changed_by, reason)
  VALUES (p_build_id, v_old_range, p_new_range_id, p_changed_by, p_reason);
  UPDATE builds SET spec_range_id = p_new_range_id WHERE id = p_build_id;
  UPDATE build_spec_selections bss
  SET spec_range_id = p_new_range_id,
      is_valid_at_current_range = v.available_at_new_range,
      selection_state = CASE
        WHEN NOT v.available_at_new_range THEN 'unavailable_at_current_range'
        WHEN bss.product_id IS NULL THEN 'included'
        ELSE bss.selection_state
      END,
      updated_at = now()
  FROM validate_selections_at_range(p_build_id, p_new_range_id) v
  WHERE bss.build_id = p_build_id AND bss.spec_item_id = v.spec_item_id;
  SELECT COUNT(*) INTO v_invalid_count
  FROM build_spec_selections
  WHERE build_id = p_build_id AND is_valid_at_current_range = false;
  RETURN jsonb_build_object(
    'from_range', v_old_range,
    'to_range', p_new_range_id,
    'invalid_selections', v_invalid_count
  );
END;
$$;
GRANT EXECUTE ON FUNCTION apply_range_change(text, text, uuid, text) TO authenticated;

CREATE OR REPLACE VIEW v_build_selections_full AS
SELECT
  bss.id AS selection_id,
  bss.build_id,
  b.spec_range_id AS build_range_id,
  sr.name        AS range_name,
  sr.tier_order  AS range_tier_order,
  bss.spec_item_id,
  si.name        AS item_name,
  si.category_id,
  sc.name        AS category_name,
  si.sort_order  AS item_sort_order,
  sri.inclusion,
  sri.selection_mode,
  sri.inclusion_copy,
  sri.default_product_id AS included_product_id,
  inc_p.name  AS included_product_name,
  inc_p.brand AS included_product_brand,
  bss.product_id AS chosen_product_id,
  ch_p.name   AS chosen_product_name,
  ch_p.brand  AS chosen_product_brand,
  bss.colour_id,
  pc.name AS colour_name,
  pc.hex  AS colour_hex,
  bss.selection_state,
  bss.is_valid_at_current_range,
  bss.manual_price_override,
  compute_upgrade_delta(bss.build_id, bss.spec_item_id) AS upgrade_delta_computed,
  bss.client_confirmed,
  bss.admin_confirmed,
  bss.client_notes,
  bss.admin_notes,
  bss.status
FROM build_spec_selections bss
JOIN builds b              ON b.id = bss.build_id
LEFT JOIN spec_ranges sr   ON sr.id = b.spec_range_id
LEFT JOIN spec_items si    ON si.id = bss.spec_item_id
LEFT JOIN spec_categories sc ON sc.id = si.category_id
LEFT JOIN spec_range_items sri ON sri.range_id = b.spec_range_id AND sri.spec_item_id = bss.spec_item_id
LEFT JOIN spec_products inc_p ON inc_p.id = sri.default_product_id
LEFT JOIN spec_products ch_p  ON ch_p.id = bss.product_id
LEFT JOIN spec_product_colours pc ON pc.id = bss.colour_id;

GRANT SELECT ON v_build_selections_full TO anon, authenticated;

-- =====================================================================
-- 5. Sync triggers \u2014 keep new model and legacy columns aligned
-- =====================================================================

-- spec_range_items.inclusion_copy -> spec_items.{tier}_description
CREATE OR REPLACE FUNCTION sync_spec_item_tier_description()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.inclusion_copy IS NULL OR length(trim(NEW.inclusion_copy)) = 0 THEN RETURN NEW; END IF;
  IF NEW.range_id = 'volos' THEN
    UPDATE spec_items SET volos_description = NEW.inclusion_copy, updated_at = now()
    WHERE id = NEW.spec_item_id AND COALESCE(volos_description,'') <> NEW.inclusion_copy;
  ELSIF NEW.range_id = 'messina' THEN
    UPDATE spec_items SET messina_description = NEW.inclusion_copy, updated_at = now()
    WHERE id = NEW.spec_item_id AND COALESCE(messina_description,'') <> NEW.inclusion_copy;
  ELSIF NEW.range_id = 'portobello' THEN
    UPDATE spec_items SET portobello_description = NEW.inclusion_copy, updated_at = now()
    WHERE id = NEW.spec_item_id AND COALESCE(portobello_description,'') <> NEW.inclusion_copy;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_sync_spec_item_tier_description ON spec_range_items;
CREATE TRIGGER trg_sync_spec_item_tier_description
AFTER INSERT OR UPDATE OF inclusion_copy ON spec_range_items
FOR EACH ROW EXECUTE FUNCTION sync_spec_item_tier_description();

-- builds.spec_tier <-> builds.spec_range_id
CREATE OR REPLACE FUNCTION sync_build_range_and_tier()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF (TG_OP = 'INSERT' OR NEW.spec_tier IS DISTINCT FROM OLD.spec_tier) AND NEW.spec_tier IS NOT NULL THEN
    IF lower(NEW.spec_tier) IN ('volos','messina','portobello') THEN
      NEW.spec_range_id := lower(NEW.spec_tier);
    END IF;
  END IF;
  IF (TG_OP = 'INSERT' OR NEW.spec_range_id IS DISTINCT FROM OLD.spec_range_id) AND NEW.spec_range_id IS NOT NULL THEN
    NEW.spec_tier := NEW.spec_range_id;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_sync_build_range_and_tier ON builds;
CREATE TRIGGER trg_sync_build_range_and_tier
BEFORE INSERT OR UPDATE OF spec_tier, spec_range_id ON builds
FOR EACH ROW EXECUTE FUNCTION sync_build_range_and_tier();

-- build_spec_selections inserts: default spec_range_id from the parent build
CREATE OR REPLACE FUNCTION default_bss_spec_range_id()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.spec_range_id IS NULL THEN
    SELECT spec_range_id INTO NEW.spec_range_id FROM builds WHERE id = NEW.build_id;
  END IF;
  IF NEW.spec_tier IS NULL AND NEW.spec_range_id IS NOT NULL THEN
    NEW.spec_tier := NEW.spec_range_id;
  END IF;
  IF NEW.selection_state IS NULL THEN NEW.selection_state := 'included'; END IF;
  IF NEW.is_valid_at_current_range IS NULL THEN NEW.is_valid_at_current_range := true; END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_default_bss_spec_range_id ON build_spec_selections;
CREATE TRIGGER trg_default_bss_spec_range_id
BEFORE INSERT OR UPDATE ON build_spec_selections
FOR EACH ROW EXECUTE FUNCTION default_bss_spec_range_id();

-- =====================================================================
-- 6. Seed the three ranges (idempotent)
-- =====================================================================

INSERT INTO spec_ranges (id, name, tier_order, description, is_active) VALUES
  ('volos',      'Volos',      1, 'Essence range \u2014 entry tier', true),
  ('messina',    'Messina',    2, 'Icon range \u2014 mid tier',     true),
  ('portobello', 'Portobello', 3, 'Vogue range \u2014 premium tier', true)
ON CONFLICT (id) DO UPDATE
SET name        = EXCLUDED.name,
    tier_order  = EXCLUDED.tier_order,
    description = EXCLUDED.description,
    is_active   = EXCLUDED.is_active;

-- =====================================================================
-- 7. Backfill: spec_items tier descriptions and builds.spec_range_id
-- =====================================================================

UPDATE spec_items si
SET volos_description = COALESCE(NULLIF(sri.inclusion_copy, ''), si.volos_description)
FROM spec_range_items sri
WHERE sri.range_id = 'volos' AND sri.spec_item_id = si.id
  AND sri.inclusion_copy IS NOT NULL AND length(trim(sri.inclusion_copy)) > 0;

UPDATE spec_items si
SET messina_description = COALESCE(NULLIF(sri.inclusion_copy, ''), si.messina_description)
FROM spec_range_items sri
WHERE sri.range_id = 'messina' AND sri.spec_item_id = si.id
  AND sri.inclusion_copy IS NOT NULL AND length(trim(sri.inclusion_copy)) > 0;

UPDATE spec_items si
SET portobello_description = COALESCE(NULLIF(sri.inclusion_copy, ''), si.portobello_description)
FROM spec_range_items sri
WHERE sri.range_id = 'portobello' AND sri.spec_item_id = si.id
  AND sri.inclusion_copy IS NOT NULL AND length(trim(sri.inclusion_copy)) > 0;

UPDATE builds
SET spec_range_id = lower(spec_tier)
WHERE spec_range_id IS NULL
  AND spec_tier IS NOT NULL
  AND lower(spec_tier) IN ('volos','messina','portobello');

UPDATE build_spec_selections bss
SET spec_range_id = COALESCE(bss.spec_range_id, b.spec_range_id),
    spec_tier     = COALESCE(bss.spec_tier,     b.spec_tier)
FROM builds b
WHERE b.id = bss.build_id
  AND (bss.spec_range_id IS NULL OR bss.spec_tier IS NULL);
