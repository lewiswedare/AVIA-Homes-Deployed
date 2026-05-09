-- Enable Supabase Realtime publication on client_foundation_calls so the iOS
-- CRM updates instantly when Cal.com webhooks reconcile a booking.
do $$
begin
    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'client_foundation_calls'
    ) then
        execute 'alter publication supabase_realtime add table public.client_foundation_calls';
    end if;
end
$$;

-- Ensure UPDATEs include enough info for downstream consumers.
alter table public.client_foundation_calls replica identity full;
