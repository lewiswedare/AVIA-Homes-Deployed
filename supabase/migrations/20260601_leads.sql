-- Inbound leads (website, social media, referrals, etc.) for the CRM.
-- Leads are pre-account contacts that can be assigned to an admin/staff member
-- for management, and optionally converted into a registered client later.

create table if not exists public.leads (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    email text,
    phone text,
    source text not null default 'website',
    message text,
    status text not null default 'new',
    temperature text not null default 'warm',
    owner_id uuid references auth.users(id) on delete set null,
    notes text,
    converted_client_id uuid references auth.users(id) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists leads_owner_idx on public.leads(owner_id);
create index if not exists leads_status_idx on public.leads(status);
create index if not exists leads_created_idx on public.leads(created_at desc);

alter table public.leads enable row level security;

-- Admins & staff manage all leads.
drop policy if exists leads_admin_all on public.leads;
create policy leads_admin_all on public.leads
    for all using (public.is_admin_or_staff(auth.uid()))
    with check (public.is_admin_or_staff(auth.uid()));

-- Allow anonymous/public inserts so website & social capture forms can create
-- leads without an authenticated session.
drop policy if exists leads_public_insert on public.leads;
create policy leads_public_insert on public.leads
    for insert with check (true);
