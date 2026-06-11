-- Production hardening: notifications, realtime & push delivery
--
-- Fixes three production-blocking gaps found in the audit:
--   1. Most app tables were never added to the `supabase_realtime` publication,
--      so realtime subscriptions (notifications, messages, builds, …) silently
--      received nothing — the root cause of "notifications aren't firing".
--   2. Nothing invoked the send-push-notification edge function. A database
--      trigger now calls it on every notification insert via pg_net.
--   3. device_tokens lacked a unique (user_id, token) constraint, so the app's
--      upsert with on_conflict=user_id,token failed silently and tokens were
--      never saved.
-- Also adds missing hot-path indexes for the queries the app runs constantly.

-- ---------------------------------------------------------------------------
-- 1. Device tokens
-- ---------------------------------------------------------------------------

create table if not exists public.device_tokens (
    id uuid primary key default gen_random_uuid(),
    user_id text not null,
    token text not null,
    platform text not null default 'ios',
    updated_at timestamptz not null default now()
);

-- Dedupe any rows that accumulated without the unique constraint.
delete from public.device_tokens a
using public.device_tokens b
where a.user_id = b.user_id
  and a.token = b.token
  and a.ctid < b.ctid;

create unique index if not exists device_tokens_user_token_uidx
    on public.device_tokens (user_id, token);

alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_own_rows on public.device_tokens;
create policy device_tokens_own_rows on public.device_tokens
    for all
    using (auth.uid() is not null and lower(auth.uid()::text) = lower(user_id))
    with check (auth.uid() is not null and lower(auth.uid()::text) = lower(user_id));

-- ---------------------------------------------------------------------------
-- 2. Hot-path indexes (guarded — some tables predate this migrations folder)
-- ---------------------------------------------------------------------------

do $$
begin
    if to_regclass('public.notifications') is not null then
        create index if not exists notifications_recipient_created_idx
            on public.notifications (recipient_id, created_at desc);
    end if;

    if to_regclass('public.messages') is not null then
        create index if not exists messages_conversation_created_idx
            on public.messages (conversation_id, created_at);
        -- Partial index that serves the unread-count query.
        create index if not exists messages_unread_idx
            on public.messages (conversation_id, sender_id)
            where is_read = false;
    end if;

    if to_regclass('public.build_stages') is not null then
        create index if not exists build_stages_build_idx
            on public.build_stages (build_id, sort_order);
    end if;

    if to_regclass('public.build_milestones') is not null then
        create index if not exists build_milestones_build_idx
            on public.build_milestones (build_id);
    end if;

    if to_regclass('public.build_reminders') is not null then
        create index if not exists build_reminders_build_idx
            on public.build_reminders (build_id);
        create index if not exists build_reminders_client_idx
            on public.build_reminders (client_id);
    end if;

    -- GIN index for participant containment lookups on conversations.
    if to_regclass('public.conversations') is not null then
        begin
            create index if not exists conversations_participants_gin_idx
                on public.conversations using gin (participant_ids);
        exception when others then
            raise warning 'Skipping conversations GIN index: %', sqlerrm;
        end;
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Realtime publication — add every table the app subscribes to.
--    Idempotent: skips tables that don't exist or are already published.
-- ---------------------------------------------------------------------------

do $$
declare
    t text;
    tables text[] := array[
        'notifications',
        'messages',
        'conversations',
        'builds',
        'build_stages',
        'package_assignments',
        'service_requests',
        'profiles',
        'documents',
        'build_spec_selections',
        'build_colour_selections',
        'schedule_items',
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
        'homefast_schemes',
        'display_homes',
        'display_home_visits'
    ];
begin
    foreach t in array tables loop
        if to_regclass('public.' || t) is not null then
            begin
                execute format('alter publication supabase_realtime add table public.%I', t);
            exception
                when duplicate_object then null;  -- already in the publication
                when others then
                    raise warning 'Could not add % to supabase_realtime: %', t, sqlerrm;
            end;
        end if;
    end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Push delivery — call the send-push-notification edge function on every
--    notification insert. Failures must never block the insert itself.
-- ---------------------------------------------------------------------------

do $$
begin
    create extension if not exists pg_net;
exception when others then
    raise warning 'pg_net extension not available: %', sqlerrm;
end $$;

create or replace function public.notify_push_on_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    begin
        perform net.http_post(
            url := 'https://app.aviahomes.com.au/functions/v1/send-push-notification',
            headers := jsonb_build_object('Content-Type', 'application/json'),
            body := jsonb_build_object('record', to_jsonb(new))
        );
    exception when others then
        -- Never let push delivery problems break notification inserts.
        raise warning '[notify_push_on_notification] %', sqlerrm;
    end;
    return new;
end;
$$;

do $$
begin
    if to_regclass('public.notifications') is not null then
        drop trigger if exists trg_notify_push on public.notifications;
        create trigger trg_notify_push
            after insert on public.notifications
            for each row execute function public.notify_push_on_notification();
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Normalize legacy mixed-case ids stored in TEXT columns.
--    Profiles are keyed by lowercase auth uuid strings; some legacy message /
--    notification rows were written with uppercase uuids, which broke
--    sender/recipient matching in the app ("Unknown User", wrong unread
--    counts). Only runs against text columns — uuid columns are unaffected.
-- ---------------------------------------------------------------------------

do $$
begin
    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'notifications'
                 and column_name = 'recipient_id' and data_type = 'text') then
        update public.notifications
           set recipient_id = lower(recipient_id)
         where recipient_id <> lower(recipient_id);
    end if;

    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'notifications'
                 and column_name = 'sender_id' and data_type = 'text') then
        update public.notifications
           set sender_id = lower(sender_id)
         where sender_id is not null and sender_id <> lower(sender_id);
    end if;

    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'messages'
                 and column_name = 'sender_id' and data_type = 'text') then
        update public.messages
           set sender_id = lower(sender_id)
         where sender_id <> lower(sender_id);
    end if;

    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'conversations'
                 and column_name = 'last_sender_id' and data_type = 'text') then
        update public.conversations
           set last_sender_id = lower(last_sender_id)
         where last_sender_id is not null and last_sender_id <> lower(last_sender_id);
    end if;

    -- participant_ids is a text array on conversations.
    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'conversations'
                 and column_name = 'participant_ids' and data_type = 'ARRAY') then
        update public.conversations c
           set participant_ids = sub.lowered
          from (
              select id, array(select lower(x) from unnest(participant_ids) as x) as lowered
                from public.conversations
          ) sub
         where c.id = sub.id
           and c.participant_ids is distinct from sub.lowered;
    end if;

    update public.device_tokens
       set user_id = lower(user_id)
     where user_id <> lower(user_id);
exception when others then
    raise warning 'Legacy id normalization skipped: %', sqlerrm;
end $$;
