-- Ensure spec_items has every column the iOS admin editor writes, plus RLS
-- policies that allow admins to upsert rows. Without this, `upsertSpecItem`
-- silently fails with a 400 (PGRST204 / column does not exist) and items
-- never persist to the database.

-- 1. Ensure base table exists.
create table if not exists public.spec_items (
    id text primary key,
    category_id text not null,
    name text not null,
    volos_description text not null default '',
    messina_description text not null default '',
    portobello_description text not null default '',
    is_upgradeable boolean default false,
    image_url text,
    sort_order integer default 0,
    updated_at timestamptz not null default now()
);

-- 2. Add cost columns the iOS row encodes (will no-op if they already exist).
alter table public.spec_items
    add column if not exists volos_cost numeric,
    add column if not exists messina_cost numeric,
    add column if not exists portobello_cost numeric,
    add column if not exists volos_to_messina_cost numeric,
    add column if not exists volos_to_portobello_cost numeric,
    add column if not exists messina_to_portobello_cost numeric,
    add column if not exists is_upgradeable boolean default false,
    add column if not exists image_url text,
    add column if not exists sort_order integer default 0,
    add column if not exists updated_at timestamptz not null default now();

-- 3. Spec item images table (used for tier-specific overrides).
create table if not exists public.spec_item_images (
    spec_item_id text primary key references public.spec_items(id) on delete cascade,
    base_image_url text,
    tier_images jsonb,
    updated_at timestamptz not null default now()
);

-- 4. Spec → colour mapping table.
create table if not exists public.spec_to_colour_mapping (
    spec_item_id text primary key references public.spec_items(id) on delete cascade,
    colour_category_ids text[] not null default '{}',
    updated_at timestamptz not null default now()
);

-- 5. Enable RLS.
alter table public.spec_items enable row level security;
alter table public.spec_item_images enable row level security;
alter table public.spec_to_colour_mapping enable row level security;

-- 6. Policies: public read, admin write — applied to all three tables.
do $$
declare
    tbl text;
begin
    foreach tbl in array array['spec_items', 'spec_item_images', 'spec_to_colour_mapping']
    loop
        if not exists (
            select 1 from pg_policies
            where schemaname = 'public' and tablename = tbl
              and policyname = tbl || ' readable by everyone'
        ) then
            execute format(
                'create policy %I on public.%I for select using (true)',
                tbl || ' readable by everyone', tbl
            );
        end if;

        if not exists (
            select 1 from pg_policies
            where schemaname = 'public' and tablename = tbl
              and policyname = 'Admins can insert ' || tbl
        ) then
            execute format(
                'create policy %I on public.%I for insert with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''Admin''))',
                'Admins can insert ' || tbl, tbl
            );
        end if;

        if not exists (
            select 1 from pg_policies
            where schemaname = 'public' and tablename = tbl
              and policyname = 'Admins can update ' || tbl
        ) then
            execute format(
                'create policy %I on public.%I for update using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''Admin'')) with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''Admin''))',
                'Admins can update ' || tbl, tbl
            );
        end if;

        if not exists (
            select 1 from pg_policies
            where schemaname = 'public' and tablename = tbl
              and policyname = 'Admins can delete ' || tbl
        ) then
            execute format(
                'create policy %I on public.%I for delete using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''Admin''))',
                'Admins can delete ' || tbl, tbl
            );
        end if;
    end loop;
end$$;

-- 7. Touch updated_at on every write.
create or replace function public.touch_spec_items_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists trg_spec_items_updated_at on public.spec_items;
create trigger trg_spec_items_updated_at
    before update on public.spec_items
    for each row execute function public.touch_spec_items_updated_at();

drop trigger if exists trg_spec_item_images_updated_at on public.spec_item_images;
create trigger trg_spec_item_images_updated_at
    before update on public.spec_item_images
    for each row execute function public.touch_spec_items_updated_at();

drop trigger if exists trg_spec_to_colour_mapping_updated_at on public.spec_to_colour_mapping;
create trigger trg_spec_to_colour_mapping_updated_at
    before update on public.spec_to_colour_mapping
    for each row execute function public.touch_spec_items_updated_at();
