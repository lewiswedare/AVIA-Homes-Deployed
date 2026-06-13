-- Fix: chat messages couldn't be traced back to their sender's profile.
--
-- The `profiles` table only had ONE select policy — "Users can view own
-- profile" (auth.uid() = id). That meant when a chat tried to resolve the
-- OTHER participant and each message's sender via fetchProfiles(ids:), RLS
-- stripped out every row except the caller's own. Result in the apps: "?"
-- avatars, a generic "Chat" title, no sender names, and messages that
-- couldn't be attributed to a person.
--
-- This migration ADDS a second, narrowly-scoped select policy: an
-- authenticated user may read a profile row when they share at least one
-- conversation with that person. It does NOT widen access to unrelated
-- profiles (clients still can't enumerate other clients), and it leaves the
-- existing own-profile / admin / staff policies untouched (multiple
-- permissive SELECT policies are OR'd together).
--
-- Fixes both the iOS and web apps simultaneously (same database).
-- All statements are idempotent (OR REPLACE / DROP ... IF EXISTS).

do $do$
begin
    -- The helper references public.conversations; skip cleanly if it's absent.
    if to_regclass('public.conversations') is null then
        raise notice 'conversations table missing — skipping conversation-peer profile policy';
        return;
    end if;

    -- SECURITY DEFINER so the membership check bypasses the conversations RLS
    -- of the caller (avoids policy-on-policy evaluation) while still only ever
    -- returning true for conversations the caller actually belongs to.
    --
    -- participant_ids is a text[] of lowercased user ids (normalised by the app
    -- on write and back-filled in 20260611). The GIN index on participant_ids
    -- makes the @> containment checks index-friendly.
    execute $fn$
        create or replace function public.shares_conversation(_other text)
        returns boolean
        language sql
        stable
        security definer
        set search_path = public
        as $body$
            select exists (
                select 1
                from public.conversations c
                where c.participant_ids @> array[lower(auth.uid()::text)]
                  and c.participant_ids @> array[lower(_other)]
            );
        $body$;
    $fn$;

    execute 'revoke all on function public.shares_conversation(text) from public, anon';
    execute 'grant execute on function public.shares_conversation(text) to authenticated';

    execute 'drop policy if exists "Users can view conversation participant profiles" on public.profiles';
    execute $pol$
        create policy "Users can view conversation participant profiles"
            on public.profiles
            for select
            using (public.shares_conversation(id))
    $pol$;
end
$do$;
