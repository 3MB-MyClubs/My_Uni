-- Keep the club general channel readable by followers, but reserve all posts
-- (including replies, polls, and media) for the club's yönetim kurulu or its
-- linked club account.

drop policy if exists club_channel_insert_members
  on public.club_channel_messages;
drop policy if exists club_channel_insert_board
  on public.club_channel_messages;

create policy club_channel_insert_board
  on public.club_channel_messages for insert to authenticated
  with check (
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
