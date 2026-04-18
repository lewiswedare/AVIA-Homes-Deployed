-- Message attachments support
-- Run this in your Supabase SQL Editor

alter table public.messages
  add column if not exists attachment_url text;

alter table public.messages
  add column if not exists attachment_type text;

-- Allow messages with empty content when an attachment is present
alter table public.messages
  alter column content drop not null;

alter table public.messages
  alter column content set default '';

-- Ensure the catalog-images bucket (used for uploads) is reusable for chat
-- attachments (handled by existing storage policies).
