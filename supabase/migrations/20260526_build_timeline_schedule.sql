-- Build timeline: schedule columns on builds + build_stages,
-- plus build_milestones and build_reminders tables used by the admin
-- Timeline editor and the client Build Progress timeline.
--
-- All DDL is `if not exists` / `create or replace` so re-running is safe.

-- 1. Schedule columns on builds (Estimated/Actual Start & Completion)
alter table if exists public.builds
    add column if not exists estimated_start_date       timestamptz,
    add column if not exists estimated_completion_date  timestamptz,
    add column if not exists actual_start_date          timestamptz,
    add column if not exists actual_completion_date     timestamptz;

-- 2. Per-stage schedule columns
alter table if exists public.build_stages
    add column if not exists estimated_start_date timestamptz,
    add column if not exists estimated_end_date   timestamptz,
    add column if not exists actual_start_date    timestamptz,
    add column if not exists actual_end_date      timestamptz;

-- 3. Milestones table
create table if not exists public.build_milestones (
    id                          text primary key,
    build_id                    text not null,
    build_stage_id              text not null,
    title                       text not null,
    description                 text not null default '',
    due_date                    timestamptz,
    completed_at                timestamptz,
    status                      text not null default 'pending',
    requires_client_action      boolean not null default false,
    client_action_description   text,
    created_at                  timestamptz not null default now()
);

create index if not exists build_milestones_build_idx
    on public.build_milestones(build_id, due_date);
create index if not exists build_milestones_stage_idx
    on public.build_milestones(build_stage_id);

-- 4. Reminders table
create table if not exists public.build_reminders (
    id              text primary key,
    build_id        text not null,
    milestone_id    text,
    client_id       text not null,
    title           text not null,
    message         text not null default '',
    reminder_date   timestamptz,
    is_read         boolean not null default false,
    created_at      timestamptz not null default now()
);

create index if not exists build_reminders_client_idx
    on public.build_reminders(client_id, reminder_date);
create index if not exists build_reminders_build_idx
    on public.build_reminders(build_id);

-- 5. RLS — admins/staff full access, clients read their own
alter table public.build_milestones enable row level security;
alter table public.build_reminders  enable row level security;

drop policy if exists build_milestones_admin_all on public.build_milestones;
create policy build_milestones_admin_all
    on public.build_milestones
    for all
    using (
        exists (
            select 1 from public.profiles p
            where p.id = auth.uid()::text
              and lower(coalesce(p.role, '')) in ('admin','staff','super_admin','sales','preconstruction','building_support')
        )
    )
    with check (
        exists (
            select 1 from public.profiles p
            where p.id = auth.uid()::text
              and lower(coalesce(p.role, '')) in ('admin','staff','super_admin','sales','preconstruction','building_support')
        )
    );

drop policy if exists build_milestones_client_read on public.build_milestones;
create policy build_milestones_client_read
    on public.build_milestones
    for select
    using (
        exists (
            select 1 from public.builds b
            where b.id = build_milestones.build_id
              and (
                  b.client_id = auth.uid()::text
                  or auth.uid()::text = any(coalesce(b.additional_client_ids, '{}'::text[]))
              )
        )
    );

drop policy if exists build_reminders_admin_all on public.build_reminders;
create policy build_reminders_admin_all
    on public.build_reminders
    for all
    using (
        exists (
            select 1 from public.profiles p
            where p.id = auth.uid()::text
              and lower(coalesce(p.role, '')) in ('admin','staff','super_admin','sales','preconstruction','building_support')
        )
    )
    with check (
        exists (
            select 1 from public.profiles p
            where p.id = auth.uid()::text
              and lower(coalesce(p.role, '')) in ('admin','staff','super_admin','sales','preconstruction','building_support')
        )
    );

drop policy if exists build_reminders_client_rw on public.build_reminders;
create policy build_reminders_client_rw
    on public.build_reminders
    for all
    using (client_id = auth.uid()::text)
    with check (client_id = auth.uid()::text);
