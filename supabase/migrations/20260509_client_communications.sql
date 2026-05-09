-- Communication log for CRM: track admin↔client interactions (calls, emails, meetings, sms, notes).
-- Self-contained: re-declares the is_admin_or_staff helper so this migration runs
-- independently of the CRM migration.
-- STATUS: APPLIED to production on 2026-05-09. Kept here for repo/source-of-truth
-- parity. Re-running is safe (all DDL is `if not exists` / `create or replace`).

create or replace function public.is_admin_or_staff(uid uuid)
returns boolean
language sql
stable
as $$
    -- profiles.id is `text` in this schema, so cast the incoming uuid before comparing.
    select exists (
        select 1 from public.profiles p
        where p.id = uid::text
          and lower(coalesce(p.role, '')) in (
              'admin','superadmin','super_admin','salesadmin','sales_admin',
              'staff','preconstruction','pre_construction','buildingsupport','building_support','partner','salespartner','sales_partner'
          )
    );
$$;

create table if not exists public.client_communications (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references auth.users(id) on delete cascade,
    author_id uuid,
    kind text not null default 'note',
    summary text not null,
    occurred_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

create index if not exists client_comms_client_idx
    on public.client_communications(client_id, occurred_at desc);

alter table public.client_communications enable row level security;

drop policy if exists client_comms_admin_all on public.client_communications;
create policy client_comms_admin_all on public.client_communications
    for all using (public.is_admin_or_staff(auth.uid()))
    with check (public.is_admin_or_staff(auth.uid()));
