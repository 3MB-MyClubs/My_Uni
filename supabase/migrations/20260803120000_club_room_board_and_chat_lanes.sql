-- Club rooms gained two lanes (Club Board + Chat): the Board is the officers'
-- notice area, the Chat is the room every member talks in.
--
-- Until now a club channel was board-only: `club_channel_insert_board` let a
-- board member or the linked club account insert, and nobody else. Members can
-- now post in the Chat lane, so the insert policy splits the two rights:
--
--   * any follower of the club            → anything except a notice
--   * board members / the club account    → anything, notices included
--
-- A notice is identified the same way the client identifies it: `message_kind =
-- 'announcement'`, plus the pin that travels with it in the payload. Both are
-- checked here so posting authority is enforced by the database and not only by
-- the UI that hides the composer.

drop policy if exists club_channel_insert_board
  on public.club_channel_messages;
drop policy if exists club_channel_insert_members
  on public.club_channel_messages;

create policy club_channel_insert_members
  on public.club_channel_messages for insert to authenticated
  with check (
    sender_auth_id = (select auth.uid())
    and (
      -- A member of the club, writing in the Chat lane.
      (
        sender_profile_id = (select auth.uid())
        and message_kind <> 'announcement'
        and coalesce((payload->>'pinned')::boolean, false) = false
        and exists (
          select 1 from public.club_followers cf
          where cf.club_id = club_channel_messages.club_id
            and cf.profile_id = (select auth.uid())
        )
      )
      or
      -- A member holding a role in the club: the Board lane as well.
      (
        sender_profile_id = (select auth.uid())
        and exists (
          select 1 from public.club_followers cf
          where cf.club_id = club_channel_messages.club_id
            and cf.profile_id = (select auth.uid())
            and cf.role = 'board_member'
        )
      )
      or
      -- The club's own account.
      (
        sender_club_id = club_channel_messages.club_id
        and exists (
          select 1 from public.club_auth_accounts ca
          where ca.club_id = club_channel_messages.club_id
            and ca.auth_user_id = (select auth.uid())
        )
      )
    )
  );

-- Deleting stays with the author: a member may remove their own chat message,
-- which the board-only delete policy did not allow for.
drop policy if exists club_channel_delete_sender
  on public.club_channel_messages;

create policy club_channel_delete_sender
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
