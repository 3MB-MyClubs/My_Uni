-- Fix the notification trigger's PL/pgSQL variable/column name collision.
-- The previous function declared `club_id` and also referenced
-- `club_auth_accounts.club_id` unqualified, which raises PostgreSQL 42702 on
-- post_comments inserts.

create or replace function private.notify_club_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner record;
  actor_name text;
  target_club_id uuid;
  item_title text;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone')
    into actor_name
  from public.profiles as p
  where p.id = new.profile_id;

  if tg_table_name = 'event_rsvps' then
    select e.club_id, e.title
      into target_club_id, item_title
    from public.events as e
    where e.id = new.event_id;
  else
    select p.club_id, left(p.content, 80)
      into target_club_id, item_title
    from public.club_posts as p
    where p.id = new.post_id;
  end if;

  for owner in
    select a.auth_user_id
    from public.club_auth_accounts as a
    where a.club_id = target_club_id
  loop
    if tg_table_name = 'post_likes' then
      perform private.enqueue_localized_notification(
        owner.auth_user_id, new.profile_id, 'post_like',
        coalesce(actor_name, 'Someone') || ' liked your post',
        coalesce(actor_name, 'Someone') || ' liked your post “' || coalesce(item_title, 'your latest post') || '”.',
        'post', new.post_id,
        'post_like:' || new.id::text || ':' || owner.auth_user_id::text,
        jsonb_build_object(
          'actorName', coalesce(actor_name, 'Someone'),
          'postPreview', coalesce(item_title, 'your latest post')
        )
      );
    elsif tg_table_name = 'post_comments' then
      perform private.enqueue_localized_notification(
        owner.auth_user_id, new.profile_id, 'post_comment',
        coalesce(actor_name, 'Someone') || ' commented on your post',
        coalesce(actor_name, 'Someone') || ' commented: “' || left(new.content, 380) || '”. Tap to reply.',
        'post', new.post_id,
        'post_comment:' || new.id::text || ':' || owner.auth_user_id::text,
        jsonb_build_object(
          'actorName', coalesce(actor_name, 'Someone'),
          'comment', left(new.content, 380)
        )
      );
    else
      perform private.enqueue_localized_notification(
        owner.auth_user_id, new.profile_id, 'event_rsvp',
        coalesce(actor_name, 'Someone') || ' is going to your event',
        coalesce(actor_name, 'Someone') || ' is going to “' || coalesce(item_title, 'your event') || '”. Your guest list is growing!',
        'event', new.event_id,
        'event_rsvp:' || new.id::text || ':' || owner.auth_user_id::text,
        jsonb_build_object(
          'actorName', coalesce(actor_name, 'Someone'),
          'eventTitle', coalesce(item_title, 'your event')
        )
      );
    end if;
  end loop;

  return new;
end;
$$;
