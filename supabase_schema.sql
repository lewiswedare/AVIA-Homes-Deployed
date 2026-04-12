-- AVIA Homes - Supabase Database Schema
-- Run this in your Supabase SQL Editor to create all required tables

-- 1. PROFILES TABLE
-- Stores user profile data, linked to auth.users
create table if not exists public.profiles (
  id text primary key,
  first_name text not null default '',
  last_name text not null default '',
  email text not null default '',
  phone text not null default '',
  address text not null default '',
  home_design text not null default '',
  lot_number text not null default '',
  contract_date timestamptz,
  profile_completed boolean not null default false,
  role text not null default 'Client',
  assigned_client_ids text[] not null default '{}',
  assigned_staff_id text,
  sales_partner_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. BUILDS TABLE
create table if not exists public.builds (
  id text primary key,
  client_id text not null references public.profiles(id),
  home_design text not null default '',
  lot_number text not null default '',
  estate text not null default '',
  contract_date timestamptz not null default now(),
  assigned_staff_id text not null default '',
  sales_partner_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. BUILD STAGES TABLE
create table if not exists public.build_stages (
  id text primary key,
  build_id text not null references public.builds(id) on delete cascade,
  name text not null,
  description text not null default '',
  status text not null default 'Upcoming',
  progress double precision not null default 0,
  start_date timestamptz,
  completion_date timestamptz,
  notes text,
  photo_count integer not null default 0,
  sort_order integer not null default 0
);

-- 4. PACKAGE ASSIGNMENTS TABLE
create table if not exists public.package_assignments (
  id text primary key,
  package_id text not null,
  assigned_partner_ids text[] not null default '{}',
  shared_with_client_ids text[] not null default '{}',
  client_responses jsonb not null default '[]',
  is_exclusive boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 5. SERVICE REQUESTS TABLE
create table if not exists public.service_requests (
  id text primary key,
  client_id text not null references public.profiles(id),
  title text not null,
  description text not null default '',
  category text not null default 'General',
  status text not null default 'Open',
  date_created timestamptz not null default now(),
  last_updated timestamptz not null default now(),
  responses jsonb not null default '[]',
  created_at timestamptz not null default now()
);

-- 6. CONVERSATIONS TABLE
create table if not exists public.conversations (
  id text primary key,
  participant_ids text[] not null default '{}',
  last_message text not null default '',
  last_message_date timestamptz not null default now(),
  last_sender_id text not null default '',
  unread_count integer not null default 0,
  created_at timestamptz not null default now()
);

-- 7. MESSAGES TABLE
create table if not exists public.messages (
  id text primary key,
  conversation_id text not null references public.conversations(id) on delete cascade,
  sender_id text not null,
  content text not null,
  created_at timestamptz not null default now(),
  is_read boolean not null default false
);

-- 8. NOTIFICATIONS TABLE
create table if not exists public.notifications (
  id text primary key,
  recipient_id text not null,
  sender_id text,
  sender_name text not null default '',
  type text not null default 'new_message',
  title text not null,
  message text not null,
  reference_id text,
  created_at timestamptz not null default now(),
  is_read boolean not null default false
);

-- 9. DEVICE TOKENS TABLE (for push notifications)
create table if not exists public.device_tokens (
  id text primary key,
  user_id text not null,
  token text not null,
  platform text not null default 'ios',
  updated_at timestamptz not null default now(),
  unique(user_id, token)
);

-- INDEXES for performance
create index if not exists idx_builds_client on public.builds(client_id);
create index if not exists idx_builds_staff on public.builds(assigned_staff_id);
create index if not exists idx_build_stages_build on public.build_stages(build_id);
create index if not exists idx_messages_conversation on public.messages(conversation_id);
create index if not exists idx_messages_created on public.messages(created_at);
create index if not exists idx_notifications_recipient on public.notifications(recipient_id);
create index if not exists idx_notifications_created on public.notifications(created_at desc);
create index if not exists idx_device_tokens_user on public.device_tokens(user_id);
create index if not exists idx_service_requests_client on public.service_requests(client_id);

-- ENABLE REALTIME for tables that need live sync
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.builds;
alter publication supabase_realtime add table public.build_stages;
alter publication supabase_realtime add table public.package_assignments;
alter publication supabase_realtime add table public.service_requests;
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.notifications;

-- ROW LEVEL SECURITY
alter table public.profiles enable row level security;
alter table public.builds enable row level security;
alter table public.build_stages enable row level security;
alter table public.package_assignments enable row level security;
alter table public.service_requests enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.device_tokens enable row level security;

-- RLS POLICIES

-- Profiles: everyone can read, users can update their own
create policy "Profiles are viewable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Users can insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (true);

create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using (true);

-- Builds: viewable by related users
create policy "Builds are viewable by authenticated users"
  on public.builds for select
  to authenticated
  using (true);

create policy "Staff can insert builds"
  on public.builds for insert
  to authenticated
  with check (true);

create policy "Staff can update builds"
  on public.builds for update
  to authenticated
  using (true);

-- Build Stages
create policy "Build stages are viewable by authenticated users"
  on public.build_stages for select
  to authenticated
  using (true);

create policy "Staff can manage build stages"
  on public.build_stages for all
  to authenticated
  using (true);

-- Package Assignments
create policy "Package assignments are viewable by authenticated users"
  on public.package_assignments for select
  to authenticated
  using (true);

create policy "Authenticated users can manage package assignments"
  on public.package_assignments for all
  to authenticated
  using (true);

-- Service Requests
create policy "Service requests are viewable by authenticated users"
  on public.service_requests for select
  to authenticated
  using (true);

create policy "Authenticated users can manage service requests"
  on public.service_requests for all
  to authenticated
  using (true);

-- Conversations: participants can read
create policy "Participants can view their conversations"
  on public.conversations for select
  to authenticated
  using (true);

create policy "Authenticated users can create conversations"
  on public.conversations for insert
  to authenticated
  with check (true);

create policy "Participants can update conversations"
  on public.conversations for update
  to authenticated
  using (true);

-- Messages
create policy "Participants can view messages"
  on public.messages for select
  to authenticated
  using (true);

create policy "Authenticated users can send messages"
  on public.messages for insert
  to authenticated
  with check (true);

create policy "Users can update message read status"
  on public.messages for update
  to authenticated
  using (true);

-- Notifications
create policy "Users can view their notifications"
  on public.notifications for select
  to authenticated
  using (recipient_id = auth.uid()::text OR true);

create policy "Authenticated users can create notifications"
  on public.notifications for insert
  to authenticated
  with check (true);

create policy "Users can update their notifications"
  on public.notifications for update
  to authenticated
  using (true);

-- Device Tokens
create policy "Users can manage their device tokens"
  on public.device_tokens for all
  to authenticated
  using (true);

-- TRIGGER: Auto-update updated_at timestamp
create or replace function public.update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.update_updated_at();

create trigger builds_updated_at
  before update on public.builds
  for each row execute function public.update_updated_at();

create trigger package_assignments_updated_at
  before update on public.package_assignments
  for each row execute function public.update_updated_at();
