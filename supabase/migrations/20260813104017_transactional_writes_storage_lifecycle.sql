-- Additive transactional mutations and durable Storage cleanup for v2 clients.
-- Released clients keep their existing table/RPC/Storage contracts.

create table public.storage_cleanup_queue_v2 (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null check (bucket_id in ('post-images', 'event-images')),
  object_path text not null check (
    char_length(object_path) between 1 and 1024
    and object_path !~ '(^|/)\.\.(/|$)'
    and object_path !~ '^/'
  ),
  reason text not null check (reason in (
    'create_compensation', 'media_replaced', 'entity_deleted', 'orphan_sweep'
  )),
  entity_type text not null check (entity_type in ('post', 'event')),
  entity_id uuid not null,
  club_id uuid not null references public.clubs(id) on delete cascade,
  requested_by uuid references auth.users(id) on delete set null,
  status text not null default 'pending' check (status in (
    'pending', 'processing', 'retryable', 'completed', 'terminal'
  )),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default (now() + interval '15 minutes'),
  lease_token uuid,
  lease_owner text,
  lease_expires_at timestamptz,
  last_error_category text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (bucket_id, object_path),
  constraint storage_cleanup_queue_v2_lease_shape check (
    (lease_token is null and lease_owner is null and lease_expires_at is null)
    or (lease_token is not null and lease_owner is not null and lease_expires_at is not null)
  )
);

create index storage_cleanup_queue_v2_claim_idx
  on public.storage_cleanup_queue_v2 (next_attempt_at, created_at)
  where status in ('pending', 'retryable', 'processing');

alter table public.storage_cleanup_queue_v2 enable row level security;
revoke all on table public.storage_cleanup_queue_v2 from public, anon, authenticated;
grant all on table public.storage_cleanup_queue_v2 to service_role;

insert into private.rate_limit_rules (
  action, burst_capacity, burst_window, sustained_capacity, sustained_window,
  privileged_multiplier, description
) values (
  'profile_update:actor', 10, interval '1 minute', 100, interval '1 day', 1,
  'Transactional full-profile saves per actor'
) on conflict (action) do update set
  burst_capacity=excluded.burst_capacity,burst_window=excluded.burst_window,
  sustained_capacity=excluded.sustained_capacity,sustained_window=excluded.sustained_window,
  privileged_multiplier=excluded.privileged_multiplier,description=excluded.description;

