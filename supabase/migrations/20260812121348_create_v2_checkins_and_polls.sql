-- F2/F3 opt-in secure mutation APIs for the new app.
--
-- The released app keeps its existing direct table contracts. These RPCs use
-- the same canonical tables, so v1 and v2 clients immediately see each
-- other's changes. Identity is always derived from auth.uid(); no v2 function
-- accepts a caller-supplied actor or voter identity.

create or replace function public.check_in_event_v2(
  p_event_id uuid,
  p_profile_id uuid,
  p_method text default 'manual'
)
returns public.event_checkins
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_checkin public.event_checkins;
begin
  if v_actor is null then
    raise exception 'An authenticated actor is required' using errcode = '42501';
  end if;
  if p_event_id is null or p_profile_id is null then
    raise exception 'Event and profile are required' using errcode = '22004';
  end if;
  if p_method is null or p_method not in ('manual', 'qr') then
    raise exception 'Invalid check-in method' using errcode = '22023';
  end if;
  if not (select private.can_manage_event(p_event_id)) then
    raise exception 'Not authorized to manage this event' using errcode = '42501';
  end if;

  perform private.enforce_authenticated_rate_limit(
    'event_checkin_change:actor',
    null
  );
  perform private.enforce_authenticated_rate_limit(
    'event_checkin_change:resource',
    p_event_id::text
  );

  insert into public.event_checkins (
    event_id,
    profile_id,
    checked_in_by,
    method
  ) values (
    p_event_id,
    p_profile_id,
    v_actor,
    p_method
  )
  on conflict (event_id, profile_id) do nothing
  returning * into v_checkin;

  if v_checkin.id is null then
    select checkin.* into strict v_checkin
    from public.event_checkins as checkin
    where checkin.event_id = p_event_id
      and checkin.profile_id = p_profile_id;
  end if;

  return v_checkin;
end
$function$;

