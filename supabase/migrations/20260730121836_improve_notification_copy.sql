create or replace function private.notify_direct_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare sender_name text;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone') into sender_name
  from public.profiles p where p.id = new.sender_id;
  perform private.enqueue_notification(
    new.receiver_id, new.sender_id, 'direct_message',
    coalesce(sender_name, 'New message'),
    coalesce(sender_name, 'Someone') || ': ' || left(new.content, 440),
    'message', new.sender_id, 'direct_message:' || new.id::text
  );
  return new;
end;
$$;

create or replace function private.notify_club_post()
returns trigger language plpgsql security definer set search_path = '' as $$
declare club_name text; follower record;
begin
  select c.name into club_name from public.clubs c where c.id = new.club_id;
  for follower in select f.profile_id from public.club_followers f where f.club_id = new.club_id loop
    perform private.enqueue_notification(
      follower.profile_id, null, 'club_post',
      coalesce(club_name, 'A club') || ' posted something new',
      coalesce(club_name, 'A club') || ' shared “' || left(new.content, 360) || '”. Tap to view the post.',
      'post', new.id,
      'club_post:' || new.id::text || ':' || follower.profile_id::text
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
    perform private.enqueue_notification(
      follower.profile_id, null, 'club_event',
      'New event from ' || coalesce(club_name, 'a club'),
      coalesce(club_name, 'A club') || ' announced “' || left(new.title, 300) || '”. Tap for details and RSVP.',
      'event', new.id,
      'club_event:' || new.id::text || ':' || follower.profile_id::text
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
  perform private.enqueue_notification(
    new.following_id, new.follower_id, 'profile_follow',
    coalesce(follower_name, 'Someone') || ' followed you',
    coalesce(follower_name, 'Someone') || ' started following you. Tap to view their profile.',
    'user', new.follower_id, 'profile_follow:' || new.id::text
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
    select e.club_id, e.title into club_id, item_title from public.events e where e.id = new.event_id;
  else
    select p.club_id, left(p.content, 80) into club_id, item_title from public.club_posts p where p.id = new.post_id;
  end if;

  for owner in select a.auth_user_id from public.club_auth_accounts a where a.club_id = club_id loop
    if tg_table_name = 'post_likes' then
      perform private.enqueue_notification(owner.auth_user_id, new.profile_id, 'post_like',
        coalesce(actor_name, 'Someone') || ' liked your post',
        coalesce(actor_name, 'Someone') || ' liked your post “' || coalesce(item_title, 'your latest post') || '”.', 'post', new.post_id,
        'post_like:' || new.id::text || ':' || owner.auth_user_id::text);
    elsif tg_table_name = 'post_comments' then
      perform private.enqueue_notification(owner.auth_user_id, new.profile_id, 'post_comment',
        coalesce(actor_name, 'Someone') || ' commented on your post',
        coalesce(actor_name, 'Someone') || ' commented: “' || left(new.content, 380) || '”. Tap to reply.', 'post', new.post_id,
        'post_comment:' || new.id::text || ':' || owner.auth_user_id::text);
    else
      perform private.enqueue_notification(owner.auth_user_id, new.profile_id, 'event_rsvp',
        coalesce(actor_name, 'Someone') || ' is going to your event',
        coalesce(actor_name, 'Someone') || ' is going to “' || coalesce(item_title, 'your event') || '”. Your guest list is growing!', 'event', new.event_id,
        'event_rsvp:' || new.id::text || ':' || owner.auth_user_id::text);
    end if;
  end loop;
  return new;
end;
$$;
