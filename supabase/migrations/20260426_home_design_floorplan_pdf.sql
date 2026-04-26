-- Add floorplan_pdf_url column to home_designs so admins can upload a floor plan PDF per design.
alter table public.home_designs
    add column if not exists floorplan_pdf_url text;
