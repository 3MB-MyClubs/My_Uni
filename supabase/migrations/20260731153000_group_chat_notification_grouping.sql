-- Keep one persistent notification row per chat conversation and recipient.
-- Historical rows remain intact; the client groups them while they age out.
alter table public.notifications
  add column if not exists notification_group_key text;

alter table public.notifications
  add column if not exists message_count integer not null default 1;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_message_count_positive'
  ) then
    alter table public.notifications
      add constraint notifications_message_count_positive
      check (message_count > 0);
  end if;
end $$;

create unique index if not exists notifications_user_group_key_idx
  on public.notifications (user_id, notification_group_key)
  where notification_group_key is not null;

create or replace function private.enqueue_localized_notification(
  recipient_id uuid,
  actor_id uuid,
  notification_type text,
  notification_title text,
  notification_body text,
  notification_target_type text,
  notification_target_id uuid,
  notification_dedupe_key text,
  notification_localization_args jsonb
) returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (
    user_id, actor_user_id, type, title, body, target_type, target_id,
    dedupe_key, localization_args, notification_group_key, message_count
  ) values (
    recipient_id,
    actor_id,
    notification_type,
    left(notification_title, 160),
    left(notification_body, 500),
    notification_target_type,
    notification_target_id,
    notification_dedupe_key,
    jsonb_set(
      coalesce(notification_localization_args, '{}'::jsonb),
      '{messageCount}',
      '1'::jsonb,
      true
    ),
    case
      when notification_type in (
        'direct_message', 'group_message', 'club_channel_message',
        'club_inbox_message'
      ) then notification_type || ':' || notification_target_id::text
      else null
    end,
    1
  )
  on conflict (user_id, notification_group_key)
    where notification_group_key is not null
  do update set
    actor_user_id = excluded.actor_user_id,
    type = excluded.type,
    title = excluded.title,
    body = excluded.body,
    target_type = excluded.target_type,
    target_id = excluded.target_id,
    dedupe_key = excluded.dedupe_key,
    message_count = case
      when public.notifications.read_at is null
        then public.notifications.message_count + 1
      else 1
    end,
    localization_args = jsonb_set(
      coalesce(excluded.localization_args, '{}'::jsonb),
      '{messageCount}',
      to_jsonb(case
        when public.notifications.read_at is null
          then public.notifications.message_count + 1
        else 1
      end),
      true
    ),
    created_at = excluded.created_at,
    read_at = null,
    push_started_at = null,
    push_sent_at = null,
    push_error = null;
$$;

revoke all on function private.enqueue_localized_notification(
  uuid, uuid, text, text, text, text, uuid, text, jsonb
) from public, anon, authenticated;

-- A grouped chat row is a new push event when its latest message changes.
-- Do not include push bookkeeping columns here or the delivery worker would
-- recursively dispatch itself when it claims/completes a notification.
drop trigger if exists send_grouped_notification_push on public.notifications;
create trigger send_grouped_notification_push
after update of actor_user_id, type, title, body, target_type, target_id,
  dedupe_key, localization_args, notification_group_key, message_count,
  created_at
on public.notifications
for each row
when (new.notification_group_key is not null)
execute function private.dispatch_notification_push();
