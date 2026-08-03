-- Structured chat messages keep their body outside `content`. Build a safe,
-- localized notification hint from the message kind so photo/video alerts do
-- not end in a blank preview.

create or replace function private.chat_notification_message_kind(
  message_kind text,
  message_payload jsonb
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when coalesce(message_kind, '') = 'file'
      and lower(coalesce(
        nullif(message_payload ->> 'attachmentName', ''),
        message_payload ->> 'attachmentPath',
        ''
      )) ~ '\.(mp4|mov|m4v|avi|webm|mkv|3gp)(\?.*)?$'
      then 'video'
    else coalesce(nullif(message_kind, ''), 'text')
  end;
$$;

create or replace function private.chat_notification_preview(
  message_kind text,
  message_content text,
  message_payload jsonb
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case private.chat_notification_message_kind(
    message_kind,
    message_payload
  )
    when 'photo' then 'Photo'
    when 'video' then 'Video'
    when 'file' then 'File'
    when 'post_share' then 'Shared a post'
    when 'announcement' then coalesce(
      nullif(left(btrim(coalesce(message_content, '')), 440), ''),
      nullif(left(btrim(coalesce(message_payload ->> 'title', '')), 440), ''),
      'Announcement'
    )
    when 'poll' then coalesce(
      nullif(left(btrim(coalesce(message_content, '')), 440), ''),
      nullif(left(btrim(coalesce(message_payload ->> 'title', '')), 440), ''),
      'Poll'
    )
    when 'event' then coalesce(
      nullif(left(btrim(coalesce(message_content, '')), 440), ''),
      'Event'
    )
    else coalesce(
      nullif(left(btrim(coalesce(message_content, '')), 440), ''),
      'Message'
    )
  end;
$$;

revoke all on function private.chat_notification_message_kind(text, jsonb)
  from public, anon, authenticated;
revoke all on function private.chat_notification_preview(text, text, jsonb)
  from public, anon, authenticated;

create or replace function private.notify_direct_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare sender_name text; preview text; preview_kind text;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone') into sender_name
  from public.profiles p where p.id = new.sender_id;
  preview_kind := private.chat_notification_message_kind(
    new.message_kind,
    new.payload
  );
  preview := private.chat_notification_preview(
    new.message_kind,
    new.content,
    new.payload
  );
  perform private.enqueue_localized_notification(
    new.receiver_id, new.sender_id, 'direct_message',
    coalesce(sender_name, 'New message'),
    coalesce(sender_name, 'Someone') || ': ' || preview,
    'message', new.sender_id, 'direct_message:' || new.id::text,
    jsonb_build_object(
      'actorName', coalesce(sender_name, 'Someone'),
      'content', preview,
      'messageKind', preview_kind
    )
  );
  return new;
end;
$$;

create or replace function private.notify_group_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  sender_name text; group_name text; preview text; preview_kind text;
  member record;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone') into sender_name
  from public.profiles p where p.id = new.sender_id;
  select coalesce(nullif(g.custom_name, ''), 'Group chat') into group_name
  from public.group_chats g where g.id = new.group_id;
  preview_kind := private.chat_notification_message_kind(
    new.message_kind,
    new.payload
  );
  preview := private.chat_notification_preview(
    new.message_kind,
    new.content,
    new.payload
  );
  for member in
    select m.user_id from public.group_chat_members m
    where m.group_id = new.group_id and m.user_id <> new.sender_id
  loop
    perform private.enqueue_localized_notification(
      member.user_id, new.sender_id, 'group_message',
      coalesce(group_name, 'Group chat'),
      coalesce(sender_name, 'Someone') || ': ' || preview,
      'message', new.group_id,
      'group_message:' || new.id::text || ':' || member.user_id::text,
      jsonb_build_object(
        'actorName', coalesce(sender_name, 'Someone'),
        'groupName', coalesce(group_name, 'Group chat'),
        'content', preview,
        'messageKind', preview_kind
      )
    );
  end loop;
  return new;
end;
$$;

create or replace function private.notify_club_channel_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare club_name text; preview text; preview_kind text; follower record;
begin
  select coalesce(nullif(c.name, ''), 'A club') into club_name
  from public.clubs c where c.id = new.club_id;
  preview_kind := private.chat_notification_message_kind(
    new.message_kind,
    new.payload
  );
  preview := private.chat_notification_preview(
    new.message_kind,
    new.content,
    new.payload
  );
  for follower in
    select cf.profile_id from public.club_followers cf
    where cf.club_id = new.club_id and cf.profile_id <> new.sender_auth_id
  loop
    perform private.enqueue_localized_notification(
      follower.profile_id, new.sender_auth_id, 'club_channel_message',
      club_name, club_name || ': ' || preview,
      'message', new.club_id,
      'club_channel_message:' || new.id::text || ':' || follower.profile_id::text,
      jsonb_build_object(
        'actorName', club_name,
        'clubName', club_name,
        'content', preview,
        'messageKind', preview_kind
      )
    );
  end loop;
  return new;
end;
$$;

create or replace function private.notify_club_inbox_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  conversation record; club_name text; actor_name text; preview text;
  preview_kind text; recipient record;
begin
  select cit.id, cit.club_id, cit.profile_id into conversation
  from public.club_inbox_threads cit where cit.id = new.thread_id;
  select coalesce(nullif(c.name, ''), 'A club') into club_name
  from public.clubs c where c.id = conversation.club_id;
  preview_kind := private.chat_notification_message_kind(
    new.message_kind,
    new.payload
  );
  preview := private.chat_notification_preview(
    new.message_kind,
    new.content,
    new.payload
  );

  if new.sender_profile_id = conversation.profile_id then
    select coalesce(nullif(p.full_name, ''), 'Someone') into actor_name
    from public.profiles p where p.id = conversation.profile_id;
    for recipient in
      select ca.auth_user_id as user_id from public.club_auth_accounts ca
      where ca.club_id = conversation.club_id
      union
      select cf.profile_id as user_id from public.club_followers cf
      where cf.club_id = conversation.club_id and cf.role = 'board_member'
    loop
      if recipient.user_id <> new.sender_auth_id then
        perform private.enqueue_localized_notification(
          recipient.user_id, new.sender_auth_id, 'club_inbox_message',
          coalesce(actor_name, 'Someone'),
          coalesce(actor_name, 'Someone') || ': ' || preview,
          'message', conversation.id,
          'club_inbox_message:' || new.id::text || ':' || recipient.user_id::text,
          jsonb_build_object(
            'actorName', coalesce(actor_name, 'Someone'),
            'clubName', club_name,
            'content', preview,
            'messageKind', preview_kind
          )
        );
      end if;
    end loop;
  else
    perform private.enqueue_localized_notification(
      conversation.profile_id, new.sender_auth_id, 'club_inbox_message',
      club_name, club_name || ': ' || preview,
      'message', conversation.id,
      'club_inbox_message:' || new.id::text || ':' || conversation.profile_id::text,
      jsonb_build_object(
        'actorName', club_name,
        'clubName', club_name,
        'content', preview,
        'messageKind', preview_kind
      )
    );
  end if;
  return new;
end;
$$;

revoke all on function private.notify_direct_message()
  from public, anon, authenticated;
revoke all on function private.notify_group_message()
  from public, anon, authenticated;
revoke all on function private.notify_club_channel_message()
  from public, anon, authenticated;
revoke all on function private.notify_club_inbox_message()
  from public, anon, authenticated;
