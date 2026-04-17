-- Build range upgrade requests
-- Tracks full spec range upgrade requests per build with a two-step confirmation flow:
--   1. client requests and accepts a range upgrade (status: pending_client -> client_accepted)
--   2. admin gives final approval which applies the tier change (status: admin_approved)
-- Clients may also decline (status: client_declined).

create table if not exists public.build_range_upgrade_requests (
    id uuid primary key default gen_random_uuid(),
    build_id uuid not null references public.builds(id) on delete cascade,
    from_tier text not null,
    to_tier text not null,
    cost numeric not null default 0,
    status text not null default 'pending_client',
    client_notes text,
    admin_notes text,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_brur_build on public.build_range_upgrade_requests(build_id);
create index if not exists idx_brur_status on public.build_range_upgrade_requests(status);

alter table public.build_range_upgrade_requests enable row level security;

drop policy if exists "build_range_upgrade_requests_all" on public.build_range_upgrade_requests;
create policy "build_range_upgrade_requests_all"
on public.build_range_upgrade_requests
for all
using (true)
with check (true);
