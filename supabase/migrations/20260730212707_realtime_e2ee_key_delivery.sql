-- Clients retry decryption as soon as a participant uploads an envelope for a
-- newly registered device. RLS on the envelope table limits each subscriber
-- to threads they are authorized to access.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'e2ee_thread_key_envelopes'
  ) then
    alter publication supabase_realtime
      add table public.e2ee_thread_key_envelopes;
  end if;
end $$;
