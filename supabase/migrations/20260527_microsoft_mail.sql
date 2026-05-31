-- Microsoft 365 mail sending + open tracking.
--
-- Three tables:
--   microsoft_connections  — OAuth tokens (refresh/access) per staff user. SERVICE-ROLE ONLY:
--                            RLS is enabled with NO policies, so anon/authenticated clients can
--                            never read refresh tokens. The edge function uses the service role.
--   microsoft_accounts     — non-sensitive connection status (email, display name) the app reads
--                            to show "Connected as …". Owner + admin/staff may read.
--   email_sends            — every email sent from the app + its open-tracking status.
--
-- Re-declares the is_admin_or_staff helper so this migration runs independently.

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

-- ── OAuth tokens (service-role only) ───────────────────────────────────────────
create table if not exists public.microsoft_connections (
    user_id uuid primary key references auth.users(id) on delete cascade,
    ms_user_id text,
    email text,
    display_name text,
    refresh_token text not null,
    access_token text,
    token_expires_at timestamptz,
    connected_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.microsoft_connections enable row level security;
-- Intentionally NO policies: only the service role (edge function) can touch tokens.

-- ── Non-sensitive connection status (app-readable) ─────────────────────────────
create table if not exists public.microsoft_accounts (
    user_id uuid primary key references auth.users(id) on delete cascade,
    email text,
    display_name text,
    connected_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.microsoft_accounts enable row level security;

drop policy if exists ms_accounts_owner_read on public.microsoft_accounts;
create policy ms_accounts_owner_read on public.microsoft_accounts
    for select using (auth.uid() = user_id or public.is_admin_or_staff(auth.uid()));

-- ── Sent emails + open tracking ────────────────────────────────────────────────
create table if not exists public.email_sends (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references auth.users(id) on delete cascade,
    sender_id uuid,
    sender_email text,
    sender_name text,
    to_email text not null,
    subject text not null,
    body_preview text,
    document_id text,
    document_name text,
    document_url text,
    status text not null default 'sent',     -- sent | failed
    error text,
    open_count integer not null default 0,
    first_opened_at timestamptz,
    last_opened_at timestamptz,
    created_at timestamptz not null default now()
);

create index if not exists email_sends_client_idx
    on public.email_sends(client_id, created_at desc);

alter table public.email_sends enable row level security;

drop policy if exists email_sends_admin_all on public.email_sends;
create policy email_sends_admin_all on public.email_sends
    for all using (public.is_admin_or_staff(auth.uid()))
    with check (public.is_admin_or_staff(auth.uid()));
