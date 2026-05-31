-- Admin task management: general (unassigned) manual tasks + manual completion
-- of automated sales-workflow steps.

-- 1. Allow tasks that aren't tied to a specific client (general team to-dos).
alter table public.client_tasks alter column client_id drop not null;

-- 2. Manual completions of automated lifecycle/workflow requirements.
--    Each row marks one StageRequirement (by stable requirement id) as done for
--    a client, overriding the auto-detected state.
create table if not exists public.client_stage_completions (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references auth.users(id) on delete cascade,
    requirement_id text not null,
    lead_status text,
    completed_at timestamptz not null default now(),
    completed_by uuid,
    created_at timestamptz not null default now(),
    unique (client_id, requirement_id)
);

create index if not exists client_stage_completions_client_idx
    on public.client_stage_completions(client_id);

alter table public.client_stage_completions enable row level security;

drop policy if exists client_stage_completions_admin_all on public.client_stage_completions;
create policy client_stage_completions_admin_all on public.client_stage_completions
    for all using (public.is_admin_or_staff(auth.uid()))
    with check (public.is_admin_or_staff(auth.uid()));
