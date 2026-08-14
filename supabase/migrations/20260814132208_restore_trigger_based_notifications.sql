-- Restore notification generation to the canonical database triggers.
-- The v2 outbox schema and worker functions remain available for rollback and
-- historical test coverage, but v2 content transactions no longer create
-- outbox work or depend on a scheduler.

do $migration$
declare
  v_job_id bigint;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    for v_job_id in
      select jobid
      from cron.job
      where jobname = 'notification-worker-v2-every-minute'
    loop
      perform cron.unschedule(v_job_id);
    end loop;
  end if;
end
$migration$;

-- V2 RPCs still set this transaction-local marker for compatibility with
-- existing clients. Suppress only their obsolete outbox calls; direct test or
-- administrative use of the helper keeps its original durable behavior.
create or replace function private.enqueue_notification_outbox_v2(
  p_event_key text,
  p_notification_type text,
  p_actor_user_id uuid,
  p_target_type text,
  p_target_id uuid,
  p_audience_type text,
  p_audience_id uuid,
  p_audience_data jsonb,
  p_title text,
  p_body text,
  p_localization_args jsonb,
  p_notification_group_key text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  if current_setting('app.notification_pipeline', true) is not distinct from 'v2' then
    return null;
  end if;

  if auth.uid() is null or (p_actor_user_id is not null and p_actor_user_id <> auth.uid()) then
    raise exception 'Notification actor mismatch' using errcode = '42501';
  end if;

  insert into public.notification_outbox_v2 (
    event_key, notification_type, actor_user_id, target_type, target_id,
    audience_type, audience_id, audience_data, title, body,
    localization_args, notification_group_key
  ) values (
    p_event_key, p_notification_type, p_actor_user_id, p_target_type, p_target_id,
    p_audience_type, p_audience_id, coalesce(p_audience_data, '{}'::jsonb),
    left(p_title, 160), left(p_body, 500),
    coalesce(p_localization_args, '{}'::jsonb), p_notification_group_key
  ) on conflict (event_key) do update set event_key = excluded.event_key
  returning id into v_id;
  return v_id;
end $$;

-- Do not gate canonical notification triggers on the v2 marker. The source
-- table insert is now the notification event, including inserts performed by
-- the v2 RPCs. Each helper remains SECURITY DEFINER and inserts through the
-- existing deduplicated notification functions.
drop trigger if exists club_post_notification on public.club_posts;
create trigger club_post_notification
after insert on public.club_posts
for each row execute function private.notify_club_post();

drop trigger if exists club_event_notification on public.events;
create trigger club_event_notification
after insert on public.events
for each row execute function private.notify_club_event();

drop trigger if exists direct_message_notification on public.direct_messages;
create trigger direct_message_notification
after insert on public.direct_messages
for each row execute function private.notify_direct_message();

drop trigger if exists group_message_notification on public.group_messages;
create trigger group_message_notification
after insert on public.group_messages
for each row execute function private.notify_group_message();

drop trigger if exists club_channel_message_notification on public.club_channel_messages;
create trigger club_channel_message_notification
after insert on public.club_channel_messages
for each row
when (new.message_kind = 'announcement')
execute function private.notify_club_channel_message();

drop trigger if exists club_channel_mention_notification on public.club_channel_messages;
create trigger club_channel_mention_notification
after insert on public.club_channel_messages
for each row
when (
  new.message_kind <> 'announcement'
  and jsonb_typeof(new.payload -> 'mentions') = 'array'
  and jsonb_array_length(new.payload -> 'mentions') > 0
)
execute function private.notify_club_channel_mention();

drop trigger if exists club_inbox_message_notification on public.club_inbox_messages;
create trigger club_inbox_message_notification
after insert on public.club_inbox_messages
for each row execute function private.notify_club_inbox_message();

-- Trigger-created notifications use the legacy/default pipeline version and
-- therefore continue to dispatch through the existing pg_net push trigger.
-- Worker-expanded pipeline_version=2 rows remain excluded from push dispatch.
