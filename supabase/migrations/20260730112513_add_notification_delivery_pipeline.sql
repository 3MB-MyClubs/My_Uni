create extension if not exists pg_net with schema extensions;

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  actor_user_id uuid references auth.users (id) on delete set null,
  type text not null check (type in (
    'direct_message', 'group_message', 'club_post', 'club_event',
    'post_like', 'post_comment', 'event_rsvp', 'profile_follow'
  )),
  title text not null check (char_length(title) between 1 and 160),
  body text not null check (char_length(body) between 1 and 500),
  target_type text not null check (target_type in ('message', 'post', 'event', 'user')),
  target_id uuid not null,
  dedupe_key text not null unique,
  read_at timestamptz,
  push_started_at timestamptz,
  push_sent_at timestamptz,
  push_error text,
  created_at timestamptz not null default now()
);

create index notifications_user_created_idx
  on public.notifications (user_id, created_at desc);
create index notifications_unsent_idx
  on public.notifications (created_at)
  where push_sent_at is null;

alter table public.notifications enable row level security;
revoke all on table public.notifications from anon;
grant select on table public.notifications to authenticated;
grant update (read_at) on table public.notifications to authenticated;
grant all on table public.notifications to service_role;

create policy "Users can read their own notifications"
  on public.notifications for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can mark their own notifications read"
  on public.notifications for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.enqueue_notification(
  recipient_id uuid,
  actor_id uuid,
  notification_type text,
  notification_title text,
  notification_body text,
  notification_target_type text,
  notification_target_id uuid,
  notification_dedupe_key text
) returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (
    user_id, actor_user_id, type, title, body, target_type, target_id, dedupe_key
  ) values (
    recipient_id,
    actor_id,
    notification_type,
    left(notification_title, 160),
    left(notification_body, 500),
    notification_target_type,
    notification_target_id,
    notification_dedupe_key
  ) on conflict (dedupe_key) do nothing;
$$;

revoke all on function private.enqueue_notification(uuid, uuid, text, text, text, text, uuid, text)
  from public, anon, authenticated;

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
    perform private.enqueue_notification(
      member.user_id, new.sender_id, 'group_message',
      coalesce(group_name, 'Group chat'), coalesce(sender_name, 'Someone') || ': ' || left(new.content, 440),
      'message', new.group_id,
      'group_message:' || new.id::text || ':' || member.user_id::text
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

revoke all on function private.notify_direct_message() from public, anon, authenticated;
revoke all on function private.notify_group_message() from public, anon, authenticated;
revoke all on function private.notify_club_post() from public, anon, authenticated;
revoke all on function private.notify_club_event() from public, anon, authenticated;
revoke all on function private.notify_profile_follow() from public, anon, authenticated;
revoke all on function private.notify_club_activity() from public, anon, authenticated;

create trigger direct_message_notification after insert on public.direct_messages
  for each row execute function private.notify_direct_message();
create trigger group_message_notification after insert on public.group_messages
  for each row execute function private.notify_group_message();
create trigger club_post_notification after insert on public.club_posts
  for each row execute function private.notify_club_post();
create trigger club_event_notification after insert on public.events
  for each row execute function private.notify_club_event();
create trigger profile_follow_notification after insert on public.profile_follows
  for each row execute function private.notify_profile_follow();
create trigger post_like_notification after insert on public.post_likes
  for each row execute function private.notify_club_activity();
create trigger post_comment_notification after insert on public.post_comments
  for each row execute function private.notify_club_activity();
create trigger event_rsvp_notification after insert on public.event_rsvps
  for each row execute function private.notify_club_activity();

-- The legacy anon JWT is a public client credential. It authorizes the
-- database webhook at the Edge gateway; the function only processes a stored,
-- unclaimed notification row and never accepts notification text from callers.
create or replace function private.dispatch_notification_push()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform net.http_post(
    url := 'https://bfntlbisipxgzxdmwxkz.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmbnRsYmlzaXB4Z3p4ZG13eGt6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2Njk0MzcsImV4cCI6MjA5NDI0NTQzN30.aGQPcb8jCr4BcyzyOtV19U-T5rlnT_CPCgARGY5zRck'
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'notifications',
      'schema', 'public',
      'record', jsonb_build_object('id', new.id)
    ),
    timeout_milliseconds := 5000
  );
  return new;
end;
$$;

revoke all on function private.dispatch_notification_push()
  from public, anon, authenticated;

create trigger send_notification_push after insert on public.notifications
  for each row execute function private.dispatch_notification_push();
