-- Canonical consolidation of the two historical 006 migrations.
-- Original byte-for-byte sources are retained in supabase/legacy_migrations/duplicates/.

-- Let users block clubs and later manage/unblock both club and user blocks.

alter table moderation_reports
  drop constraint if exists moderation_reports_target_type_check;
alter table moderation_reports
  add constraint moderation_reports_target_type_check
  check (target_type in (
    'post', 'comment', 'profile', 'message', 'event', 'club'
  ));

create table if not exists club_blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  club_id uuid not null references clubs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, club_id)
);

create index if not exists club_blocks_club_idx on club_blocks (club_id);

alter table club_blocks enable row level security;

create policy "club_blocks_select_own" on club_blocks
  for select to authenticated
  using ((select auth.uid()) = blocker_id);

create policy "club_blocks_insert_own" on club_blocks
  for insert to authenticated
  with check ((select auth.uid()) = blocker_id);

create policy "club_blocks_delete_own" on club_blocks
  for delete to authenticated
  using ((select auth.uid()) = blocker_id);

grant select, insert, delete on table club_blocks to authenticated;

-- ---- originally 006_club_community_presence.sql ----

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

