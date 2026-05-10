-- Clean migration to the per-product colour swatches model.
--
-- Before this migration:
--   * `colour_categories` held shared, standalone colour palettes.
--   * `spec_to_colour_mapping` linked spec_items -> shared colour_categories.
--   * `build_colour_selections` referenced (build_id, colour_category_id, colour_option_id).
--
-- After this migration:
--   * Each spec item owns its own colour palette stored as a `colour_categories`
--     row whose id is `spec_<spec_item_id>_colours`.
--   * `spec_to_colour_mapping` only ever links a spec item to its own
--     per-product palette (or has no row, meaning the product has no colours).
--   * Stale shared colour palettes are deleted.
--   * Old `build_colour_selections` rows are cleared because per the product
--     decision, existing in-flight builds are NOT carried over.
--
-- This migration is idempotent. Run it once and the system is on the new model.
-- Old builds are intentionally NOT preserved.
--
-- IMPORTANT: this destroys any historical client colour picks. Confirmed
-- acceptable because the customer said "old builds aren't important".
--
-- ---------------------------------------------------------------------------
-- 1. Migrate every shared (spec_item_id -> colour_category) link into a
--    per-product colour palette `spec_<spec_item_id>_colours`.
-- ---------------------------------------------------------------------------

do $$
declare
    map_row record;
    src_options jsonb;
    src_category record;
    per_product_id text;
    merged_options jsonb;
    existing_options jsonb;
    spec_name text;
    next_sort int;
begin
    -- Skip cleanly if the legacy tables don't exist yet (fresh db).
    if not exists (
        select 1 from information_schema.tables
        where table_schema = 'public' and table_name = 'spec_to_colour_mapping'
    ) then
        raise notice 'spec_to_colour_mapping not present, skipping migration body';
        return;
    end if;

    if not exists (
        select 1 from information_schema.tables
        where table_schema = 'public' and table_name = 'colour_categories'
    ) then
        raise notice 'colour_categories not present, skipping migration body';
        return;
    end if;

    -- Walk every existing (spec_item_id, colour_category_id) pairing.
    for map_row in
        select stcm.spec_item_id, unnest(stcm.colour_category_ids) as cat_id
        from public.spec_to_colour_mapping stcm
    loop
        -- Skip per-product palettes; they're already in the right shape.
        if map_row.cat_id like 'spec\_%\_colours' escape '\' then
            continue;
        end if;

        -- Pull the shared category we're migrating from.
        select id, name, icon, section, note, image_url, options,
               default_option_cost, applicable_tiers
          into src_category
          from public.colour_categories
         where id = map_row.cat_id;

        if not found then
            continue;
        end if;

        src_options := coalesce(src_category.options, '[]'::jsonb);

        per_product_id := 'spec_' || map_row.spec_item_id || '_colours';

        select name into spec_name
          from public.spec_items
         where id = map_row.spec_item_id;
        if spec_name is null then
            spec_name := src_category.name;
        end if;

        -- Merge into any existing per-product palette so we don't lose options
        -- when a spec item was previously linked to multiple shared categories.
        select options into existing_options
          from public.colour_categories
         where id = per_product_id;

        if existing_options is null then
            merged_options := src_options;
            select coalesce(max(sort_order), 0) + 1 into next_sort
              from public.colour_categories;

            insert into public.colour_categories
                (id, name, icon, section, note, image_url, options,
                 default_option_cost, applicable_tiers, sort_order)
            values
                (per_product_id,
                 spec_name,
                 'paintpalette.fill',
                 'interior',
                 'Colours for ' || spec_name,
                 null,
                 merged_options,
                 src_category.default_option_cost,
                 src_category.applicable_tiers,
                 next_sort);
        else
            -- Append shared options that aren't already present (dedupe by id).
            merged_options := existing_options || (
                select coalesce(jsonb_agg(opt), '[]'::jsonb)
                  from jsonb_array_elements(src_options) opt
                 where not exists (
                    select 1
                      from jsonb_array_elements(existing_options) eo
                     where eo->>'id' = opt->>'id'
                 )
            );

            update public.colour_categories
               set options = merged_options
             where id = per_product_id;
        end if;
    end loop;

    -- Repoint every mapping row to its per-product palette only.
    update public.spec_to_colour_mapping stcm
       set colour_category_ids = array['spec_' || stcm.spec_item_id || '_colours']
     where exists (
        select 1 from public.colour_categories
         where id = 'spec_' || stcm.spec_item_id || '_colours'
     );

    -- Drop mapping rows where the per-product palette ended up empty.
    delete from public.spec_to_colour_mapping stcm
     where not exists (
        select 1 from public.colour_categories
         where id = 'spec_' || stcm.spec_item_id || '_colours'
     );
end$$;

-- ---------------------------------------------------------------------------
-- 2. Delete legacy shared colour categories. Anything that isn't a
--    per-product palette is no longer referenced and is removed.
-- ---------------------------------------------------------------------------

do $$
begin
    if exists (
        select 1 from information_schema.tables
        where table_schema = 'public' and table_name = 'colour_categories'
    ) then
        delete from public.colour_categories
         where id not like 'spec\_%\_colours' escape '\';
    end if;
end$$;

-- ---------------------------------------------------------------------------
-- 3. Wipe historical client colour picks. Old builds are not carried over.
-- ---------------------------------------------------------------------------

do $$
begin
    if exists (
        select 1 from information_schema.tables
        where table_schema = 'public' and table_name = 'build_colour_selections'
    ) then
        delete from public.build_colour_selections;
    end if;
end$$;
