-- Ticketing is an explicit organizer choice. Existing events remain ordinary
-- RSVP events unless staff already issued tickets under the earlier version.
-- Neither creating an event nor RSVPing issues any tickets.
alter table public.events add column is_ticketed boolean not null default false;
-- Preserve admissions already explicitly issued before this opt-in rollout.
update public.events e set is_ticketed = true
  where exists (select 1 from public.event_tickets t where t.event_id = e.id);

-- Preserve released create/edit RPC contracts. New clients save the setting
-- in the same transaction as the event, using existing validation and RLS.
create function public.create_club_event_transactional_v4(
  p_event_id uuid, p_club_id uuid, p_title text, p_description text,
  p_location text, p_event_date date, p_starts_at timestamptz,
  p_ends_at timestamptz, p_audience text default 'everyone',
  p_image_path text default null, p_image_url text default null,
  p_tags text[] default '{}', p_registration_url text default null,
  p_schedule jsonb default null, p_speakers jsonb default '[]',
  p_is_ticketed boolean default false
) returns public.events language plpgsql security invoker set search_path = '' as $$
declare v_event public.events;
begin
  v_event := public.create_club_event_transactional_v3(
    p_event_id,p_club_id,p_title,p_description,p_location,p_event_date,
    p_starts_at,p_ends_at,p_audience,p_image_path,p_image_url,p_tags,
    p_registration_url,p_schedule,p_speakers
  );
  update public.events set is_ticketed = coalesce(p_is_ticketed,false)
    where id = v_event.id returning * into v_event;
  if not found then raise exception 'Not authorized' using errcode = '42501'; end if;
  return v_event;
end;
$$;

