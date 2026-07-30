-- Repair app-wide Presence authorization with a unique migration version.
-- The original presence migration used version 006, which is also used by
-- 006_club_blocks.sql and may therefore be absent from migration history.
-- Supabase manages realtime.messages and already enables RLS on it; only its
-- supported Presence authorization policies are changed here.

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
