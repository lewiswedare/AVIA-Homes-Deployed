-- Add a cover image_url to spec_categories so admins can give each
-- selection category a hero image shown on the user-facing Selections screen.

alter table public.spec_categories
    add column if not exists image_url text;
