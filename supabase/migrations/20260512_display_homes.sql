-- Display Homes feature: clients browse display home listings and request visits.
-- Admins/staff manage listings and the visit pipeline.

create or replace function public.is_admin_or_staff(uid uuid)
returns boolean
language sql
stable
as $$
    select exists (
        select 1 from public.profiles p
        where p.id = uid::text
          and lower(coalesce(p.role, '')) in (
              'admin','superadmin','super_admin','salesadmin','sales_admin',
              'staff','preconstruction','pre_construction','buildingsupport','building_support','partner','salespartner','sales_partner'
          )
    );
$$;

-- Listings -------------------------------------------------------------------

create table if not exists public.display_homes (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    estate text,
    address text,
    suburb text,
    description text,
    bedrooms int,
    bathrooms int,
    garages int,
    square_meters numeric(10,2),
    home_design_id text,
    image_urls text[] not null default '{}',
    features text[] not null default '{}',
    opening_hours text,
    contact_phone text,
    is_active boolean not null default true,
    sort_order int not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists display_homes_active_idx
    on public.display_homes(is_active, sort_order);

alter table public.display_homes enable row level security;

-- Anyone signed in can read active listings; admins/staff manage.
drop policy if exists display_homes_read on public.display_homes;
create policy display_homes_read on public.display_homes
    for select using (auth.role() = 'authenticated');

drop policy if exists display_homes_admin_write on public.display_homes;
create policy display_homes_admin_write on public.display_homes
    for all using (public.is_admin_or_staff(auth.uid()))
    with check (public.is_admin_or_staff(auth.uid()));

-- Visits ---------------------------------------------------------------------

create table if not exists public.display_home_visits (
    id uuid primary key default gen_random_uuid(),
    display_home_id uuid not null references public.display_homes(id) on delete cascade,
    client_id uuid references auth.users(id) on delete set null,
    requested_at timestamptz not null,
    duration_minutes int not null default 45,
    status text not null default 'pending',
        -- pending | confirmed | completed | cancelled | no_show | rescheduled
    attendee_name text,
    attendee_email text,
    attendee_phone text,
    party_size int not null default 1,
    notes text,
    assigned_staff_id uuid,
    admin_notes text,
    confirmed_at timestamptz,
    completed_at timestamptz,
    cancelled_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists display_home_visits_home_idx
    on public.display_home_visits(display_home_id, requested_at desc);

create index if not exists display_home_visits_client_idx
    on public.display_home_visits(client_id, requested_at desc);

create index if not exists display_home_visits_status_idx
    on public.display_home_visits(status, requested_at);

alter table public.display_home_visits enable row level security;

-- Admins/staff: full access.
drop policy if exists display_home_visits_admin_all on public.display_home_visits;
create policy display_home_visits_admin_all on public.display_home_visits
    for all using (public.is_admin_or_staff(auth.uid()))
    with check (public.is_admin_or_staff(auth.uid()));

-- Clients: read own visits.
drop policy if exists display_home_visits_client_read on public.display_home_visits;
create policy display_home_visits_client_read on public.display_home_visits
    for select using (auth.uid() = client_id);

-- Clients: create a visit record for themselves.
drop policy if exists display_home_visits_client_insert on public.display_home_visits;
create policy display_home_visits_client_insert on public.display_home_visits
    for insert with check (auth.uid() = client_id);

-- Clients: cancel/edit their own pending or confirmed visit.
drop policy if exists display_home_visits_client_update on public.display_home_visits;
create policy display_home_visits_client_update on public.display_home_visits
    for update using (auth.uid() = client_id)
    with check (auth.uid() = client_id);

-- Touch updated_at automatically.
create or replace function public.touch_display_home_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists trg_display_homes_touch on public.display_homes;
create trigger trg_display_homes_touch
    before update on public.display_homes
    for each row execute function public.touch_display_home_updated_at();

drop trigger if exists trg_display_home_visits_touch on public.display_home_visits;
create trigger trg_display_home_visits_touch
    before update on public.display_home_visits
    for each row execute function public.touch_display_home_updated_at();

-- Realtime
alter publication supabase_realtime add table public.display_homes;
alter publication supabase_realtime add table public.display_home_visits;