create or replace function public.remove_event_checkin_v2(
  p_event_id uuid,
  p_profile_id uuid
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_deleted boolean := false;
begin
  if v_actor is null then
    raise exception 'An authenticated actor is required' using errcode = '42501';
  end if;
  if p_event_id is null or p_profile_id is null then
    raise exception 'Event and profile are required' using errcode = '22004';
  end if;
  if not (select private.can_manage_event(p_event_id)) then
    raise exception 'Not authorized to manage this event' using errcode = '42501';
  end if;

  perform private.enforce_authenticated_rate_limit(
    'event_checkin_change:actor',
    null
  );
  perform private.enforce_authenticated_rate_limit(
    'event_checkin_change:resource',
    p_event_id::text
  );

  delete from public.event_checkins as checkin
  where checkin.event_id = p_event_id
    and checkin.profile_id = p_profile_id;
  v_deleted := found;

  return v_deleted;
end
$function$;

create or replace function public.create_poll_v2(
  p_post_id uuid,
  p_question text,
  p_options jsonb
)
returns public.polls
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_poll public.polls;
begin
  if v_actor is null then
    raise exception 'An authenticated actor is required' using errcode = '42501';
  end if;
  if p_post_id is null then
    raise exception 'Post is required' using errcode = '22004';
  end if;
  if p_question is null or char_length(btrim(p_question)) not between 1 and 500 then
    raise exception 'Poll question must contain 1 to 500 characters'
      using errcode = '22023';
  end if;
  if p_options is null or jsonb_typeof(p_options) <> 'array' then
    raise exception 'Poll options must be a JSON array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_options) not between 2 and 10 then
    raise exception 'Poll must contain 2 to 10 options' using errcode = '22023';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_options) as option(value)
    where jsonb_typeof(option.value) <> 'string'
      or char_length(btrim(option.value #>> '{}')) not between 1 and 200
  ) then
    raise exception 'Each poll option must be a non-empty string of at most 200 characters'
      using errcode = '22023';
  end if;
  if (
    select count(distinct lower(btrim(option.value #>> '{}')))
    from jsonb_array_elements(p_options) as option(value)
  ) <> jsonb_array_length(p_options) then
    raise exception 'Poll options must be unique' using errcode = '22023';
  end if;
  if not (select private.can_manage_poll_post(p_post_id)) then
    raise exception 'Not authorized to create a poll for this post'
      using errcode = '42501';
  end if;

  perform private.enforce_authenticated_rate_limit('poll_create:actor', null);
  perform private.enforce_authenticated_rate_limit(
    'poll_create:resource',
    p_post_id::text
  );

  insert into public.polls (post_id, question, options)
  values (p_post_id, btrim(p_question), p_options)
  returning * into v_poll;

  return v_poll;
end
$function$;

create or replace function public.vote_poll_v2(
  p_poll_id uuid,
  p_option_index integer
)
returns public.poll_votes
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_option_count integer;
  v_vote public.poll_votes;
begin
  if v_actor is null then
    raise exception 'An authenticated voter is required' using errcode = '42501';
  end if;
  if p_poll_id is null or p_option_index is null then
    raise exception 'Poll and option are required' using errcode = '22004';
  end if;

  select jsonb_array_length(poll.options) into v_option_count
  from public.polls as poll
  where poll.id = p_poll_id;
  if v_option_count is null then
    raise exception 'Poll does not exist or is not visible' using errcode = '23503';
  end if;
  if p_option_index < 0 or p_option_index >= v_option_count then
    raise exception 'Poll option index is out of range' using errcode = '23514';
  end if;

  perform private.enforce_authenticated_rate_limit('poll_vote_change:actor', null);
  perform private.enforce_authenticated_rate_limit(
    'poll_vote_change:resource',
    p_poll_id::text
  );

  insert into public.poll_votes (poll_id, profile_id, option_index)
  values (p_poll_id, v_actor, p_option_index)
  on conflict (poll_id, profile_id) do update
    set option_index = excluded.option_index
  returning * into v_vote;

  return v_vote;
end
$function$;

create or replace function public.remove_poll_vote_v2(p_poll_id uuid)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_deleted boolean := false;
begin
  if v_actor is null then
    raise exception 'An authenticated voter is required' using errcode = '42501';
  end if;
  if p_poll_id is null then
    raise exception 'Poll is required' using errcode = '22004';
  end if;

  perform private.enforce_authenticated_rate_limit('poll_vote_change:actor', null);
  perform private.enforce_authenticated_rate_limit(
    'poll_vote_change:resource',
    p_poll_id::text
  );

  delete from public.poll_votes as vote
  where vote.poll_id = p_poll_id
    and vote.profile_id = v_actor;
  v_deleted := found;

  return v_deleted;
end
$function$;

revoke all on function public.check_in_event_v2(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.remove_event_checkin_v2(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.create_poll_v2(uuid, text, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.vote_poll_v2(uuid, integer)
  from public, anon, authenticated, service_role;
revoke all on function public.remove_poll_vote_v2(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.check_in_event_v2(uuid, uuid, text)
  to authenticated;
grant execute on function public.remove_event_checkin_v2(uuid, uuid)
  to authenticated;
grant execute on function public.create_poll_v2(uuid, text, jsonb)
  to authenticated;
grant execute on function public.vote_poll_v2(uuid, integer)
  to authenticated;
grant execute on function public.remove_poll_vote_v2(uuid)
  to authenticated;

comment on function public.check_in_event_v2(uuid, uuid, text) is
  'V2 manager check-in API. Actor is auth.uid(); writes canonical event_checkins.';
comment on function public.remove_event_checkin_v2(uuid, uuid) is
  'V2 manager check-in removal API. Actor is auth.uid(); deletes canonical event_checkins.';
comment on function public.create_poll_v2(uuid, text, jsonb) is
  'V2 authorized poll creation API using canonical polls.';
comment on function public.vote_poll_v2(uuid, integer) is
  'V2 vote/upsert API. Voter is auth.uid(); writes canonical poll_votes.';
comment on function public.remove_poll_vote_v2(uuid) is
  'V2 own-vote removal API. Voter is auth.uid(); deletes only the caller vote.';
