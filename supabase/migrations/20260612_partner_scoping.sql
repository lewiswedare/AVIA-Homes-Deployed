-- Partner access scoping
--
-- Partners & SalesPartners were lumped in with staff by is_admin_or_staff(),
-- which silently granted them admin-grade access to: CRM records, leads,
-- internal tasks, the Microsoft mail pipeline, the stock document library,
-- catalog/pricing writes, and the private documents/contracts storage buckets.
--
-- Their role is "View associated client portfolios" — so this migration:
--   1. Narrows is_admin_or_staff() to actual staff roles only.
--   2. Adds an is_partner() helper.
--   3. Grants partners the narrow access they genuinely need:
--      - read the builds they referred (builds.sales_partner_id = them)
--      - read/write the package assignments they are assigned to
--
-- Run AFTER 20260612_security_lockdown.sql. All statements are idempotent.

-- ---------------------------------------------------------------------------
-- 1. is_admin_or_staff: staff means staff — partners removed
-- ---------------------------------------------------------------------------

create or replace function public.is_admin_or_staff(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.profiles p
        where p.id = uid::text
          and lower(coalesce(p.role, '')) in (
              'admin','superadmin','super_admin','salesadmin','sales_admin',
              'staff','preconstruction','pre_construction',
              'buildingsupport','building_support'
          )
    );
$$;

-- ---------------------------------------------------------------------------
-- 2. is_partner helper
-- ---------------------------------------------------------------------------

create or replace function public.is_partner(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.profiles p
        where p.id = uid::text
          and lower(coalesce(p.role, '')) in ('partner','salespartner','sales_partner')
    );
$$;

-- ---------------------------------------------------------------------------
-- 3. Partners can read the builds they referred
-- ---------------------------------------------------------------------------

do $$
begin
    if to_regclass('public.builds') is not null
       and exists (
           select 1 from information_schema.columns
           where table_schema = 'public' and table_name = 'builds'
             and column_name = 'sales_partner_id'
       ) then
        drop policy if exists builds_partner_read on public.builds;
        -- ::text on both sides keeps this valid whether the column is text or uuid.
        create policy builds_partner_read on public.builds
            for select using (
                public.is_partner(auth.uid())
                and sales_partner_id::text = auth.uid()::text
            );
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Partners can read & manage package assignments they belong to
-- ---------------------------------------------------------------------------

do $$
declare
    col_type text;
begin
    if to_regclass('public.package_assignments') is null then
        return;
    end if;

    select data_type into col_type
    from information_schema.columns
    where table_schema = 'public' and table_name = 'package_assignments'
      and column_name = 'assigned_partner_ids';

    if col_type is null then
        return;
    end if;

    drop policy if exists pa_partner_select on public.package_assignments;
    drop policy if exists pa_partner_insert on public.package_assignments;
    drop policy if exists pa_partner_update on public.package_assignments;

    if col_type = 'ARRAY' then
        execute $p$
            create policy pa_partner_select on public.package_assignments
                for select using (auth.uid()::text = any(assigned_partner_ids::text[]))
        $p$;
        execute $p$
            create policy pa_partner_insert on public.package_assignments
                for insert with check (
                    public.is_partner(auth.uid())
                    and auth.uid()::text = any(assigned_partner_ids::text[])
                )
        $p$;
        execute $p$
            create policy pa_partner_update on public.package_assignments
                for update using (auth.uid()::text = any(assigned_partner_ids::text[]))
                with check (auth.uid()::text = any(assigned_partner_ids::text[]))
        $p$;
    elsif col_type = 'jsonb' then
        execute $p$
            create policy pa_partner_select on public.package_assignments
                for select using (assigned_partner_ids ? auth.uid()::text)
        $p$;
        execute $p$
            create policy pa_partner_insert on public.package_assignments
                for insert with check (
                    public.is_partner(auth.uid())
                    and assigned_partner_ids ? auth.uid()::text
                )
        $p$;
        execute $p$
            create policy pa_partner_update on public.package_assignments
                for update using (assigned_partner_ids ? auth.uid()::text)
                with check (assigned_partner_ids ? auth.uid()::text)
        $p$;
    end if;
end $$;
