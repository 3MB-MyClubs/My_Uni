-- Ephemeral typing indicators for Chat v2.
--
-- Supabase owns realtime.messages. Realtime Authorization supports policies
-- on that table, but the table and the rest of the realtime schema must not be
-- altered. Typing state is sent by clients over private Broadcast channels and
-- is never persisted in an application table.

create or replace function private.can_use_chat_typing_topic(
  p_topic text,
  p_extension text,
  p_write boolean
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_thread_id text;
  v_peer uuid;
  v_club_id uuid;
begin
  if v_actor is null
      or p_extension is distinct from 'broadcast'
      or p_topic is null
      or left(p_topic, 12) <> 'chat:typing:' then
    return false;
  end if;

  v_thread_id := substr(p_topic, 13);
  if v_thread_id = ''
      or not private.chat_v2_can_access(v_thread_id, v_actor) then
    return false;
  end if;

  -- Reading follows Chat v2 membership exactly. Writing has the additional
  -- restrictions enforced by the canonical message insert paths.
  if not p_write then
    return true;
  end if;

  if left(v_thread_id, 3) = 'dm:' then
    v_peer := private.chat_v2_direct_peer(v_thread_id, v_actor);
    return v_peer is not null
      and not private.chat_v2_dm_blocked(v_actor, v_peer);
  elsif left(v_thread_id, 6) = 'group:' then
    return true;
  elsif left(v_thread_id, 5) = 'club:' then
    v_club_id := private.chat_v2_thread_uuid(v_thread_id, 'club:');
    return v_club_id is not null and (
      exists (
        select 1
        from public.club_followers as follower
        where follower.club_id = v_club_id
          and follower.profile_id = v_actor
          and follower.role = 'board_member'
      )
      or exists (
        select 1
        from public.club_auth_accounts as account
        where account.club_id = v_club_id
          and account.auth_user_id = v_actor
      )
    );
  elsif left(v_thread_id, 7) = 'clubdm:' then
    return true;
  end if;

  return false;
end
$function$;

revoke all on function private.can_use_chat_typing_topic(text, text, boolean)
  from public, anon;
grant execute on function private.can_use_chat_typing_topic(text, text, boolean)
  to authenticated;

drop policy if exists "chat_typing_broadcast_receive"
  on realtime.messages;
create policy "chat_typing_broadcast_receive"
  on realtime.messages
  for select
  to authenticated
  using (
    (select private.can_use_chat_typing_topic(
      (select realtime.topic()),
      realtime.messages.extension::text,
      false
    ))
  );

drop policy if exists "chat_typing_broadcast_send"
  on realtime.messages;
create policy "chat_typing_broadcast_send"
  on realtime.messages
  for insert
  to authenticated
  with check (
    (select private.can_use_chat_typing_topic(
      (select realtime.topic()),
      realtime.messages.extension::text,
      true
    ))
  );
