-- Lead → Opportunity → Client progression.
-- A lead is a raw inbound enquiry. Converting it to an "opportunity" unlocks the
-- full sales workflow (a per-stage checklist the team ticks off). An opportunity
-- only becomes a "client" once a build contract has been allocated to them.

alter table public.leads
    add column if not exists kind text not null default 'lead',
    add column if not exists estimated_value numeric,
    add column if not exists expected_close_date timestamptz,
    add column if not exists workflow_completions text[] not null default '{}',
    add column if not exists converted_at timestamptz;

create index if not exists leads_kind_idx on public.leads(kind);
