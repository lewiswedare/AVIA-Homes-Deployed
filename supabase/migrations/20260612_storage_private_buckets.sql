-- ============================================================
-- STORAGE LOCKDOWN — private buckets + signed-URL access
-- ============================================================
-- The `documents` and `contracts` buckets were public: anyone with a
-- link could open client contracts, invoices and build documents.
-- This migration:
--   1. Makes both buckets private (creates them if missing).
--   2. Replaces any old object policies for them with a strict set:
--      • Admin/staff: full access to both buckets.
--      • Clients: read documents that belong to THEIR builds, read
--        contracts in THEIR folder, and upload/replace their own
--        signed contract files.
-- The apps now exchange short-lived signed URLs instead of public ones.
-- Stored `file_url`/`contract_url` values keep their public-style format
-- (they encode bucket + path) and both apps convert them at display time.
--
-- Requires: public.is_admin_or_staff(uuid) from 20260612_security_lockdown.sql.

-- 1. Ensure the buckets exist and are PRIVATE.
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do update set public = false;

insert into storage.buckets (id, name, public)
values ('contracts', 'contracts', false)
on conflict (id) do update set public = false;

-- 2. Drop every existing object policy that targets these two buckets
--    (they were created manually with unknown names / permissive rules).
do $$
declare
    pol record;
begin
    for pol in
        select policyname
        from pg_policies
        where schemaname = 'storage'
          and tablename = 'objects'
          and (
               coalesce(qual, '')       like '%''documents''%'
            or coalesce(with_check, '') like '%''documents''%'
            or coalesce(qual, '')       like '%''contracts''%'
            or coalesce(with_check, '') like '%''contracts''%'
          )
    loop
        execute format('drop policy %I on storage.objects', pol.policyname);
    end loop;
end$$;

-- 3. Admin/staff: full access to both buckets.
create policy "documents_staff_all" on storage.objects
    for all
    using (bucket_id = 'documents' and public.is_admin_or_staff(auth.uid()))
    with check (bucket_id = 'documents' and public.is_admin_or_staff(auth.uid()));

create policy "contracts_staff_all" on storage.objects
    for all
    using (bucket_id = 'contracts' and public.is_admin_or_staff(auth.uid()))
    with check (bucket_id = 'contracts' and public.is_admin_or_staff(auth.uid()));

-- 4. Clients: read documents that belong to their own builds.
--    Paths used by the apps:
--      {buildId}/{uuid}_{file}            (per-build documents)
--      builds/{buildId}/spec_summary.pdf  (generated spec/colour PDFs)
create policy "documents_client_read" on storage.objects
    for select
    using (
        bucket_id = 'documents'
        and exists (
            select 1
            from public.builds b
            where (
                    b.client_id::text = auth.uid()::text
                 or auth.uid()::text = any (coalesce(b.additional_client_ids, '{}')::text[])
                  )
              and (
                    (storage.foldername(name))[1] = b.id::text
                 or (
                        (storage.foldername(name))[1] = 'builds'
                    and (storage.foldername(name))[2] = b.id::text
                    )
                  )
        )
    );

-- 5. Clients: read contracts that belong to them.
--    Paths used by the apps:
--      {clientId}/{contractId}/original_*.pdf   (signature flow)
--      {clientId}/{contractId}/signed_*.pdf     (signature flow)
--      contracts/{contractId}/{file}            (pipeline contracts)
create policy "contracts_client_read" on storage.objects
    for select
    using (
        bucket_id = 'contracts'
        and (
            (storage.foldername(name))[1] = auth.uid()::text
            or (
                (storage.foldername(name))[1] = 'contracts'
                and exists (
                    select 1
                    from public.contracts c
                    where c.id::text = (storage.foldername(name))[2]
                      and c.client_id::text = auth.uid()::text
                )
            )
        )
    );

-- 6. Clients: upload / replace files ONLY inside their own contracts folder
--    (used when a client uploads the signed contract PDF).
create policy "contracts_client_insert" on storage.objects
    for insert
    with check (
        bucket_id = 'contracts'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

create policy "contracts_client_update" on storage.objects
    for update
    using (
        bucket_id = 'contracts'
        and (storage.foldername(name))[1] = auth.uid()::text
    )
    with check (
        bucket_id = 'contracts'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
