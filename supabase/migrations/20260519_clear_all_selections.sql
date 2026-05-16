-- Reset every build's selections so all clients start from zero.
-- Per the new product-driven flow, nothing should be pre-selected — clients
-- must deliberately pick a product + colour for each spec item.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'build_spec_selections'
    ) THEN
        DELETE FROM public.build_spec_selections;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'build_colour_selections'
    ) THEN
        DELETE FROM public.build_colour_selections;
    END IF;
END $$;
