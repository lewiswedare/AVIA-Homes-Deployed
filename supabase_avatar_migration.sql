-- Avatar upload support
-- Run this in your Supabase SQL Editor

-- 1) Add avatar_url column to profiles table (if missing)
alter table public.profiles
  add column if not exists avatar_url text;

-- 2) Add display_title column to profiles (used by staff editor)
alter table public.profiles
  add column if not exists display_title text;

-- 3) Ensure the catalog-images storage bucket exists and is public
insert into storage.buckets (id, name, public)
values ('catalog-images', 'catalog-images', true)
on conflict (id) do update set public = true;

-- 4) Storage policies so authenticated users can upload & read avatars
drop policy if exists "Public read for catalog-images" on storage.objects;
create policy "Public read for catalog-images"
  on storage.objects for select
  to public
  using (bucket_id = 'catalog-images');

drop policy if exists "Authenticated upload to catalog-images" on storage.objects;
create policy "Authenticated upload to catalog-images"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'catalog-images');

drop policy if exists "Authenticated update catalog-images" on storage.objects;
create policy "Authenticated update catalog-images"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'catalog-images');

drop policy if exists "Authenticated delete catalog-images" on storage.objects;
create policy "Authenticated delete catalog-images"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'catalog-images');
