-- Add an `is_fixed_inclusion` flag to spec_items so admins can mark certain
-- items as fixed (no tier upgrade, no colour variants). End users see these
-- as "Included" only — not tappable, no choice required.

alter table public.spec_items
    add column if not exists is_fixed_inclusion boolean not null default false;
