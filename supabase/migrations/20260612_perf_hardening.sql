-- ============================================================================
-- Performance hardening (run after 20260612_partner_scoping.sql)
--
--   1. Adds the missing hot-path indexes. Every list screen in the app filters
--      on these columns (notifications by recipient, messages by conversation,
--      build children by build_id, …) — without indexes each request walks the
--      whole table AND makes every RLS policy check slower.
--   2. Trims the realtime publication down to the tables the apps actually
--      subscribe to. 28 tables were broadcasting every write to every
--      connected client; only 14 are ever listened to.
--
-- Both sections are defensive: tables/columns that don't exist are skipped
-- with a notice, and the whole file is idempotent — safe to re-run.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Hot-path indexes
-- ---------------------------------------------------------------------------

do $$
declare
    -- idx name | table | index expression | columns that must exist
    specs text[][] := array[
        ['notifications_recipient_created_idx', 'notifications',               'recipient_id, created_at desc', 'recipient_id,created_at'],
        ['messages_conversation_created_idx',   'messages',                    'conversation_id, created_at',   'conversation_id,created_at'],
        ['documents_client_idx',                'documents',                   'client_id',                     'client_id'],
        ['service_requests_client_idx',         'service_requests',            'client_id',                     'client_id'],
        ['build_stages_build_idx',              'build_stages',                'build_id',                      'build_id'],
        ['build_spec_selections_build_idx',     'build_spec_selections',       'build_id',                      'build_id'],
        ['build_colour_selections_build_idx',   'build_colour_selections',     'build_id',                      'build_id'],
        ['schedule_items_build_idx',            'schedule_items',              'build_id',                      'build_id'],
        ['build_milestones_build_idx',          'build_milestones',            'build_id',                      'build_id'],
        ['build_reminders_build_idx',           'build_reminders',             'build_id',                      'build_id'],
        ['build_range_upgrade_requests_build_idx', 'build_range_upgrade_requests', 'build_id',                  'build_id'],
        ['package_assignments_package_idx',     'package_assignments',         'package_id',                    'package_id'],
        ['eoi_submissions_package_idx',         'eoi_submissions',             'package_id',                    'package_id'],
        ['contracts_client_idx',                'contracts',                   'client_id',                     'client_id'],
        ['invoices_client_idx',                 'invoices',                    'client_id',                     'client_id'],
        ['client_tasks_assignee_idx',           'client_tasks',                'assignee_id',                   'assignee_id'],
        ['client_stage_completions_client_idx', 'client_stage_completions',    'client_id',                     'client_id'],
        ['email_sends_client_idx',              'email_sends',                 'client_id',                     'client_id']
    ];
    spec text[];
    col text;
    all_cols_exist boolean;
begin
    foreach spec slice 1 in array specs loop
        if to_regclass('public.' || spec[2]) is null then
            raise notice 'Skipping index % — table % does not exist', spec[1], spec[2];
            continue;
        end if;

        all_cols_exist := true;
        foreach col in array string_to_array(spec[4], ',') loop
            if not exists (
                select 1 from information_schema.columns
                where table_schema = 'public'
                  and table_name = spec[2]
                  and column_name = col
            ) then
                all_cols_exist := false;
            end if;
        end loop;

        if not all_cols_exist then
            raise notice 'Skipping index % — column missing on %', spec[1], spec[2];
            continue;
        end if;

        begin
            execute format(
                'create index if not exists %I on public.%I (%s)',
                spec[1], spec[2], spec[3]
            );
        exception when others then
            raise warning 'Could not create index %: %', spec[1], sqlerrm;
        end;
    end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Trim the realtime publication
--
-- Tables the apps actually subscribe to (iOS channels + web useRealtimeSync):
--   notifications, messages, conversations, builds, build_stages,
--   package_assignments, service_requests, profiles, documents,
--   build_spec_selections, build_colour_selections, schedule_items,
--   display_homes, display_home_visits
--
-- Everything else broadcasts every insert/update/delete to all connected
-- clients for nothing — extra load on the realtime server and on devices.
-- ---------------------------------------------------------------------------

do $$
declare
    unused text[] := array[
        'build_milestones',
        'build_reminders',
        'build_range_upgrade_requests',
        'invoices',
        'contracts',
        'contract_signatures',
        'eoi_submissions',
        'colour_categories',
        'spec_items',
        'spec_categories',
        'spec_to_colour_mapping',
        'spec_range_tiers',
        'spec_item_images',
        'homefast_schemes'
    ];
    t text;
begin
    foreach t in array unused loop
        if to_regclass('public.' || t) is null then
            continue;
        end if;
        begin
            execute format('alter publication supabase_realtime drop table public.%I', t);
        exception
            when undefined_object then null;   -- not in the publication
            when others then
                raise warning 'Could not drop % from supabase_realtime: %', t, sqlerrm;
        end;
    end loop;
end $$;
