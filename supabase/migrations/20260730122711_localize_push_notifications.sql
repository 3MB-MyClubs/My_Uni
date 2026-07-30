alter table public.push_devices
  add column locale text not null default 'en'
  check (locale in ('en', 'tr'));

alter table public.notifications
  add column localization_args jsonb not null default '{}'::jsonb
  check (jsonb_typeof(localization_args) = 'object');

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
    dedupe_key, localization_args
  ) values (
    recipient_id,
    actor_id,
    notification_type,
    left(notification_title, 160),
    left(notification_body, 500),
    notification_target_type,
    notification_target_id,
    notification_dedupe_key,
    coalesce(notification_localization_args, '{}'::jsonb)
  ) on conflict (dedupe_key) do nothing;
$$;

revoke all on function private.enqueue_localized_notification(
  uuid, uuid, text, text, text, text, uuid, text, jsonb
) from public, anon, authenticated;

create or replace function private.notify_direct_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare sender_name text;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone') into sender_name
  from public.profiles p where p.id = new.sender_id;
  perform private.enqueue_localized_notification(
    new.receiver_id, new.sender_id, 'direct_message',
    coalesce(sender_name, 'New message'),
    coalesce(sender_name, 'Someone') || ': ' || left(new.content, 440),
    'message', new.sender_id, 'direct_message:' || new.id::text,
    jsonb_build_object('actorName', coalesce(sender_name, 'Someone'), 'content', left(new.content, 440))
  );
  return new;
end;
$$;

create or replace function private.notify_group_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare sender_name text; group_name text; member record;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone') into sender_name
  from public.profiles p where p.id = new.sender_id;
  select coalesce(nullif(g.custom_name, ''), 'Group chat') into group_name
  from public.group_chats g where g.id = new.group_id;
  for member in
    select m.user_id from public.group_chat_members m
    where m.group_id = new.group_id and m.user_id <> new.sender_id
  loop
    perform private.enqueue_localized_notification(
      member.user_id, new.sender_id, 'group_message',
      coalesce(group_name, 'Group chat'),
      coalesce(sender_name, 'Someone') || ': ' || left(new.content, 440),
      'message', new.group_id,
      'group_message:' || new.id::text || ':' || member.user_id::text,
      jsonb_build_object(
        'actorName', coalesce(sender_name, 'Someone'),
        'groupName', coalesce(group_name, 'Group chat'),
        'content', left(new.content, 440)
      )
    );
  end loop;
  return new;
end;
$$;

create or replace function private.notify_club_post()
returns trigger language plpgsql security definer set search_path = '' as $$
declare club_name text; follower record;
begin
  select c.name into club_name from public.clubs c where c.id = new.club_id;
  for follower in select f.profile_id from public.club_followers f where f.club_id = new.club_id loop
    perform private.enqueue_localized_notification(
      follower.profile_id, null, 'club_post',
      coalesce(club_name, 'A club') || ' posted something new',
      coalesce(club_name, 'A club') || ' shared “' || left(new.content, 360) || '”. Tap to view the post.',
      'post', new.id,
      'club_post:' || new.id::text || ':' || follower.profile_id::text,
      jsonb_build_object('clubName', coalesce(club_name, 'A club'), 'content', left(new.content, 360))
    );
  end loop;
  return new;
end;
$$;

create or replace function private.notify_club_event()
returns trigger language plpgsql security definer set search_path = '' as $$
declare club_name text; follower record;
begin
  select c.name into club_name from public.clubs c where c.id = new.club_id;
  for follower in select f.profile_id from public.club_followers f where f.club_id = new.club_id loop
    perform private.enqueue_localized_notification(
      follower.profile_id, null, 'club_event',
      'New event from ' || coalesce(club_name, 'a club'),
      coalesce(club_name, 'A club') || ' announced “' || left(new.title, 300) || '”. Tap for details and RSVP.',
      'event', new.id,
      'club_event:' || new.id::text || ':' || follower.profile_id::text,
      jsonb_build_object('clubName', coalesce(club_name, 'A club'), 'eventTitle', left(new.title, 300))
    );
  end loop;
  return new;
end;
$$;

create or replace function private.notify_profile_follow()
returns trigger language plpgsql security definer set search_path = '' as $$
declare follower_name text;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone') into follower_name
  from public.profiles p where p.id = new.follower_id;
  perform private.enqueue_localized_notification(
    new.following_id, new.follower_id, 'profile_follow',
    coalesce(follower_name, 'Someone') || ' followed you',
    coalesce(follower_name, 'Someone') || ' started following you. Tap to view their profile.',
    'user', new.follower_id, 'profile_follow:' || new.id::text,
    jsonb_build_object('actorName', coalesce(follower_name, 'Someone'))
  );
  return new;
end;
$$;

create or replace function private.notify_club_activity()
returns trigger language plpgsql security definer set search_path = '' as $$
declare owner record; actor_name text; club_id uuid; item_title text;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone') into actor_name
  from public.profiles p where p.id = new.profile_id;

  if tg_table_name = 'event_rsvps' then
    select e.club_id, e.title into club_id, item_title
    from public.events e where e.id = new.event_id;
  else
    select p.club_id, left(p.content, 80) into club_id, item_title
    from public.club_posts p where p.id = new.post_id;
  end if;

  for owner in select a.auth_user_id from public.club_auth_accounts a where a.club_id = club_id loop
    if tg_table_name = 'post_likes' then
      perform private.enqueue_localized_notification(
        owner.auth_user_id, new.profile_id, 'post_like',
        coalesce(actor_name, 'Someone') || ' liked your post',
        coalesce(actor_name, 'Someone') || ' liked your post “' || coalesce(item_title, 'your latest post') || '”.',
        'post', new.post_id,
        'post_like:' || new.id::text || ':' || owner.auth_user_id::text,
        jsonb_build_object('actorName', coalesce(actor_name, 'Someone'), 'postPreview', coalesce(item_title, 'your latest post'))
      );
    elsif tg_table_name = 'post_comments' then
      perform private.enqueue_localized_notification(
        owner.auth_user_id, new.profile_id, 'post_comment',
        coalesce(actor_name, 'Someone') || ' commented on your post',
        coalesce(actor_name, 'Someone') || ' commented: “' || left(new.content, 380) || '”. Tap to reply.',
        'post', new.post_id,
        'post_comment:' || new.id::text || ':' || owner.auth_user_id::text,
        jsonb_build_object('actorName', coalesce(actor_name, 'Someone'), 'comment', left(new.content, 380))
      );
    else
      perform private.enqueue_localized_notification(
        owner.auth_user_id, new.profile_id, 'event_rsvp',
        coalesce(actor_name, 'Someone') || ' is going to your event',
        coalesce(actor_name, 'Someone') || ' is going to “' || coalesce(item_title, 'your event') || '”. Your guest list is growing!',
        'event', new.event_id,
        'event_rsvp:' || new.id::text || ':' || owner.auth_user_id::text,
        jsonb_build_object('actorName', coalesce(actor_name, 'Someone'), 'eventTitle', coalesce(item_title, 'your event'))
      );
    end if;
  end loop;
  return new;
end;
$$;
