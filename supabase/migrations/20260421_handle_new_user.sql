-- Auto-create a profiles row whenever a new auth.users row is created.
-- This runs with security definer so it bypasses RLS and ALWAYS succeeds,
-- regardless of whether the new user has confirmed their email yet.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    first_name,
    last_name,
    phone,
    address,
    home_design,
    lot_number,
    role,
    profile_completed,
    assigned_client_ids
  )
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'first_name', ''),
    coalesce(new.raw_user_meta_data->>'last_name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    '',
    '',
    '',
    'Client',
    false,
    '{}'::text[]
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Make sure authenticated users can SELECT / UPDATE / INSERT their own profile
-- (these are idempotent — only created if missing).

alter table public.profiles enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'Users can view own profile'
  ) then
    create policy "Users can view own profile"
      on public.profiles for select
      using (auth.uid() = id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'Users can update own profile'
  ) then
    create policy "Users can update own profile"
      on public.profiles for update
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'Users can insert own profile'
  ) then
    create policy "Users can insert own profile"
      on public.profiles for insert
      with check (auth.uid() = id);
  end if;
end$$;

-- Backfill: create profiles for any existing auth users that are missing one.
insert into public.profiles (id, email, first_name, last_name, phone, address, home_design, lot_number, role, profile_completed, assigned_client_ids)
select
  u.id,
  coalesce(u.email, ''),
  coalesce(u.raw_user_meta_data->>'first_name', ''),
  coalesce(u.raw_user_meta_data->>'last_name', ''),
  coalesce(u.raw_user_meta_data->>'phone', ''),
  '', '', '',
  'Client',
  false,
  '{}'::text[]
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;
