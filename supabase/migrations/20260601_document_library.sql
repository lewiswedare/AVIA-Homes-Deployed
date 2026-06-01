-- Shared "stock" document library: reusable files (brochures, standard contracts,
-- templates, marketing collateral, etc.) that admins upload once and staff can pick
-- from when sending to any client. These are NOT tied to a specific client — they live
-- separately from the per-client `documents` table.

create table if not exists public.document_library (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    category text not null default 'Templates',
    description text,
    file_url text not null,
    file_size text not null default '',
    file_type text not null default 'application/pdf',
    uploaded_by uuid references auth.users(id) on delete set null,
    sort_order int not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists document_library_category_idx on public.document_library(category);
create index if not exists document_library_sort_idx on public.document_library(sort_order, created_at desc);

alter table public.document_library enable row level security;

-- Admins & staff can read and manage the shared stock library.
drop policy if exists document_library_staff_all on public.document_library;
create policy document_library_staff_all on public.document_library
    for all using (public.is_admin_or_staff(auth.uid()))
    with check (public.is_admin_or_staff(auth.uid()));
