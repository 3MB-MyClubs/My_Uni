-- Keep chat notifications private even if a stale row has the wrong
-- recipient or a recipient has since left the referenced conversation.

create or replace function private.can_access_notification(
  notification_user_id uuid,
  notification_type text,
  notification_target_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    notification_user_id = (select auth.uid())
    and case notification_type
      when 'direct_message' then
        notification_target_id <> notification_user_id
        and exists (
          select 1
          from public.direct_messages as message
          where (
            message.sender_id = notification_user_id
            and message.receiver_id = notification_target_id
          ) or (
            message.receiver_id = notification_user_id
            and message.sender_id = notification_target_id
          )
        )
      when 'group_message' then exists (
        select 1
        from public.group_chat_members as member
        where member.group_id = notification_target_id
          and member.user_id = notification_user_id
      )
      when 'club_channel_message' then exists (
        select 1
        from public.club_followers as follower
        where follower.club_id = notification_target_id
          and follower.profile_id = notification_user_id
      )
      when 'club_inbox_message' then exists (
        select 1
        from public.club_inbox_threads as thread
        where thread.id = notification_target_id
          and (
            thread.profile_id = notification_user_id
            or exists (
              select 1
              from public.club_auth_accounts as account
              where account.club_id = thread.club_id
                and account.auth_user_id = notification_user_id
            )
            or exists (
              select 1
              from public.club_followers as board_member
              where board_member.club_id = thread.club_id
                and board_member.profile_id = notification_user_id
                and board_member.role = 'board_member'
            )
          )
      )
      when 'club_post' then true
      when 'club_event' then true
      when 'post_like' then true
      when 'post_comment' then true
      when 'event_rsvp' then true
      when 'profile_follow' then true
      else false
    end;
$$;

revoke all on function private.can_access_notification(uuid, text, uuid)
  from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.can_access_notification(uuid, text, uuid)
  to authenticated;

drop policy if exists "Users can read their own notifications"
  on public.notifications;
create policy "Users can read authorized notifications"
  on public.notifications
  for select
  to authenticated
  using (
    private.can_access_notification(user_id, type, target_id)
  );

drop policy if exists "Users can mark their own notifications read"
  on public.notifications;
create policy "Users can mark authorized notifications read"
  on public.notifications
  for update
  to authenticated
  using (
    private.can_access_notification(user_id, type, target_id)
  )
  with check (
    private.can_access_notification(user_id, type, target_id)
  );

-- A Firebase token belongs to the current installation, but an interrupted or
-- offline logout can leave it attached to the previous account. Run before
-- the unique-token check so the newly authenticated account can safely claim
-- its own token without broadening push_devices RLS.
create or replace function private.claim_push_device_token()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or new.user_id <> (select auth.uid()) then
    raise insufficient_privilege
      using message = 'push device user_id must match the authenticated user';
  end if;

  delete from public.push_devices as device
  where device.fcm_token = new.fcm_token
    and device.user_id <> new.user_id;

  return new;
end;
$$;

revoke all on function private.claim_push_device_token()
  from public, anon, authenticated;

drop trigger if exists claim_push_device_token_before_insert
  on public.push_devices;
create trigger claim_push_device_token_before_insert
before insert on public.push_devices
for each row execute function private.claim_push_device_token();
