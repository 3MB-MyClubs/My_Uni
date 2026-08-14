-- Additive Feed v2 read path. The released application continues using the
-- existing tables and reads; this RPC is only for new clients.

-- This column is part of the historical 003 migration. Keeping the guard here
-- makes the isolated production-shaped test baseline match that contract.
alter table public.club_posts
  add column if not exists is_announcement boolean not null default false;

-- The legacy feed had only a (club_id, created_at) index and therefore could
-- not satisfy the global stable feed order without sorting the full visible
-- history. This is the access path used by the v2 keyset predicate/order.
create index if not exists club_posts_feed_v2_order_idx
  on public.club_posts (created_at desc, id desc)
  include (club_id);

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

comment on function public.get_feed_page_v2(integer, timestamptz, uuid, boolean)
is 'RLS-aware keyset Feed v2 page. Viewer state is always derived from auth.uid().';

revoke all on function public.get_feed_page_v2(integer, timestamptz, uuid, boolean)
  from public, anon;
grant execute on function public.get_feed_page_v2(integer, timestamptz, uuid, boolean)
  to authenticated;
