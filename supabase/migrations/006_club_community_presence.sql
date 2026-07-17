-- Live club community information:
--   * app-wide authenticated Presence for accurate foreground activity
--   * realtime membership changes for the one opened club

create index if not exists club_followers_club_id_idx
  on public.club_followers (club_id);

alter table public.club_followers replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'club_followers'
  ) then
    alter publication supabase_realtime add table public.club_followers;
  end if;
end
$$;

-- Private Presence channels are authorized through realtime.messages. Only a
-- valid authenticated session can see or publish app activity.
alter table realtime.messages enable row level security;
grant select, insert on realtime.messages to authenticated;

drop policy if exists "authenticated_app_presence_read"
  on realtime.messages;
create policy "authenticated_app_presence_read"
  on realtime.messages
  for select
  to authenticated
  using (
    realtime.messages.extension = 'presence'
    and (select realtime.topic()) = 'app:presence'
  );

drop policy if exists "authenticated_app_presence_track"
  on realtime.messages;
create policy "authenticated_app_presence_track"
  on realtime.messages
  for insert
  to authenticated
  with check (
    realtime.messages.extension = 'presence'
    and (select realtime.topic()) = 'app:presence'
  );