create function public.update_club_event_transactional_v3(
  p_event_id uuid, p_title text, p_description text, p_location text,
  p_event_date date, p_starts_at timestamptz, p_ends_at timestamptz,
  p_image_path text, p_image_url text, p_tags text[], p_registration_url text,
  p_schedule jsonb, p_speakers jsonb, p_is_ticketed boolean
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_result jsonb; v_event public.events;
begin
  if auth.uid() is null or not private.can_manage_event(p_event_id) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  v_result := public.update_club_event_transactional_v2(
    p_event_id,p_title,p_description,p_location,p_event_date,p_starts_at,
    p_ends_at,p_image_path,p_image_url,p_tags,p_registration_url,p_schedule,p_speakers
  );
  update public.events set is_ticketed = coalesce(p_is_ticketed,false)
    where id = p_event_id returning * into v_event;
  if not found then raise exception 'Not authorized' using errcode = '42501'; end if;
  return jsonb_set(v_result,'{entity}',to_jsonb(v_event));
end;
$$;
revoke all on function public.create_club_event_transactional_v4(uuid,uuid,text,text,text,date,timestamptz,timestamptz,text,text,text,text[],text,jsonb,jsonb,boolean),
  public.update_club_event_transactional_v3(uuid,text,text,text,date,timestamptz,timestamptz,text,text,text[],text,jsonb,jsonb,boolean) from public,anon;
grant execute on function public.create_club_event_transactional_v4(uuid,uuid,text,text,text,date,timestamptz,timestamptz,text,text,text,text[],text,jsonb,jsonb,boolean),
  public.update_club_event_transactional_v3(uuid,text,text,text,date,timestamptz,timestamptz,text,text,text[],text,jsonb,jsonb,boolean) to authenticated;

create function private.revoke_disabled_event_tickets()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.event_tickets set revoked_at = clock_timestamp(), revoked_by = auth.uid()
    where event_id = new.id and revoked_at is null;
  return new;
end;
$$;
revoke all on function private.revoke_disabled_event_tickets() from public,anon,authenticated;
create trigger revoke_disabled_event_tickets after update of is_ticketed on public.events
  for each row when (old.is_ticketed and not new.is_ticketed)
  execute function private.revoke_disabled_event_tickets();

create or replace function private.issue_event_ticket(p_event_id uuid, p_profile_id uuid, p_reissue boolean)
returns public.event_tickets language plpgsql security definer set search_path = '' as $$
declare
  v_ticket public.event_tickets;
begin
  if auth.uid() is null or not private.can_manage_event(p_event_id) then
    raise exception 'Not authorized to manage this event' using errcode = '42501';
  end if;
  -- Serialize against the event toggle before locking RSVP or ticket rows.
  perform 1 from public.events where id = p_event_id and is_ticketed for share;
  if not found then
    raise exception 'Ticketing is not enabled for this event' using errcode = '22023';
  end if;

  -- RSVP is the serialization point for concurrent issue/reissue/cancellation.
  perform 1 from public.event_rsvps
    where event_id = p_event_id and profile_id = p_profile_id for update;
  if not found then
    raise exception 'An RSVP is required' using errcode = '22023';
  end if;
  select * into v_ticket from public.event_tickets
    where event_id = p_event_id and profile_id = p_profile_id and revoked_at is null
    for update;
  if v_ticket.id is not null and not coalesce(p_reissue, false) then
    return v_ticket; -- Retried issuance is idempotent.
  end if;
  if exists (select 1 from public.event_checkins where event_id = p_event_id and profile_id = p_profile_id)
    or exists (select 1 from public.event_tickets where event_id = p_event_id and profile_id = p_profile_id and used_at is not null) then
    raise exception 'Attendee has already checked in' using errcode = '22023';
  end if;
  update public.event_tickets set revoked_at = clock_timestamp(), revoked_by = auth.uid()
    where id = v_ticket.id;
  insert into public.event_tickets(event_id, profile_id, issued_by)
    values (p_event_id, p_profile_id, auth.uid()) returning * into v_ticket;
  return v_ticket;
end;
$$;


create or replace function private.scan_event_ticket(p_event_id uuid, p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_ticket public.event_tickets;
  v_checkin_id uuid;
begin
  -- Check permissions before token lookup, including for unknown/foreign tokens.
  if auth.uid() is null or not private.can_manage_event(p_event_id) then
    raise exception 'Not authorized to manage this event' using errcode = '42501';
  end if;
  -- Serialize against the event toggle before locking RSVP or ticket rows.
  perform 1 from public.events where id = p_event_id and is_ticketed for share;
  if not found then
    return jsonb_build_object('status', 'invalid');
  end if;

  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('status', 'invalid');
  end if;
  select * into v_ticket from public.event_tickets where token = p_token;
  if not found then return jsonb_build_object('status', 'invalid'); end if;
  if v_ticket.event_id <> p_event_id then
    -- No holder, event, or ticket details escape across event boundaries.
    return jsonb_build_object('status', 'wrong_event');
  end if;
  -- Use the same RSVP -> ticket lock order as issuance and cancellation.
  perform 1 from public.event_rsvps where event_id = p_event_id
    and profile_id = v_ticket.profile_id for key share;
  if not found then return jsonb_build_object('status', 'revoked'); end if;
  select * into v_ticket from public.event_tickets where token = p_token for update;
  if not found then return jsonb_build_object('status', 'invalid'); end if;
  if v_ticket.revoked_at is not null then return jsonb_build_object('status', 'revoked'); end if;
  if v_ticket.used_at is not null then return jsonb_build_object('status', 'already_used'); end if;
  -- The canonical unique (event_id, profile_id) also arbitrates races with
  -- manual check-in. A conflict never reports a new admission.
  insert into public.event_checkins(event_id, profile_id, checked_in_by, method)
    values (p_event_id, v_ticket.profile_id, auth.uid(), 'qr')
    on conflict (event_id, profile_id) do nothing returning id into v_checkin_id;
  update public.event_tickets set used_at = clock_timestamp(), used_by = auth.uid()
    where id = v_ticket.id;
  if v_checkin_id is null then return jsonb_build_object('status', 'already_used'); end if;
  return jsonb_build_object('status', 'checked_in', 'profile_id', v_ticket.profile_id);
end;
$$;


create or replace function public.can_manage_event_tickets(p_event_id uuid)
returns boolean language sql stable security invoker set search_path = '' as $$
  select auth.uid() is not null and private.can_manage_event(p_event_id)
    and exists (select 1 from public.events where id = p_event_id and is_ticketed);
$$;

-- Carry the flag through the existing bounded event rail payload.
create or replace function public.get_feed_page_v2(
  p_limit integer default 25,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null,
  p_followed_only boolean default false
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 25), 1), 50);
  v_items jsonb := '[]'::jsonb;
  v_events jsonb := '[]'::jsonb;
  v_people jsonb := '[]'::jsonb;
  v_clubs jsonb := '[]'::jsonb;
  v_next_cursor jsonb;
  v_has_more boolean := false;
