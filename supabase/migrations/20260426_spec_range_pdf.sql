-- Add pdf_url column to spec_range_tiers so admins can upload a PDF document per spec range.
alter table public.spec_range_tiers
    add column if not exists pdf_url text;
