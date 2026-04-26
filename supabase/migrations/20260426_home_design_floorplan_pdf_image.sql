-- Allow admins to upload a hero image that displays behind the floorplan PDF download block.
alter table public.home_designs
    add column if not exists floorplan_pdf_url text;

alter table public.home_designs
    add column if not exists floorplan_pdf_image_url text;
