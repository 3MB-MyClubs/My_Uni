-- Keep a club room quiet now that its members talk in it.
--
-- Every insert into club_channel_messages used to push a club-branded
-- notification to every follower. That was right while the channel was
-- board-only broadcast; with the Board + Chat lanes it would mean a push to the
-- whole club for each chat message.
--
-- The two lanes get the two behaviours the design implies, and each one gets
-- its own trigger so the conditions stay readable and disjoint:
--
--   * Board (message_kind = 'announcement') → the official notice: every
--     follower is notified, by the existing notify_club_channel_message().
--   * Chat (everything else)                → the room: only the people the
--     message mentions, plus everyone when it carries an @everyone mention.
--     The unread count on the Chat segment and on the Messages row is the
--     signal for the rest.
--
-- Mentions travel in the client payload as `payload -> 'mentions'`: a list of
-- profile ids, or the literal 'everyone'.

-- The Board lane keeps the club-wide fan-out, now only for notices.
drop trigger if exists club_channel_message_notification
  on public.club_channel_messages;
create trigger club_channel_message_notification
after insert on public.club_channel_messages
for each row
when (new.message_kind = 'announcement')
execute function private.notify_club_channel_message();

-- The Chat lane notifies the people it names, and nobody else.
create or replace function private.notify_club_channel_mention()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  club_name text;
  preview text;
  mentions jsonb;
  mentions_everyone boolean;
  follower record;
begin
  select coalesce(nullif(c.name, ''), 'A club') into club_name
  from public.clubs c where c.id = new.club_id;

  mentions := new.payload -> 'mentions';
  mentions_everyone := mentions ? 'everyone';
  preview := coalesce(nullif(btrim(new.content), ''), 'New message');

  for follower in
    select cf.profile_id from public.club_followers cf
    where cf.club_id = new.club_id and cf.profile_id <> new.sender_auth_id
  loop
    if mentions_everyone or mentions ? follower.profile_id::text then
      perform private.enqueue_localized_notification(
        follower.profile_id, new.sender_auth_id, 'club_channel_message',
        club_name, club_name || ': ' || preview,
        'message', new.club_id,
        'club_channel_mention:' || new.id::text || ':'
          || follower.profile_id::text,
        jsonb_build_object(
          'actorName', club_name,
          'clubName', club_name,
          'content', preview,
          'messageKind', 'text'
        )
      );
    end if;
  end loop;
  return new;
end;
$$;

revoke all on function private.notify_club_channel_mention()
  from public, anon, authenticated;

drop trigger if exists club_channel_mention_notification
  on public.club_channel_messages;
create trigger club_channel_mention_notification
after insert on public.club_channel_messages
for each row
when (
  new.message_kind <> 'announcement'
  and jsonb_typeof(new.payload -> 'mentions') = 'array'
  and jsonb_array_length(new.payload -> 'mentions') > 0
)
execute function private.notify_club_channel_mention();
