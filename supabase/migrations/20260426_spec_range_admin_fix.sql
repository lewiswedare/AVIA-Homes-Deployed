-- Make sure the spec_range_tiers table has every column the iOS admin editor
-- writes, plus RLS policies that allow admins to upsert rows, plus a public
-- catalog-images storage bucket with policies for admin uploads.

-- 1. Ensure the table exists with the full shape.
create table if not exists public.spec_range_tiers (
    tier text primary key,
    hero_image_url text not null default '',
    summary text not null default '',
    highlights jsonb not null default '[]'::jsonb,
    room_images jsonb not null default '[]'::jsonb,
    partner_logos jsonb,
    pdf_url text,
    pdf_preview_image_url text,
    updated_at timestamptz not null default now()
);

-- 2. Add any columns that may be missing on existing installs.
alter table public.spec_range_tiers
    add column if not exists hero_image_url text not null default '',
    add column if not exists summary text not null default '',
    add column if not exists highlights jsonb not null default '[]'::jsonb,
    add column if not exists room_images jsonb not null default '[]'::jsonb,
    add column if not exists partner_logos jsonb,
    add column if not exists pdf_url text,
    add column if not exists pdf_preview_image_url text,
    add column if not exists updated_at timestamptz not null default now();

-- 3. Enable RLS and set policies.
alter table public.spec_range_tiers enable row level security;

do $$
begin
    -- Anyone authenticated can read spec ranges.
    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'spec_range_tiers'
          and policyname = 'Spec ranges readable by everyone'
    ) then
        create policy "Spec ranges readable by everyone"
            on public.spec_range_tiers for select
            using (true);
    end if;

    -- Admins can insert.
    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'spec_range_tiers'
          and policyname = 'Admins can insert spec ranges'
    ) then
        create policy "Admins can insert spec ranges"
            on public.spec_range_tiers for insert
            with check (
                exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid() and p.role = 'Admin'
                )
            );
    end if;

    -- Admins can update.
    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'spec_range_tiers'
          and policyname = 'Admins can update spec ranges'
    ) then
        create policy "Admins can update spec ranges"
            on public.spec_range_tiers for update
            using (
                exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid() and p.role = 'Admin'
                )
            )
            with check (
                exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid() and p.role = 'Admin'
                )
            );
    end if;

    -- Admins can delete (used when wiping rows).
    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'spec_range_tiers'
          and policyname = 'Admins can delete spec ranges'
    ) then
        create policy "Admins can delete spec ranges"
            on public.spec_range_tiers for delete
            using (
                exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid() and p.role = 'Admin'
                )
            );
    end if;
end$$;

-- 4. Storage bucket for catalog assets (images, PDFs). Public read, admin write.
insert into storage.buckets (id, name, public)
values ('catalog-images', 'catalog-images', true)
on conflict (id) do update set public = true;

do $$
begin
    if not exists (
        select 1 from pg_policies
        where schemaname = 'storage' and tablename = 'objects'
          and policyname = 'Catalog images public read'
    ) then
        create policy "Catalog images public read"
            on storage.objects for select
            using (bucket_id = 'catalog-images');
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname = 'storage' and tablename = 'objects'
          and policyname = 'Catalog images admin insert'
    ) then
        create policy "Catalog images admin insert"
            on storage.objects for insert
            with check (
                bucket_id = 'catalog-images'
                and exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid() and p.role = 'Admin'
                )
            );
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname = 'storage' and tablename = 'objects'
          and policyname = 'Catalog images admin update'
    ) then
        create policy "Catalog images admin update"
            on storage.objects for update
            using (
                bucket_id = 'catalog-images'
                and exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid() and p.role = 'Admin'
                )
            )
            with check (
                bucket_id = 'catalog-images'
                and exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid() and p.role = 'Admin'
                )
            );
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname = 'storage' and tablename = 'objects'
          and policyname = 'Catalog images admin delete'
    ) then
        create policy "Catalog images admin delete"
            on storage.objects for delete
            using (
                bucket_id = 'catalog-images'
                and exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid() and p.role = 'Admin'
                )
            );
    end if;
end$$;

-- 5. Touch updated_at on every write.
create or replace function public.touch_spec_range_tiers_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists trg_spec_range_tiers_updated_at on public.spec_range_tiers;
create trigger trg_spec_range_tiers_updated_at
    before update on public.spec_range_tiers
    for each row execute function public.touch_spec_range_tiers_updated_at();

-- 6. Seed empty rows for the three tiers if the table is empty so admins see
-- a starting point in the editor.
insert into public.spec_range_tiers (tier, hero_image_url, summary, highlights, room_images)
values
    ('volos', '', '', '[]'::jsonb, '[]'::jsonb),
    ('messina', '', '', '[]'::jsonb, '[]'::jsonb),
    ('portobello', '', '', '[]'::jsonb, '[]'::jsonb)
on conflict (tier) do nothing;