create or replace function private.enqueue_storage_cleanup_v2(
  p_bucket_id text,
  p_object_path text,
  p_reason text,
  p_entity_type text,
  p_entity_id uuid,
  p_club_id uuid,
  p_delay interval default interval '15 minutes'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_id uuid;
  v_expected_prefix text;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if not (select private.can_manage_club_content(p_club_id)) then
    raise exception 'Not authorized to manage this club' using errcode = '42501';
  end if;
  if p_entity_type = 'post' and p_bucket_id = 'post-images' then
    v_expected_prefix := 'club_posts/' || p_club_id || '/';
  elsif p_entity_type = 'event' and p_bucket_id = 'event-images' then
    v_expected_prefix := 'events/' || p_club_id || '/';
  else
    raise exception 'Invalid cleanup target' using errcode = '22023';
  end if;
  if p_object_path is null or p_object_path not like v_expected_prefix || '%' then
    raise exception 'Object path is not bound to the club' using errcode = '22023';
  end if;

  insert into public.storage_cleanup_queue_v2 (
    bucket_id, object_path, reason, entity_type, entity_id, club_id,
    requested_by, status, attempt_count, next_attempt_at, completed_at,
    last_error_category, last_error
  ) values (
    p_bucket_id, p_object_path, p_reason, p_entity_type, p_entity_id, p_club_id,
    v_actor, 'pending', 0, now() + greatest(coalesce(p_delay, interval '15 minutes'), interval '0'),
    null, null, null
  )
  on conflict (bucket_id, object_path) do update set
    reason = excluded.reason,
    entity_type = excluded.entity_type,
    entity_id = excluded.entity_id,
    club_id = excluded.club_id,
    requested_by = excluded.requested_by,
    status = 'pending',
    attempt_count = 0,
    next_attempt_at = excluded.next_attempt_at,
    lease_token = null,
    lease_owner = null,
    lease_expires_at = null,
    completed_at = null,
    last_error_category = null,
    last_error = null,
    updated_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function private.enqueue_storage_cleanup_v2(text,text,text,text,uuid,uuid,interval)
  from public, anon, authenticated;
grant execute on function private.enqueue_storage_cleanup_v2(text,text,text,text,uuid,uuid,interval)
  to authenticated;

create or replace function public.register_abandoned_content_upload_v2(
  p_bucket_id text,
  p_object_path text,
  p_entity_type text,
  p_entity_id uuid,
  p_club_id uuid
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not (
    (p_entity_type = 'post' and p_bucket_id = 'post-images'
      and p_object_path = 'club_posts/' || p_club_id || '/' || p_entity_id || '/cover.jpg')
    or
    (p_entity_type = 'event' and p_bucket_id = 'event-images'
      and p_object_path like 'events/' || p_club_id || '/' || p_entity_id || '/%')
  ) then
    raise exception 'Object path is not bound to the entity' using errcode = '22023';
  end if;
  return private.enqueue_storage_cleanup_v2(
    p_bucket_id,p_object_path,'create_compensation',p_entity_type,
    p_entity_id,p_club_id,interval '15 minutes'
  );
end;
$$;

-- One row lock serializes concurrent full-profile saves. Last writer wins as a
-- complete state; collections from two saves can never be interleaved.
create or replace function public.update_profile_v2(
  p_full_name text,
  p_bio text,
  p_major_id uuid,
  p_academic_year_id uuid,
  p_interest_ids uuid[] default '{}',
  p_double_major_ids uuid[] default '{}',
  p_minor_ids uuid[] default '{}'
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_interest_ids uuid[];
  v_double_major_ids uuid[];
  v_minor_ids uuid[];
  v_profile record;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_full_name is null or char_length(btrim(p_full_name)) not between 1 and 120 then
    raise exception 'Full name must contain 1 to 120 characters' using errcode = '22023';
  end if;
  if char_length(coalesce(p_bio, '')) > 80 then
    raise exception 'Bio must contain at most 80 characters' using errcode = '22023';
  end if;

  select coalesce(array_agg(id order by id), '{}'::uuid[]) into v_interest_ids
  from (select distinct unnest(coalesce(p_interest_ids, '{}'::uuid[])) as id) valueset;
  select coalesce(array_agg(id order by id), '{}'::uuid[]) into v_double_major_ids
  from (select distinct unnest(coalesce(p_double_major_ids, '{}'::uuid[])) as id) valueset;
  select coalesce(array_agg(id order by id), '{}'::uuid[]) into v_minor_ids
  from (select distinct unnest(coalesce(p_minor_ids, '{}'::uuid[])) as id) valueset;

  if cardinality(v_interest_ids) > 20 or cardinality(v_double_major_ids) > 1
     or cardinality(v_minor_ids) > 1 then
    raise exception 'Profile collection limit exceeded' using errcode = '22023';
  end if;
  if p_major_id = any(v_double_major_ids) or p_major_id = any(v_minor_ids)
     or v_double_major_ids && v_minor_ids then
    raise exception 'Major, double major, and minor must be distinct' using errcode = '22023';
  end if;
  if p_major_id is not null and not exists (
    select 1 from public.majors where id = p_major_id and is_active is true
  ) then raise exception 'Invalid major' using errcode = '23503'; end if;
  if p_academic_year_id is not null and not exists (
    select 1 from public.academic_years where id = p_academic_year_id and is_active is true
  ) then raise exception 'Invalid academic year' using errcode = '23503'; end if;
  if exists (
    select 1 from unnest(v_interest_ids) as requested(id)
    where not exists (
      select 1 from public.interests i
      where i.id = requested.id and i.is_active is true
    )
  ) then raise exception 'Invalid interest' using errcode = '23503'; end if;
  if exists (
    select 1 from unnest(v_double_major_ids || v_minor_ids) as requested(id)
    where not exists (
      select 1 from public.majors m
      where m.id = requested.id and m.is_active is true
    )
  ) then raise exception 'Invalid academic program' using errcode = '23503'; end if;

  perform private.enforce_authenticated_rate_limit('profile_update:actor', null);
  perform 1 from public.profiles where id = v_actor for update;
  if not found then raise exception 'Profile not found' using errcode = 'P0002'; end if;

  update public.profiles set
    full_name = btrim(p_full_name), bio = nullif(btrim(coalesce(p_bio, '')), ''),
    major_id = p_major_id, academic_year_id = p_academic_year_id, updated_at = now()
  where id = v_actor
  returning id, full_name, role, avatar_url, bio, major_id,
    academic_year_id, updated_at
  into v_profile;

  delete from public.student_interests where user_id = v_actor;
  insert into public.student_interests(user_id, interest_id)
    select v_actor, id from unnest(v_interest_ids) id;
  delete from public.profile_double_majors where profile_id = v_actor;
  insert into public.profile_double_majors(profile_id, major_id)
    select v_actor, id from unnest(v_double_major_ids) id;
  delete from public.profile_minors where profile_id = v_actor;
  insert into public.profile_minors(profile_id, major_id)
    select v_actor, id from unnest(v_minor_ids) id;

  return jsonb_build_object(
    'id', v_profile.id, 'email', coalesce(auth.jwt()->>'email', ''),
    'full_name', v_profile.full_name, 'role', v_profile.role,
    'avatar_url', v_profile.avatar_url, 'bio', v_profile.bio,
    'major_id', v_profile.major_id,
    'major_name', (select name from public.majors where id = v_profile.major_id),
    'academic_year_id', v_profile.academic_year_id,
    'academic_year_name', (select name from public.academic_years where id = v_profile.academic_year_id),
    'interest_ids', to_jsonb(v_interest_ids),
    'interest_names', coalesce((select jsonb_agg(i.name order by i.sort_order, i.id)
      from public.interests i where i.id = any(v_interest_ids)), '[]'::jsonb),
    'double_major_ids', to_jsonb(v_double_major_ids),
    'double_major_names', coalesce((select jsonb_agg(m.name order by m.sort_order, m.id)
      from public.majors m where m.id = any(v_double_major_ids)), '[]'::jsonb),
    'minor_ids', to_jsonb(v_minor_ids),
    'minor_names', coalesce((select jsonb_agg(m.name order by m.sort_order, m.id)
      from public.majors m where m.id = any(v_minor_ids)), '[]'::jsonb),
    'updated_at', v_profile.updated_at
  );
end;
$$;

create or replace function public.create_club_post_transactional_v2(
  p_post_id uuid,
  p_club_id uuid,
  p_content text,
  p_image_path text default null,
  p_image_url text default null,
  p_is_announcement boolean default false,
  p_mentioned_user_ids uuid[] default '{}',
  p_poll_question text default null,
  p_poll_options jsonb default null
)
returns public.club_posts
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_author uuid;
  v_post public.club_posts%rowtype;
  v_club_name text;
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_post_id is null or p_club_id is null then raise exception 'Post and club IDs are required' using errcode='22004'; end if;
  if not (select private.can_manage_club_content(p_club_id)) then
    raise exception 'Not authorized to manage this club' using errcode='42501';
  end if;
  select * into v_post from public.club_posts where id = p_post_id;
  if found then
    if v_post.club_id <> p_club_id then raise exception 'Idempotency key conflict' using errcode='23505'; end if;
    return v_post;
  end if;
  if p_content is null or char_length(btrim(p_content)) not between 1 and 5000 then
    raise exception 'Post content must contain 1 to 5000 characters' using errcode='22023';
  end if;
  if p_image_path is not null and p_image_path <> 'club_posts/'||p_club_id||'/'||p_post_id||'/cover.jpg' then
    raise exception 'Image path is not bound to this post' using errcode='22023';
  end if;
  if (p_poll_question is null) <> (p_poll_options is null) then
    raise exception 'Poll question and options are required together' using errcode='22023';
  end if;
  if p_poll_question is not null then
    if char_length(btrim(p_poll_question)) not between 1 and 500
       or jsonb_typeof(p_poll_options) <> 'array'
       or jsonb_array_length(p_poll_options) not between 2 and 10
       or exists (select 1 from jsonb_array_elements(p_poll_options) option(value)
         where jsonb_typeof(option.value) <> 'string'
           or char_length(btrim(option.value #>> '{}')) not between 1 and 200)
       or (select count(distinct lower(btrim(option.value #>> '{}')))
           from jsonb_array_elements(p_poll_options) option(value)) <> jsonb_array_length(p_poll_options)
    then raise exception 'Invalid poll' using errcode='22023'; end if;
  end if;

  perform private.enforce_authenticated_rate_limit('post_create:actor', null);
  perform private.enforce_authenticated_rate_limit('post_create:resource', p_club_id::text);
  perform set_config('app.notification_pipeline', 'v2', true);
  select id into v_author from public.profiles where id = v_actor;
  insert into public.club_posts(id,club_id,content,author_id,image_path,image_url,is_announcement)
  values(p_post_id,p_club_id,btrim(p_content),v_author,p_image_path,p_image_url,coalesce(p_is_announcement,false))
  returning * into v_post;
  if p_poll_question is not null then
    insert into public.polls(post_id,question,options)
    values(v_post.id,btrim(p_poll_question),p_poll_options);
  end if;
  select coalesce(nullif(name,''),'A club') into v_club_name from public.clubs where id=p_club_id;
  perform private.enqueue_notification_outbox_v2('club_post:'||v_post.id,'club_post',v_actor,'post',v_post.id,
    'club_followers',p_club_id,jsonb_build_object('exclude_recipient_ids',to_jsonb(coalesce(p_mentioned_user_ids,'{}'::uuid[]))),v_club_name||' posted something new',
    v_club_name||' shared “'||left(p_content,360)||'”. Tap to view the post.',jsonb_build_object('clubName',v_club_name,'content',left(p_content,360)),null);
  if cardinality(coalesce(p_mentioned_user_ids,'{}')) > 0 then
    perform private.enqueue_notification_outbox_v2('post_mention:'||v_post.id,'club_post',v_actor,'post',v_post.id,
      'explicit_users',null,jsonb_build_object('recipient_ids',to_jsonb(p_mentioned_user_ids)),v_club_name||' mentioned you',
      v_club_name||' mentioned you in a post.',jsonb_build_object('clubName',v_club_name,'content',left(p_content,360)),null);
  end if;
  return v_post;
end;
$$;

create or replace function public.create_club_event_transactional_v2(
  p_event_id uuid, p_club_id uuid, p_title text, p_description text, p_location text,
  p_event_date date, p_starts_at timestamptz, p_ends_at timestamptz,
  p_image_path text default null, p_image_url text default null,
  p_tags text[] default '{}', p_registration_url text default null,
  p_schedule jsonb default null, p_speakers jsonb default '[]'
)
returns public.events
language plpgsql
security invoker
set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_event public.events%rowtype; v_club_name text;
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if not (select private.can_manage_club_content(p_club_id)) then raise exception 'Not authorized' using errcode='42501'; end if;
  select * into v_event from public.events where id=p_event_id;
  if found then
    if v_event.club_id<>p_club_id then raise exception 'Idempotency key conflict' using errcode='23505'; end if;
    return v_event;
  end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 300
     or p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at then
    raise exception 'Invalid event details' using errcode='22023';
  end if;
  if p_image_path is not null and p_image_path <> 'events/'||p_club_id||'/'||p_event_id||'/cover.jpg' then
    raise exception 'Image path is not bound to this event' using errcode='22023';
  end if;
  perform private.enforce_authenticated_rate_limit('event_create:actor', null);
  perform private.enforce_authenticated_rate_limit('event_create:resource', p_club_id::text);
  perform set_config('app.notification_pipeline','v2',true);
  insert into public.events(id,club_id,title,description,location,event_date,starts_at,ends_at,is_public,
    created_by_user_id,image_path,image_url,tags,registration_url,schedule,speakers)
  values(p_event_id,p_club_id,btrim(p_title),p_description,p_location,p_event_date,p_starts_at,p_ends_at,true,
    v_actor,p_image_path,p_image_url,coalesce(p_tags,'{}'),p_registration_url,p_schedule,coalesce(p_speakers,'[]'))
  returning * into v_event;
  select coalesce(nullif(name,''),'A club') into v_club_name from public.clubs where id=p_club_id;
  perform private.enqueue_notification_outbox_v2('club_event:'||v_event.id,'club_event',v_actor,'event',v_event.id,
    'club_followers',p_club_id,'{}','New event from '||v_club_name,
    v_club_name||' announced “'||left(p_title,300)||'”. Tap for details and RSVP.',
    jsonb_build_object('clubName',v_club_name,'eventTitle',left(p_title,300)),null);
  return v_event;
end;
$$;

create or replace function public.update_club_event_transactional_v2(
  p_event_id uuid, p_title text, p_description text, p_location text,
  p_event_date date, p_starts_at timestamptz, p_ends_at timestamptz,
  p_image_path text, p_image_url text, p_tags text[], p_registration_url text,
  p_schedule jsonb, p_speakers jsonb
)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_event public.events%rowtype; v_old_path text; v_cleanup_id uuid;
begin
  select * into v_event from public.events where id=p_event_id for update;
  if not found then raise exception 'Event not found' using errcode='P0002'; end if;
  if not (select private.can_manage_club_content(v_event.club_id)) then raise exception 'Not authorized' using errcode='42501'; end if;
  if p_image_path is not null and p_image_path not like 'events/'||v_event.club_id||'/'||p_event_id||'/%' then
    raise exception 'Image path is not bound to this event' using errcode='22023';
  end if;
  if p_ends_at <= p_starts_at then raise exception 'Event end must follow start' using errcode='22023'; end if;
  perform private.enforce_authenticated_rate_limit('event_update:actor', null);
  perform private.enforce_authenticated_rate_limit('event_update:resource', v_event.club_id::text);
  v_old_path:=v_event.image_path;
  update public.events set title=btrim(p_title),description=p_description,location=p_location,event_date=p_event_date,
    starts_at=p_starts_at,ends_at=p_ends_at,image_path=p_image_path,image_url=p_image_url,tags=coalesce(p_tags,'{}'),
    registration_url=p_registration_url,schedule=p_schedule,speakers=coalesce(p_speakers,'[]'),updated_at=now()
  where id=p_event_id returning * into v_event;
  if v_old_path is not null and v_old_path is distinct from p_image_path then
    v_cleanup_id:=private.enqueue_storage_cleanup_v2('event-images',v_old_path,'media_replaced','event',p_event_id,v_event.club_id,interval '0');
  end if;
  return jsonb_build_object('entity',to_jsonb(v_event),'cleanup_id',v_cleanup_id,'cleanup_path',v_old_path);
end $$;

create or replace function public.delete_club_post_transactional_v2(p_post_id uuid, p_club_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_post public.club_posts%rowtype; v_cleanup_id uuid;
begin
  if not (select private.can_manage_club_content(p_club_id)) then raise exception 'Not authorized' using errcode='42501'; end if;
  select * into v_post from public.club_posts where id=p_post_id for update;
  if not found then return jsonb_build_object('deleted',true,'already_deleted',true); end if;
  if v_post.club_id<>p_club_id then raise exception 'Club mismatch' using errcode='42501'; end if;
  perform private.enforce_authenticated_rate_limit('post_delete:actor', null);
  perform private.enforce_authenticated_rate_limit('post_delete:resource', p_club_id::text);
  delete from public.club_posts where id=p_post_id;
  if v_post.image_path is not null then
    v_cleanup_id:=private.enqueue_storage_cleanup_v2('post-images',v_post.image_path,'entity_deleted','post',p_post_id,p_club_id,interval '0');
  end if;
  return jsonb_build_object('deleted',true,'cleanup_id',v_cleanup_id,'cleanup_path',v_post.image_path);
end $$;

create or replace function public.delete_club_event_transactional_v2(p_event_id uuid, p_club_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_event public.events%rowtype; v_cleanup_id uuid;
begin
  if not (select private.can_manage_club_content(p_club_id)) then raise exception 'Not authorized' using errcode='42501'; end if;
  select * into v_event from public.events where id=p_event_id for update;
  if not found then return jsonb_build_object('deleted',true,'already_deleted',true); end if;
  if v_event.club_id<>p_club_id then raise exception 'Club mismatch' using errcode='42501'; end if;
  perform private.enforce_authenticated_rate_limit('event_delete:actor', null);
  perform private.enforce_authenticated_rate_limit('event_delete:resource', p_club_id::text);
  delete from public.events where id=p_event_id;
  if v_event.image_path is not null then
    v_cleanup_id:=private.enqueue_storage_cleanup_v2('event-images',v_event.image_path,'entity_deleted','event',p_event_id,p_club_id,interval '0');
  end if;
  return jsonb_build_object('deleted',true,'cleanup_id',v_cleanup_id,'cleanup_path',v_event.image_path);
end $$;

create or replace function public.complete_storage_cleanup_v2(p_cleanup_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_item public.storage_cleanup_queue_v2%rowtype;
begin
  select * into v_item from public.storage_cleanup_queue_v2 where id=p_cleanup_id for update;
  if not found then return false; end if;
  if auth.uid() is null or not (select private.can_manage_club_content(v_item.club_id)) then
    raise exception 'Not authorized' using errcode='42501';
  end if;
  update public.storage_cleanup_queue_v2 set status='completed',completed_at=now(),updated_at=now(),
    lease_token=null,lease_owner=null,lease_expires_at=null where id=p_cleanup_id;
  return true;
end $$;

create or replace function public.claim_storage_cleanup_v2(p_worker text, p_limit integer default 25, p_lease_seconds integer default 90)
returns setof public.storage_cleanup_queue_v2 language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'Service role required' using errcode='42501'; end if;
  return query
  with candidates as (
    select id from public.storage_cleanup_queue_v2
    where ((status in ('pending','retryable') and next_attempt_at<=now())
      or (status='processing' and lease_expires_at<=now()))
      and attempt_count < 8
    order by next_attempt_at,created_at for update skip locked limit least(greatest(coalesce(p_limit,25),1),100)
  )
  update public.storage_cleanup_queue_v2 q set status='processing',attempt_count=q.attempt_count+1,
    lease_token=gen_random_uuid(),lease_owner=left(p_worker,120),lease_expires_at=now()+make_interval(secs=>least(greatest(p_lease_seconds,15),600)),updated_at=now()
  from candidates where q.id=candidates.id returning q.*;
end $$;

create or replace function public.complete_storage_cleanup_worker_v2(
  p_cleanup_id uuid,p_lease_token uuid,p_outcome text,p_error_category text default null,p_error text default null
)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_attempt integer;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'Service role required' using errcode='42501'; end if;
  select attempt_count into v_attempt from public.storage_cleanup_queue_v2 where id=p_cleanup_id and lease_token=p_lease_token for update;
  if not found then return false; end if;
  update public.storage_cleanup_queue_v2 set
    status=case when p_outcome in ('deleted','referenced') then 'completed'
      when p_outcome='permanent' or v_attempt>=8 then 'terminal' else 'retryable' end,
    next_attempt_at=case when p_outcome='retryable' and v_attempt<8
      then now()+least(interval '6 hours',interval '30 seconds'*power(2,least(v_attempt,10))) else next_attempt_at end,
    completed_at=case when p_outcome in ('deleted','referenced','permanent') or v_attempt>=8 then now() else null end,
    last_error_category=p_error_category,last_error=left(p_error,1000),updated_at=now(),
    lease_token=null,lease_owner=null,lease_expires_at=null
  where id=p_cleanup_id;
  return true;
end $$;

create or replace function public.storage_cleanup_is_referenced_v2(p_cleanup_id uuid,p_lease_token uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_item public.storage_cleanup_queue_v2%rowtype;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'Service role required' using errcode='42501'; end if;
  select * into v_item from public.storage_cleanup_queue_v2 where id=p_cleanup_id and lease_token=p_lease_token;
  if not found then raise exception 'Cleanup lease not found' using errcode='P0002'; end if;
  if v_item.entity_type='post' then
    return exists(select 1 from public.club_posts where id=v_item.entity_id and image_path=v_item.object_path);
  end if;
  return exists(select 1 from public.events where id=v_item.entity_id and image_path=v_item.object_path);
end $$;

revoke all on function public.register_abandoned_content_upload_v2(text,text,text,uuid,uuid) from public,anon,authenticated;
revoke all on function public.update_profile_v2(text,text,uuid,uuid,uuid[],uuid[],uuid[]) from public,anon,authenticated;
revoke all on function public.create_club_post_transactional_v2(uuid,uuid,text,text,text,boolean,uuid[],text,jsonb) from public,anon,authenticated;
revoke all on function public.create_club_event_transactional_v2(uuid,uuid,text,text,text,date,timestamptz,timestamptz,text,text,text[],text,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.update_club_event_transactional_v2(uuid,text,text,text,date,timestamptz,timestamptz,text,text,text[],text,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.delete_club_post_transactional_v2(uuid,uuid) from public,anon,authenticated;
revoke all on function public.delete_club_event_transactional_v2(uuid,uuid) from public,anon,authenticated;
revoke all on function public.complete_storage_cleanup_v2(uuid) from public,anon,authenticated;
revoke all on function public.claim_storage_cleanup_v2(text,integer,integer) from public,anon,authenticated;
revoke all on function public.complete_storage_cleanup_worker_v2(uuid,uuid,text,text,text) from public,anon,authenticated;
revoke all on function public.storage_cleanup_is_referenced_v2(uuid,uuid) from public,anon,authenticated;

grant execute on function public.register_abandoned_content_upload_v2(text,text,text,uuid,uuid) to authenticated;
grant execute on function public.update_profile_v2(text,text,uuid,uuid,uuid[],uuid[],uuid[]) to authenticated;
grant execute on function public.create_club_post_transactional_v2(uuid,uuid,text,text,text,boolean,uuid[],text,jsonb) to authenticated;
grant execute on function public.create_club_event_transactional_v2(uuid,uuid,text,text,text,date,timestamptz,timestamptz,text,text,text[],text,jsonb,jsonb) to authenticated;
grant execute on function public.update_club_event_transactional_v2(uuid,text,text,text,date,timestamptz,timestamptz,text,text,text[],text,jsonb,jsonb) to authenticated;
grant execute on function public.delete_club_post_transactional_v2(uuid,uuid) to authenticated;
grant execute on function public.delete_club_event_transactional_v2(uuid,uuid) to authenticated;
grant execute on function public.complete_storage_cleanup_v2(uuid) to authenticated;
grant execute on function public.claim_storage_cleanup_v2(text,integer,integer) to service_role;
grant execute on function public.complete_storage_cleanup_worker_v2(uuid,uuid,text,text,text) to service_role;
grant execute on function public.storage_cleanup_is_referenced_v2(uuid,uuid) to service_role;

comment on table public.storage_cleanup_queue_v2 is
  'Durable, bounded Storage deletion work. Workers re-check canonical references before deleting via the Storage API.';
