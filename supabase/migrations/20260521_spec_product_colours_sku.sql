-- Adds a variant SKU per product colour so each colour swatch can carry its
-- own supplier SKU code, independent of the parent product SKU.

ALTER TABLE spec_product_colours
    ADD COLUMN IF NOT EXISTS sku text;

COMMENT ON COLUMN spec_product_colours.sku IS
    'Variant SKU code for this colour. NULL = no variant SKU (use the product SKU).';
