-- Allow authenticated senders to remove only their own chat messages.
-- Existing SELECT/RLS policies continue to gate conversation membership.

grant delete on public.direct_messages to authenticated;
create policy "dm_delete_sender"
  on public.direct_messages
  for delete to authenticated
  using ((select auth.uid()) = sender_id);

grant delete on public.group_messages to authenticated;
create policy "group_messages_delete_sender"
  on public.group_messages
  for delete to authenticated
  using (
    sender_id = (select auth.uid())
    and private.is_group_chat_member(group_id)
  );

grant delete on public.club_channel_messages to authenticated;
create policy "club_channel_delete_sender"
  on public.club_channel_messages
  for delete to authenticated
  using (
    sender_auth_id = (select auth.uid())
    and (
      (
        sender_profile_id = (select auth.uid())
        and exists (
          select 1
          from public.club_followers cf
          where cf.club_id = club_channel_messages.club_id
            and cf.profile_id = (select auth.uid())
            and cf.role = 'board_member'
        )
      )
      or (
        sender_club_id = club_channel_messages.club_id
        and exists (
          select 1
          from public.club_auth_accounts ca
          where ca.club_id = club_channel_messages.club_id
            and ca.auth_user_id = (select auth.uid())
        )
      )
    )
  );

grant delete on public.club_inbox_messages to authenticated;
create policy "club_inbox_messages_delete_sender"
  on public.club_inbox_messages
  for delete to authenticated
  using (
    sender_auth_id = (select auth.uid())
    and exists (
      select 1
      from public.club_inbox_threads cit
      where cit.id = club_inbox_messages.thread_id
        and (
          cit.profile_id = (select auth.uid())
          or exists (
            select 1
            from public.club_auth_accounts ca
            where ca.club_id = cit.club_id
              and ca.auth_user_id = (select auth.uid())
          )
          or exists (
            select 1
            from public.club_followers cf
            where cf.club_id = cit.club_id
              and cf.profile_id = (select auth.uid())
              and cf.role = 'board_member'
          )
        )
    )
  );
