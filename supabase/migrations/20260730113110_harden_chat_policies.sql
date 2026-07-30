alter function public.is_group_chat_member(uuid) set schema private;
alter function public.is_group_chat_creator(uuid) set schema private;

grant usage on schema private to authenticated;
revoke all on function private.is_group_chat_member(uuid) from public, anon;
revoke all on function private.is_group_chat_creator(uuid) from public, anon;
grant execute on function private.is_group_chat_member(uuid) to authenticated;
grant execute on function private.is_group_chat_creator(uuid) to authenticated;

drop policy if exists "dm_select_participants" on public.direct_messages;
create policy "dm_select_participants" on public.direct_messages
  for select to authenticated
  using ((select auth.uid()) in (sender_id, receiver_id));

drop policy if exists "dm_insert_sender" on public.direct_messages;
create policy "dm_insert_sender" on public.direct_messages
  for insert to authenticated
  with check (sender_id = (select auth.uid()));

drop policy if exists "dm_update_receiver" on public.direct_messages;
create policy "dm_update_receiver" on public.direct_messages
  for update to authenticated
  using (receiver_id = (select auth.uid()))
  with check (receiver_id = (select auth.uid()));

drop policy if exists "group_select_members" on public.group_chats;
create policy "group_select_members" on public.group_chats
  for select to authenticated
  using (private.is_group_chat_member(id) or creator_id = (select auth.uid()));

drop policy if exists "group_insert_creator" on public.group_chats;
create policy "group_insert_creator" on public.group_chats
  for insert to authenticated
  with check (creator_id = (select auth.uid()));

drop policy if exists "group_update_creator" on public.group_chats;
create policy "group_update_creator" on public.group_chats
  for update to authenticated
  using (creator_id = (select auth.uid()))
  with check (creator_id = (select auth.uid()));

drop policy if exists "group_members_select_members" on public.group_chat_members;
create policy "group_members_select_members" on public.group_chat_members
  for select to authenticated
  using (private.is_group_chat_member(group_id) or private.is_group_chat_creator(group_id));

drop policy if exists "group_members_insert_creator" on public.group_chat_members;
create policy "group_members_insert_creator" on public.group_chat_members
  for insert to authenticated
  with check (private.is_group_chat_creator(group_id));

drop policy if exists "group_members_delete_creator" on public.group_chat_members;
create policy "group_members_delete_creator" on public.group_chat_members
  for delete to authenticated
  using (private.is_group_chat_creator(group_id));

drop policy if exists "group_messages_select_members" on public.group_messages;
create policy "group_messages_select_members" on public.group_messages
  for select to authenticated
  using (private.is_group_chat_member(group_id));

drop policy if exists "group_messages_insert_members" on public.group_messages;
create policy "group_messages_insert_members" on public.group_messages
  for insert to authenticated
  with check (
    sender_id = (select auth.uid()) and private.is_group_chat_member(group_id)
  );

create index if not exists group_chats_creator_id_idx
  on public.group_chats (creator_id);
create index if not exists group_messages_sender_id_idx
  on public.group_messages (sender_id);
create index if not exists notifications_actor_user_id_idx
  on public.notifications (actor_user_id);
