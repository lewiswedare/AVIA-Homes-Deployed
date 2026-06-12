-- Security lockdown — closes the remotely-exploitable holes found in the
-- production audit:
--
--   1. PRIVILEGE ESCALATION: "Users can update own profile" allowed editing the
--      `role` column, so any client could promote themselves to Admin. A
--      trigger now blocks role changes unless the caller is an admin.
--   2. RLS BYPASS: v_build_selections_full ran with owner rights and was
--      readable by unauthenticated anon — exposing every client's selections,
--      prices and private notes. Now security_invoker + anon revoked.
--   3. CATALOG TAMPERING: 9 spec/pricing tables allowed writes from ANY
--      signed-in user (including the upgrade costs that feed contract values).
--      Writes are now restricted to admin/staff.
--   4. PUSH ENDPOINT ABUSE: the send-push-notification edge function accepted
--      unauthenticated calls. A shared secret (generated here, stored in a
--      private schema) is now sent by the trigger and verified by the function.
--
-- All statements are idempotent (IF EXISTS / OR REPLACE / ON CONFLICT).

-- ---------------------------------------------------------------------------
-- 0. Helpers
-- ---------------------------------------------------------------------------

-- Admin tier only (role assignment, pricing control). Staff are NOT admins.
create or replace function public.is_admin(uid uuid)
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
              'admin','superadmin','super_admin','super admin',
              'salesadmin','sales_admin','sales admin'
          )
    );
$$;

-- Re-declare for self-containment (matches earlier migrations).
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
              'staff','preconstruction','pre_construction','buildingsupport','building_support','partner','salespartner','sales_partner'
          )
    );
$$;

-- ---------------------------------------------------------------------------
-- 1. Block self role-escalation on profiles
-- ---------------------------------------------------------------------------

create or replace function public.protect_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    caller uuid := auth.uid();
    jwt_role text := coalesce(auth.jwt() ->> 'role', '');
begin
    -- Service role / internal contexts (auth triggers, migrations) bypass.
    if caller is null or jwt_role = 'service_role' then
        return new;
    end if;

    if tg_op = 'UPDATE' then
        if new.role is distinct from old.role and not public.is_admin(caller) then
            raise exception 'Only admins can change user roles';
        end if;
        -- Staff/client assignment is also permission-bearing.
        if new.assigned_client_ids is distinct from old.assigned_client_ids
           and not public.is_admin_or_staff(caller) then
            raise exception 'Only staff can change client assignments';
        end if;
    elsif tg_op = 'INSERT' then
        -- Self-registration may only create unprivileged profiles.
        if not public.is_admin(caller)
           and lower(coalesce(new.role, 'client')) not in ('client', 'pending') then
            new.role := 'Client';
        end if;
    end if;

    return new;
end;
$$;

drop trigger if exists trg_protect_profile_role on public.profiles;
create trigger trg_protect_profile_role
    before insert or update on public.profiles
    for each row execute function public.protect_profile_role();

-- ---------------------------------------------------------------------------
-- 2. v_build_selections_full: respect RLS, no anonymous access
-- ---------------------------------------------------------------------------

do $$
begin
    if exists (select 1 from pg_views where schemaname = 'public' and viewname = 'v_build_selections_full') then
        execute 'alter view public.v_build_selections_full set (security_invoker = true)';
        execute 'revoke select on public.v_build_selections_full from anon';
    end if;
end $$;

-- Pricing helper functions are not needed by unauthenticated visitors.
do $$
begin
    begin
        revoke execute on function public.resolve_product_price(text, timestamptz) from anon;
    exception when undefined_function then null;
    end;
    begin
        revoke execute on function public.compute_upgrade_delta(text, text) from anon;
    exception when undefined_function then null;
    end;
    begin
        revoke execute on function public.validate_selections_at_range(text, text) from anon;
    exception when undefined_function then null;
    end;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Catalog / pricing tables: writes restricted to admin & staff
-- ---------------------------------------------------------------------------

do $$
declare
    spec record;
begin
    for spec in
        select * from (values
            ('spec_ranges',              'spec_ranges_write_auth',   'spec_ranges_write_staff'),
            ('spec_products',            'spec_products_write_auth', 'spec_products_write_staff'),
            ('spec_product_prices',      'spp_write_auth',           'spp_write_staff'),
            ('spec_product_colours',     'spc_write_auth',           'spc_write_staff'),
            ('spec_range_items',         'sri_write_auth',           'sri_write_staff'),
            ('spec_range_item_products', 'srip_write_auth',          'srip_write_staff'),
            ('build_range_history',      'brh_write_auth',           'brh_write_staff'),
            ('product_categories',       'pc_write_auth',            'pc_write_staff'),
            ('variant_room_assignments', 'vra_write_auth',           'vra_write_staff')
        ) as t(table_name, old_policy, new_policy)
    loop
        if to_regclass('public.' || spec.table_name) is not null then
            execute format('drop policy if exists %I on public.%I', spec.old_policy, spec.table_name);
            execute format('drop policy if exists %I on public.%I', spec.new_policy, spec.table_name);
            execute format(
                'create policy %I on public.%I for all using (public.is_admin_or_staff(auth.uid())) with check (public.is_admin_or_staff(auth.uid()))',
                spec.new_policy, spec.table_name
            );
        end if;
    end loop;
end $$;

-- build_range_history contains per-build cost deltas; nothing in the apps
-- reads it client-side, so reads become staff-only (was USING (true) → anon).
do $$
begin
    if to_regclass('public.build_range_history') is not null then
        drop policy if exists brh_read_all on public.build_range_history;
        drop policy if exists brh_read_staff on public.build_range_history;
        create policy brh_read_staff on public.build_range_history
            for select using (public.is_admin_or_staff(auth.uid()));
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Push webhook shared secret (verified by send-push-notification)
-- ---------------------------------------------------------------------------

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.app_secrets (
    key text primary key,
    value text not null,
    created_at timestamptz not null default now()
);
revoke all on private.app_secrets from public, anon, authenticated;

insert into private.app_secrets (key, value)
values ('push_webhook_secret', encode(gen_random_bytes(32), 'hex'))
on conflict (key) do nothing;

-- Re-create the push trigger function so it authenticates itself with the
-- shared secret. The edge function rejects calls without it.
create or replace function public.notify_push_on_notification()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
    v_secret text;
begin
    begin
        select value into v_secret
        from private.app_secrets
        where key = 'push_webhook_secret';

        perform net.http_post(
            url := 'https://app.aviahomes.com.au/functions/v1/send-push-notification',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-push-secret', coalesce(v_secret, '')
            ),
            body := jsonb_build_object('record', to_jsonb(new))
        );
    exception when others then
        -- Never let push delivery problems break notification inserts.
        raise warning '[notify_push_on_notification] %', sqlerrm;
    end;
    return new;
end;
$$;
