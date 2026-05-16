-- Ensure admins can upsert spec_categories rows (including cover image_url).
-- Earlier installs may have spec_categories created without explicit RLS write
-- policies, which causes the cover-image upsert from the admin panel to fail
-- silently. This migration:
--   1. Guarantees the image_url column exists (idempotent).
--   2. Enables RLS.
--   3. Adds public read + admin write policies that mirror spec_range_tiers.

alter table public.spec_categories
    add column if not exists image_url text;

alter table public.spec_categories enable row level security;

do $$
begin
    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'spec_categories'
          and policyname = 'Spec categories readable by everyone'
    ) then
        create policy "Spec categories readable by everyone"
            on public.spec_categories for select
            using (true);
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'spec_categories'
          and policyname = 'Admins can insert spec categories'
    ) then
        create policy "Admins can insert spec categories"
            on public.spec_categories for insert
            with check (
                exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid()::text and p.role = 'Admin'
                )
            );
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'spec_categories'
          and policyname = 'Admins can update spec categories'
    ) then
        create policy "Admins can update spec categories"
            on public.spec_categories for update
            using (
                exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid()::text and p.role = 'Admin'
                )
            )
            with check (
                exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid()::text and p.role = 'Admin'
                )
            );
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'spec_categories'
          and policyname = 'Admins can delete spec categories'
    ) then
        create policy "Admins can delete spec categories"
            on public.spec_categories for delete
            using (
                exists (
                    select 1 from public.profiles p
                    where p.id = auth.uid()::text and p.role = 'Admin'
                )
            );
    end if;
end$$;
