-- Foundation Calls: video calls via Cal.com booked from the CRM as the primary
-- conversion goal for new leads.
--
-- Self-contained migration: re-declares the is_admin_or_staff helper.

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

create table if not exists public.client_foundation_calls (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references auth.users(id) on delete cascade,
    organizer_id uuid,
    status text not null default 'pending', -- pending | scheduled | completed | cancelled | no_show | rescheduled
    scheduled_at timestamptz,
    duration_minutes int,
    meeting_url text,
    cal_booking_id text,
    cal_booking_uid text,
    cal_event_type text,
    attendee_email text,
    attendee_name text,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index if not exists client_foundation_calls_cal_uid_idx
    on public.client_foundation_calls(cal_booking_uid)
    where cal_booking_uid is not null;

create index if not exists client_foundation_calls_client_idx
    on public.client_foundation_calls(client_id, scheduled_at desc);

create index if not exists client_foundation_calls_status_idx
    on public.client_foundation_calls(status, scheduled_at);

alter table public.client_foundation_calls enable row level security;

drop policy if exists foundation_calls_admin_all on public.client_foundation_calls;
create policy foundation_calls_admin_all on public.client_foundation_calls
    for all using (public.is_admin_or_staff(auth.uid()))
    with check (public.is_admin_or_staff(auth.uid()));

-- Clients can read their own foundation call (so they can join the meeting from the app).
drop policy if exists foundation_calls_client_read on public.client_foundation_calls;
create policy foundation_calls_client_read on public.client_foundation_calls
    for select using (auth.uid() = client_id);

-- Touch updated_at automatically.
create or replace function public.touch_foundation_call_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists trg_foundation_calls_touch on public.client_foundation_calls;
create trigger trg_foundation_calls_touch
    before update on public.client_foundation_calls
    for each row execute function public.touch_foundation_call_updated_at();