begin
  if v_uid is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication required';
  end if;

  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Both cursor fields must be provided together';
  end if;

  with candidate as materialized (
    select
      post.id,
      post.club_id,
      post.author_id,
      post.content,
      coalesce(post.image_url, post.image_path) as image_path,
      post.is_announcement,
      post.created_at,
      club.name as club_name,
      club.short_name as club_short_name,
      club.description as club_description,
      club.logo_url as club_logo_url,
      club.category_id as club_category_id,
      club.created_at as club_created_at,
      author.full_name as author_name,
      author.avatar_url as author_avatar_url,
      author.role as author_role,
      exists (
        select 1
        from public.club_followers as viewer_follow
        where viewer_follow.club_id = post.club_id
          and viewer_follow.profile_id = v_uid
      ) as viewer_follows_club
    from public.club_posts as post
    join public.clubs as club on club.id = post.club_id
    left join public.profiles as author on author.id = post.author_id
    where club.is_active is true
      and (
        p_cursor_created_at is null
        or (post.created_at, post.id) < (p_cursor_created_at, p_cursor_id)
      )
      and not exists (
        select 1
        from public.club_blocks as blocked_club
        where blocked_club.blocker_id = v_uid
          and blocked_club.club_id = post.club_id
      )
      and not exists (
        select 1
        from public.user_blocks as blocked_author
        where blocked_author.blocker_id = v_uid
          and blocked_author.blocked_id = post.author_id
      )
      and (
        not coalesce(p_followed_only, false)
        or exists (
          select 1
          from public.club_followers as followed_club
          where followed_club.club_id = post.club_id
            and followed_club.profile_id = v_uid
        )
      )
    order by post.created_at desc, post.id desc
    limit v_limit + 1
  ),
  page as materialized (
    select *
    from candidate
    order by created_at desc, id desc
    limit v_limit
  ),
  like_counts as (
    select
      post_like.post_id,
      count(*)::integer as like_count,
      bool_or(post_like.profile_id = v_uid) as viewer_has_liked
    from public.post_likes as post_like
    join page on page.id = post_like.post_id
    group by post_like.post_id
  ),
  first_visible_liker as (
    select distinct on (post_like.post_id)
      post_like.post_id,
      liker.id as liker_id,
      liker.full_name as liker_name,
      liker.avatar_url as liker_avatar_url
    from public.post_likes as post_like
    join page on page.id = post_like.post_id
    join public.profiles as liker on liker.id = post_like.profile_id
    where not exists (
      select 1
      from public.user_blocks as blocked_liker
      where blocked_liker.blocker_id = v_uid
        and blocked_liker.blocked_id = liker.id
    )
    order by post_like.post_id, post_like.created_at, post_like.id
  ),
  comment_counts as (
    select comment.post_id, count(*)::integer as comment_count
    from public.post_comments as comment
    join page on page.id = comment.post_id
    where not exists (
      select 1
      from public.user_blocks as blocked_commenter
      where blocked_commenter.blocker_id = v_uid
        and blocked_commenter.blocked_id = comment.profile_id
    )
    group by comment.post_id
  ),
  view_counts as (
    select post_view.post_id, count(*)::integer as view_count
    from public.post_views as post_view
    join page on page.id = post_view.post_id
    group by post_view.post_id
  ),
  page_polls as materialized (
    select poll.id, poll.post_id, poll.question, poll.options
    from public.polls as poll
    join page on page.id = poll.post_id
  ),
  poll_option_counts as (
    select
      vote.poll_id,
      vote.option_index,
      count(*)::integer as vote_count
    from public.poll_votes as vote
    join page_polls as poll on poll.id = vote.poll_id
    group by vote.poll_id, vote.option_index
  ),
  poll_summaries as (
    select
      poll.id as poll_id,
      coalesce(sum(option_count.vote_count), 0)::integer as total_votes,
      coalesce(
        jsonb_object_agg(
          option_count.option_index::text,
          option_count.vote_count
          order by option_count.option_index
        ) filter (where option_count.option_index is not null),
        '{}'::jsonb
      ) as option_counts
    from page_polls as poll
    left join poll_option_counts as option_count on option_count.poll_id = poll.id
    group by poll.id
  ),
  viewer_poll_votes as (
    select vote.poll_id, vote.option_index
    from public.poll_votes as vote
    join page_polls as poll on poll.id = vote.poll_id
    where vote.profile_id = v_uid
  ),
  assembled as (
    select
      page.created_at,
      page.id,
      jsonb_build_object(
        'id', page.id,
        'type', 'post',
        'created_at', page.created_at,
        'content', page.content,
        'media_url', page.image_path,
        'is_announcement', page.is_announcement,
        'club', jsonb_build_object(
          'id', page.club_id,
          'name', page.club_name,
          'short_name', page.club_short_name,
          'description', page.club_description,
          'logo_url', page.club_logo_url,
          'category_id', page.club_category_id,
          'created_at', page.club_created_at
        ),
        'author', case
          when page.author_id is null then null
          else jsonb_build_object(
            'id', page.author_id,
            'name', page.author_name,
            'avatar_url', page.author_avatar_url,
            'role', page.author_role
          )
        end,
        'engagement', jsonb_build_object(
          'like_count', coalesce(like_counts.like_count, 0),
          'comment_count', coalesce(comment_counts.comment_count, 0),
          'view_count', coalesce(view_counts.view_count, 0),
          'viewer_has_liked', coalesce(like_counts.viewer_has_liked, false),
          'first_liker', case
            when first_visible_liker.liker_id is null then null
            else jsonb_build_object(
              'id', first_visible_liker.liker_id,
              'name', first_visible_liker.liker_name,
              'avatar_url', first_visible_liker.liker_avatar_url
            )
          end
        ),
        'viewer', jsonb_build_object(
          'follows_club', page.viewer_follows_club
        ),
        'poll', case
          when page_polls.id is null then null
          else jsonb_build_object(
            'id', page_polls.id,
            'question', page_polls.question,
            'options', page_polls.options,
            'total_votes', coalesce(poll_summaries.total_votes, 0),
            'option_counts', coalesce(poll_summaries.option_counts, '{}'::jsonb),
            'viewer_option_index', viewer_poll_votes.option_index
          )
        end
      ) as card
    from page
    left join like_counts on like_counts.post_id = page.id
    left join first_visible_liker on first_visible_liker.post_id = page.id
    left join comment_counts on comment_counts.post_id = page.id
    left join view_counts on view_counts.post_id = page.id
    left join page_polls on page_polls.post_id = page.id
    left join poll_summaries on poll_summaries.poll_id = page_polls.id
    left join viewer_poll_votes on viewer_poll_votes.poll_id = page_polls.id
  )
  select
    coalesce(
      jsonb_agg(assembled.card order by assembled.created_at desc, assembled.id desc),
      '[]'::jsonb
    ),
    (select count(*) > v_limit from candidate),
    case
      when (select count(*) > v_limit from candidate) then (
        select jsonb_build_object('created_at', page.created_at, 'id', page.id)
        from page
        order by page.created_at asc, page.id asc
        limit 1
      )
      else null
    end
  into v_items, v_has_more, v_next_cursor
  from assembled;

  -- Auxiliary first-page data keeps the Home event rail and recommendation
  -- cards from falling back to the legacy all-history loader. Later pages do
  -- not repeat it.
  if p_cursor_created_at is null then
    with upcoming as materialized (
      select
        event.id,
        event.club_id,
        event.title,
        coalesce(event.description, '') as description,
        coalesce(event.location, '') as location,
        coalesce(event.image_url, event.image_path) as image_path,
        event.starts_at,
        coalesce(event.ends_at, event.starts_at) as ends_at,
        event.created_by_user_id,
        event.tags,
        event.registration_url,
        event.is_ticketed,
        event.schedule,
        event.speakers,
        club.name as club_name,
        club.short_name as club_short_name,
        club.description as club_description,
        club.logo_url as club_logo_url,
        club.category_id as club_category_id,
        club.created_at as club_created_at
      from public.events as event
      join public.clubs as club on club.id = event.club_id
      where club.is_active is true
        and coalesce(event.ends_at, event.starts_at) >= now() - interval '2 hours'
        and event.starts_at < now() + interval '7 days'
        and not exists (
          select 1
          from public.club_blocks as blocked_club
          where blocked_club.blocker_id = v_uid
            and blocked_club.club_id = event.club_id
        )
      order by event.starts_at, event.id
      limit 10
    ),
    rsvp_counts as (
      select
        rsvp.event_id,
        count(*)::integer as rsvp_count,
        bool_or(rsvp.profile_id = v_uid) as viewer_is_attending
      from public.event_rsvps as rsvp
      join upcoming on upcoming.id = rsvp.event_id
      group by rsvp.event_id
    )
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', upcoming.id,
          'title', upcoming.title,
          'description', upcoming.description,
          'location', upcoming.location,
          'media_url', upcoming.image_path,
          'starts_at', upcoming.starts_at,
          'ends_at', upcoming.ends_at,
          'created_by_user_id', upcoming.created_by_user_id,
          'tags', upcoming.tags,
          'registration_url', upcoming.registration_url,
          'is_ticketed', upcoming.is_ticketed,
          'schedule', upcoming.schedule,
          'speakers', upcoming.speakers,
          'rsvp_count', coalesce(rsvp_counts.rsvp_count, 0),
          'viewer_is_attending', coalesce(rsvp_counts.viewer_is_attending, false),
          'club', jsonb_build_object(
            'id', upcoming.club_id,
            'name', upcoming.club_name,
            'short_name', upcoming.club_short_name,
            'description', upcoming.club_description,
            'logo_url', upcoming.club_logo_url,
            'category_id', upcoming.club_category_id,
            'created_at', upcoming.club_created_at
          )
        ) order by upcoming.starts_at, upcoming.id
      ),
      '[]'::jsonb
    )
    into v_events
    from upcoming
    left join rsvp_counts on rsvp_counts.event_id = upcoming.id;

    with suggested as (
      select
        profile.id,
        profile.full_name,
        profile.avatar_url,
        profile.bio,
        exists (
          select 1
          from public.profile_follows as follower
          where follower.follower_id = profile.id
            and follower.following_id = v_uid
        ) as follows_viewer
      from public.profiles as profile
      where profile.role = 'student'
        and profile.id <> v_uid
        and not exists (
          select 1
          from public.profile_follows as already_followed
          where already_followed.follower_id = v_uid
            and already_followed.following_id = profile.id
        )
        and not exists (
          select 1
          from public.user_blocks as blocked_profile
          where blocked_profile.blocker_id = v_uid
            and blocked_profile.blocked_id = profile.id
        )
      order by follows_viewer desc, profile.created_at desc, profile.id
      limit 8
    )
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', suggested.id,
          'name', suggested.full_name,
          'avatar_url', suggested.avatar_url,
          'bio', suggested.bio,
          'follows_viewer', suggested.follows_viewer
        ) order by suggested.follows_viewer desc, suggested.id
      ),
      '[]'::jsonb
    )
    into v_people
    from suggested;

    with suggested as (
      select
        club.id,
        club.name,
        club.short_name,
        club.description,
        club.logo_url,
        club.category_id,
        club.created_at,
        count(member.id)::integer as member_count
      from public.clubs as club
      left join public.club_followers as member on member.club_id = club.id
      where club.is_active is true
        and not exists (
          select 1
          from public.club_followers as already_followed
          where already_followed.club_id = club.id
            and already_followed.profile_id = v_uid
        )
        and not exists (
          select 1
          from public.club_blocks as blocked_club
          where blocked_club.blocker_id = v_uid
            and blocked_club.club_id = club.id
        )
      group by
        club.id, club.name, club.short_name, club.description, club.logo_url,
        club.category_id, club.created_at
      order by member_count desc, club.created_at desc, club.id
      limit 3
    )
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', suggested.id,
          'name', suggested.name,
          'short_name', suggested.short_name,
          'description', suggested.description,
          'logo_url', suggested.logo_url,
          'category_id', suggested.category_id,
          'created_at', suggested.created_at,
          'member_count', suggested.member_count
        ) order by suggested.member_count desc, suggested.id
      ),
      '[]'::jsonb
    )
    into v_clubs
    from suggested;
  end if;

  return jsonb_build_object(
    'version', 2,
    'page_size', v_limit,
    'items', v_items,
    'has_more', v_has_more,
    'next_cursor', v_next_cursor,
    'upcoming_events', v_events,
    'suggested_people', v_people,
    'suggested_clubs', v_clubs
  );
end;
$$;

notify pgrst, 'reload schema';
