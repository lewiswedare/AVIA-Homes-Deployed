-- Phase 2 of the AVIA spec catalogue rebuild.
-- Adds per-colour extra cost on top of a product's range upgrade price.

ALTER TABLE spec_product_colours
    ADD COLUMN IF NOT EXISTS extra_cost numeric;

COMMENT ON COLUMN spec_product_colours.extra_cost IS
    'Additional AUD cost added on top of the product''s range upgrade price when this colour is chosen. NULL = no extra cost.';
