-- Advanced CRM tables: lead status/tags per client, admin notes, follow-up tasks.
-- STATUS: APPLIED to production on 2026-05-09. Kept here for repo/source-of-truth
-- parity. Re-running is safe (all DDL is `if not exists` / `create or replace`).

create table if not exists public.client_crm_profile (
    client_id uuid primary key references auth.users(id) on delete cascade,
    lead_status text not null default 'new',
    lead_temperature text not null default 'warm',
    tags text[] not null default '{}',
    owner_id uuid,
    last_contacted_at timestamptz,
    next_follow_up_at timestamptz,
    lifetime_value numeric(12,2) not null default 0,
    updated_at timestamptz not null default now()
);

create table if not exists public.client_notes (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references auth.users(id) on delete cascade,
    author_id uuid,
    body text not null,
    pinned boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists client_notes_client_idx on public.client_notes(client_id, created_at desc);

create table if not exists public.client_tasks (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references auth.users(id) on delete cascade,
    title text not null,
    detail text,
    due_at timestamptz,
    completed_at timestamptz,
    assignee_id uuid,
    created_by uuid,
    priority text not null default 'normal',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists client_tasks_client_idx on public.client_tasks(client_id, due_at);
create index if not exists client_tasks_open_idx on public.client_tasks(completed_at) where completed_at is null;

alter table public.client_crm_profile enable row level security;
alter table public.client_notes enable row level security;
alter table public.client_tasks enable row level security;

-- Admins/staff: full access. Helper relies on existing profiles.role column.
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

drop policy if exists crm_profile_admin_all on public.client_crm_profile;
create policy crm_profile_admin_all on public.client_crm_profile
    for all using (public.is_admin_or_staff(auth.uid()))
    with check (public.is_admin_or_staff(auth.uid()));

drop policy if exists client_notes_admin_all on public.client_notes;
create policy client_notes_admin_all on public.client_notes
    for all using (public.is_admin_or_staff(auth.uid()))
    with check (public.is_admin_or_staff(auth.uid()));

drop policy if exists client_tasks_admin_all on public.client_tasks;
create policy client_tasks_admin_all on public.client_tasks
    for all using (public.is_admin_or_staff(auth.uid()))
    with check (public.is_admin_or_staff(auth.uid()));
