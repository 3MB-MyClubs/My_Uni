-- Notification v2 is additive. Released clients keep direct table writes and
-- the canonical public.notifications inbox. New v2 RPCs mark their transaction
-- so the legacy row triggers are skipped and enqueue exactly one durable event.

create extension if not exists pgcrypto with schema extensions;

alter table public.notifications
  add column if not exists pipeline_version smallint not null default 1
    check (pipeline_version in (1, 2));

create table public.notification_outbox_v2 (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique check (char_length(event_key) between 1 and 300),
  notification_type text not null,
  actor_user_id uuid references auth.users(id) on delete set null,
  target_type text not null,
  target_id uuid not null,
  audience_type text not null check (audience_type in (
    'direct_user', 'group_members', 'club_followers', 'club_board', 'explicit_users'
  )),
  audience_id uuid,
  audience_data jsonb not null default '{}'::jsonb
    check (jsonb_typeof(audience_data) = 'object' and pg_column_size(audience_data) <= 65536),
  title text not null check (char_length(title) between 1 and 160),
  body text not null check (char_length(body) between 1 and 500),
  localization_args jsonb not null default '{}'::jsonb
    check (jsonb_typeof(localization_args) = 'object' and pg_column_size(localization_args) <= 16384),
  notification_group_key text,
  status text not null default 'pending' check (status in (
    'pending', 'processing', 'expanded', 'retryable', 'terminal'
  )),
  recipient_cursor uuid,
  recipient_count integer not null default 0 check (recipient_count >= 0),
  batch_count integer not null default 0 check (batch_count >= 0),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default now(),
  lease_token uuid,
  lease_owner text,
  lease_expires_at timestamptz,
  last_error_code text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint notification_outbox_v2_lease_shape check (
    (lease_token is null and lease_owner is null and lease_expires_at is null)
    or (lease_token is not null and lease_owner is not null and lease_expires_at is not null)
  )
);

create table public.notification_recipients_v2 (
  outbox_id uuid not null references public.notification_outbox_v2(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (outbox_id, recipient_id),
  unique (outbox_id, notification_id)
);

create table public.notification_deliveries_v2 (
  id uuid primary key default gen_random_uuid(),
  outbox_id uuid not null,
  recipient_id uuid not null,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  device_id uuid not null references public.push_devices(id) on delete cascade,
  status text not null default 'pending' check (status in (
    'pending', 'processing', 'retryable', 'delivered', 'terminal'
  )),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default now(),
  lease_token uuid,
  lease_owner text,
  lease_expires_at timestamptz,
  provider_message_id text,
  last_http_status integer,
  last_error_code text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  delivered_at timestamptz,
  terminal_at timestamptz,
  foreign key (outbox_id, recipient_id)
    references public.notification_recipients_v2(outbox_id, recipient_id) on delete cascade,
  unique (outbox_id, device_id),
  constraint notification_deliveries_v2_lease_shape check (
    (lease_token is null and lease_owner is null and lease_expires_at is null)
    or (lease_token is not null and lease_owner is not null and lease_expires_at is not null)
  )
);

create index notification_outbox_v2_claim_idx
  on public.notification_outbox_v2 (next_attempt_at, created_at)
  where status in ('pending', 'retryable', 'processing');
create index notification_deliveries_v2_claim_idx
  on public.notification_deliveries_v2 (next_attempt_at, created_at)
  where status in ('pending', 'retryable', 'processing');
create index notification_deliveries_v2_notification_idx
  on public.notification_deliveries_v2 (notification_id, status);
create index notification_recipients_v2_recipient_idx
  on public.notification_recipients_v2 (recipient_id, created_at desc);

alter table public.notification_outbox_v2 enable row level security;
alter table public.notification_recipients_v2 enable row level security;
alter table public.notification_deliveries_v2 enable row level security;
revoke all on public.notification_outbox_v2 from public, anon, authenticated;
revoke all on public.notification_recipients_v2 from public, anon, authenticated;
revoke all on public.notification_deliveries_v2 from public, anon, authenticated;
grant all on public.notification_outbox_v2 to service_role;
grant all on public.notification_recipients_v2 to service_role;
grant all on public.notification_deliveries_v2 to service_role;

create or replace function private.notification_v2_backoff(
  p_attempt integer,
  p_seed uuid
) returns interval
language sql immutable set search_path = '' as $$
  select make_interval(secs => least(21600, 15 * (2 ^ least(greatest(p_attempt - 1, 0), 10))::integer)
    + (abs(hashtextextended(p_seed::text, p_attempt)) % 16)::integer)
$$;

create or replace function private.enqueue_notification_outbox_v2(
  p_event_key text,
  p_notification_type text,
  p_actor_user_id uuid,
  p_target_type text,
  p_target_id uuid,
  p_audience_type text,
  p_audience_id uuid,
  p_audience_data jsonb,
  p_title text,
  p_body text,
  p_localization_args jsonb,
  p_notification_group_key text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if auth.uid() is null or (p_actor_user_id is not null and p_actor_user_id <> auth.uid()) then
    raise exception 'Notification actor mismatch' using errcode = '42501';
  end if;
  insert into public.notification_outbox_v2 (
    event_key, notification_type, actor_user_id, target_type, target_id,
    audience_type, audience_id, audience_data, title, body,
    localization_args, notification_group_key
  ) values (
    p_event_key, p_notification_type, p_actor_user_id, p_target_type, p_target_id,
    p_audience_type, p_audience_id, coalesce(p_audience_data, '{}'::jsonb),
    left(p_title, 160), left(p_body, 500),
    coalesce(p_localization_args, '{}'::jsonb), p_notification_group_key
  ) on conflict (event_key) do update set event_key = excluded.event_key
  returning id into v_id;
  return v_id;
end $$;

revoke all on function private.enqueue_notification_outbox_v2(
  text, text, uuid, text, uuid, text, uuid, jsonb, text, text, jsonb, text
) from public, anon, authenticated;
grant execute on function private.enqueue_notification_outbox_v2(
  text, text, uuid, text, uuid, text, uuid, jsonb, text, text, jsonb, text
) to authenticated;

-- Claiming and expansion are separate transactions. If a worker disappears
-- after claiming, the 90-second lease makes the event eligible again.
create or replace function public.claim_notification_outbox_v2(
  p_worker text,
  p_lease_seconds integer default 90,
  p_max_attempts integer default 8
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_event public.notification_outbox_v2%rowtype; v_token uuid := gen_random_uuid();
begin
  if char_length(coalesce(p_worker, '')) not between 1 and 120 then raise exception 'Invalid worker' using errcode = '22023'; end if;
  update public.notification_outbox_v2 set status='terminal', completed_at=clock_timestamp(),
    lease_token=null, lease_owner=null, lease_expires_at=null,
    last_error_code='lease_attempts_exhausted',
    last_error='Worker lease expired after the maximum claim count', updated_at=clock_timestamp()
  where status='processing' and lease_expires_at <= clock_timestamp()
    and attempt_count >= least(greatest(p_max_attempts,1),20);
  with candidate as (
    select id from public.notification_outbox_v2
    where (
      (status in ('pending', 'retryable') and next_attempt_at <= clock_timestamp())
      or (status = 'processing' and lease_expires_at <= clock_timestamp())
    ) and attempt_count < least(greatest(p_max_attempts, 1), 20)
    order by next_attempt_at, created_at
    for update skip locked limit 1
  )
  update public.notification_outbox_v2 as outbox set
    status = 'processing', attempt_count = attempt_count + 1,
    lease_token = v_token, lease_owner = p_worker,
    lease_expires_at = clock_timestamp() + make_interval(secs => least(greatest(p_lease_seconds, 30), 300)),
    updated_at = clock_timestamp()
  from candidate where outbox.id = candidate.id returning outbox.* into v_event;
  if not found then return null; end if;
  return jsonb_build_object('id', v_event.id, 'lease_token', v_token,
    'attempt_count', v_event.attempt_count, 'audience_type', v_event.audience_type);
end $$;

create or replace function public.expand_notification_outbox_v2(
  p_outbox_id uuid,
  p_lease_token uuid,
  p_batch_size integer default 250
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_event public.notification_outbox_v2%rowtype;
  v_limit integer := least(greatest(coalesce(p_batch_size, 250), 1), 500);
  v_count integer := 0; v_has_more boolean := false; v_cursor uuid;
begin
  select * into v_event from public.notification_outbox_v2
  where id = p_outbox_id and status = 'processing' and lease_token = p_lease_token
    and lease_expires_at > clock_timestamp() for update;
  if not found then raise exception 'Outbox lease is missing or expired' using errcode = '55000'; end if;

  create temporary table if not exists pg_temp.notification_v2_batch(recipient_id uuid primary key) on commit drop;
  truncate pg_temp.notification_v2_batch;
  if v_event.audience_type = 'club_followers' then
    insert into pg_temp.notification_v2_batch
    select follower.profile_id from public.club_followers follower
    where follower.club_id = v_event.audience_id
      and follower.profile_id > coalesce(v_event.recipient_cursor, '00000000-0000-0000-0000-000000000000'::uuid)
      and follower.profile_id is distinct from v_event.actor_user_id
    order by follower.profile_id limit v_limit + 1;
  elsif v_event.audience_type = 'group_members' then
    insert into pg_temp.notification_v2_batch
    select member.user_id from public.group_chat_members member
    where member.group_id = v_event.audience_id
      and member.user_id > coalesce(v_event.recipient_cursor, '00000000-0000-0000-0000-000000000000'::uuid)
      and member.user_id is distinct from v_event.actor_user_id
    order by member.user_id limit v_limit + 1;
  elsif v_event.audience_type = 'club_board' then
    insert into pg_temp.notification_v2_batch
    select recipient_id from (
      select account.auth_user_id as recipient_id from public.club_auth_accounts account where account.club_id = v_event.audience_id
      union
      select follower.profile_id from public.club_followers follower where follower.club_id = v_event.audience_id and follower.role = 'board_member'
    ) recipients
    where recipient_id > coalesce(v_event.recipient_cursor, '00000000-0000-0000-0000-000000000000'::uuid)
      and recipient_id is distinct from v_event.actor_user_id
    order by recipient_id limit v_limit + 1;
  elsif v_event.audience_type in ('direct_user', 'explicit_users') then
    insert into pg_temp.notification_v2_batch
    select distinct value::uuid
    from jsonb_array_elements_text(coalesce(v_event.audience_data -> 'recipient_ids', '[]'::jsonb)) value
    where value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      and value::uuid > coalesce(v_event.recipient_cursor, '00000000-0000-0000-0000-000000000000'::uuid)
      and value::uuid is distinct from v_event.actor_user_id
      and (v_event.audience_type='direct_user' or v_event.audience_id is null or exists (
        select 1 from public.club_followers follower
        where follower.club_id=v_event.audience_id and follower.profile_id=value::uuid
      ))
    order by value::uuid limit v_limit + 1;
  end if;

  select count(*) > v_limit into v_has_more from pg_temp.notification_v2_batch;
  delete from pg_temp.notification_v2_batch where recipient_id in (
    select recipient_id from pg_temp.notification_v2_batch order by recipient_id offset v_limit
  );

  -- Blocks are server-side exclusions already used by feed visibility. Device
  -- enablement is applied when delivery rows are materialized below.
  delete from pg_temp.notification_v2_batch batch where exists (
    select 1 from public.user_blocks block
    where (block.blocker_id = batch.recipient_id and block.blocked_id = v_event.actor_user_id)
       or (block.blocker_id = v_event.actor_user_id and block.blocked_id = batch.recipient_id)
  );
  delete from pg_temp.notification_v2_batch batch
  where batch.recipient_id in (
    select value::uuid
    from jsonb_array_elements_text(coalesce(v_event.audience_data -> 'exclude_recipient_ids', '[]'::jsonb)) value
    where value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  );

  insert into public.notifications (
    user_id, actor_user_id, type, title, body, target_type, target_id,
    dedupe_key, localization_args, notification_group_key, pipeline_version
  )
  select batch.recipient_id, v_event.actor_user_id, v_event.notification_type,
    v_event.title, v_event.body, v_event.target_type, v_event.target_id,
    v_event.event_key || ':' || batch.recipient_id::text,
    v_event.localization_args, v_event.notification_group_key, 2
  from pg_temp.notification_v2_batch batch
  on conflict (dedupe_key) do nothing;

  insert into public.notification_recipients_v2(outbox_id, recipient_id, notification_id)
  select v_event.id, batch.recipient_id, notification.id
  from pg_temp.notification_v2_batch batch
  join public.notifications notification
    on notification.dedupe_key = v_event.event_key || ':' || batch.recipient_id::text
  on conflict (outbox_id, recipient_id) do nothing;

  insert into public.notification_deliveries_v2(
    outbox_id, recipient_id, notification_id, device_id
  )
  select recipient.outbox_id, recipient.recipient_id, recipient.notification_id, device.id
  from public.notification_recipients_v2 recipient
  join public.push_devices device on device.user_id = recipient.recipient_id
    and device.notifications_enabled
  where recipient.outbox_id = v_event.id
    and exists (select 1 from pg_temp.notification_v2_batch batch where batch.recipient_id = recipient.recipient_id)
  on conflict (outbox_id, device_id) do nothing;

  update public.notifications notification set
    push_sent_at=coalesce(notification.push_sent_at,clock_timestamp()),
    push_error='No registered devices'
  where notification.id in (
    select recipient.notification_id from public.notification_recipients_v2 recipient
    where recipient.outbox_id=v_event.id
      and exists (select 1 from pg_temp.notification_v2_batch batch where batch.recipient_id=recipient.recipient_id)
      and not exists (select 1 from public.notification_deliveries_v2 delivery
        where delivery.notification_id=recipient.notification_id)
  );

  select count(*) into v_count from pg_temp.notification_v2_batch;
  select recipient_id into v_cursor from pg_temp.notification_v2_batch
  order by recipient_id desc limit 1;
  update public.notification_outbox_v2 set
    recipient_cursor = coalesce(v_cursor, recipient_cursor),
    recipient_count = recipient_count + v_count,
    batch_count = batch_count + 1,
    status = case when v_has_more then 'pending' else 'expanded' end,
    next_attempt_at = clock_timestamp(), lease_token = null, lease_owner = null,
    lease_expires_at = null, completed_at = case when v_has_more then null else clock_timestamp() end,
    updated_at = clock_timestamp()
  where id = v_event.id;
  return jsonb_build_object('outbox_id', v_event.id, 'recipients', v_count,
    'has_more', v_has_more, 'batch_size', v_limit);
end $$;

create or replace function public.fail_notification_outbox_v2(
  p_outbox_id uuid, p_lease_token uuid, p_error_code text, p_error text,
  p_retryable boolean default true, p_max_attempts integer default 8
) returns void language plpgsql security definer set search_path = '' as $$
declare v_attempt integer;
begin
  select attempt_count into v_attempt from public.notification_outbox_v2
  where id = p_outbox_id and lease_token = p_lease_token for update;
  if not found then return; end if;
  update public.notification_outbox_v2 set
    status = case when p_retryable and v_attempt < least(greatest(p_max_attempts, 1), 20) then 'retryable' else 'terminal' end,
    next_attempt_at = clock_timestamp() + private.notification_v2_backoff(v_attempt, p_outbox_id),
    lease_token = null, lease_owner = null, lease_expires_at = null,
    last_error_code = left(p_error_code, 80), last_error = left(p_error, 1000),
    completed_at = case when not p_retryable or v_attempt >= p_max_attempts then clock_timestamp() else null end,
    updated_at = clock_timestamp() where id = p_outbox_id;
end $$;

create or replace function public.claim_notification_deliveries_v2(
  p_worker text, p_batch_size integer default 250, p_lease_seconds integer default 90,
  p_max_attempts integer default 8
) returns table (
  delivery_id uuid, lease_token uuid, notification_id uuid, device_id uuid,
  fcm_token text, locale text, notification_type text, title text, body text,
  target_type text, target_id uuid, actor_user_id uuid, localization_args jsonb,
  notification_group_key text, message_count integer, attempt_count integer
) language plpgsql security definer set search_path = '' as $$
begin
  update public.notification_deliveries_v2 as exhausted set status='terminal', terminal_at=clock_timestamp(),
    lease_token=null, lease_owner=null, lease_expires_at=null,
    last_error_code='lease_attempts_exhausted',
    last_error='Delivery lease expired after the maximum claim count', updated_at=clock_timestamp()
  where exhausted.status='processing' and exhausted.lease_expires_at <= clock_timestamp()
    and exhausted.attempt_count >= least(greatest(p_max_attempts,1),20);
  return query with candidate as (
    select delivery.id from public.notification_deliveries_v2 delivery
    where ((delivery.status in ('pending', 'retryable') and delivery.next_attempt_at <= clock_timestamp())
      or (delivery.status = 'processing' and delivery.lease_expires_at <= clock_timestamp()))
      and delivery.attempt_count < least(greatest(p_max_attempts, 1), 20)
    order by delivery.next_attempt_at, delivery.created_at
    for update skip locked limit least(greatest(coalesce(p_batch_size, 250), 1), 500)
  ), claimed as (
    update public.notification_deliveries_v2 delivery set
      status = 'processing', attempt_count = delivery.attempt_count + 1,
      lease_token = gen_random_uuid(), lease_owner = left(p_worker, 120),
      lease_expires_at = clock_timestamp() + make_interval(secs => least(greatest(p_lease_seconds, 30), 300)),
      updated_at = clock_timestamp()
    from candidate where delivery.id = candidate.id returning delivery.*
  )
  select claimed.id, claimed.lease_token, notification.id, device.id,
    device.fcm_token, device.locale, notification.type, notification.title,
    notification.body, notification.target_type, notification.target_id,
    notification.actor_user_id, notification.localization_args,
    notification.notification_group_key, notification.message_count,
    claimed.attempt_count
  from claimed
  join public.notifications notification on notification.id = claimed.notification_id
  join public.push_devices device on device.id = claimed.device_id and device.notifications_enabled;
end $$;

create or replace function public.complete_notification_delivery_v2(
  p_delivery_id uuid, p_lease_token uuid, p_outcome text,
  p_http_status integer default null, p_error_code text default null,
  p_error text default null, p_provider_message_id text default null,
  p_max_attempts integer default 8
) returns void language plpgsql security definer set search_path = '' as $$
declare v_delivery public.notification_deliveries_v2%rowtype; v_terminal boolean;
begin
  if p_outcome not in ('delivered', 'retryable', 'terminal') then raise exception 'Invalid delivery outcome' using errcode = '22023'; end if;
  select * into v_delivery from public.notification_deliveries_v2
  where id = p_delivery_id and lease_token = p_lease_token and status = 'processing' for update;
  if not found then return; end if;
  v_terminal := p_outcome = 'terminal' or (p_outcome = 'retryable' and v_delivery.attempt_count >= p_max_attempts);
  update public.notification_deliveries_v2 set
    status = case when p_outcome = 'delivered' then 'delivered' when v_terminal then 'terminal' else 'retryable' end,
    next_attempt_at = case when p_outcome = 'retryable' and not v_terminal
      then clock_timestamp() + private.notification_v2_backoff(v_delivery.attempt_count, v_delivery.id)
      else next_attempt_at end,
    lease_token = null, lease_owner = null, lease_expires_at = null,
    provider_message_id = left(p_provider_message_id, 300), last_http_status = p_http_status,
    last_error_code = left(p_error_code, 80), last_error = left(p_error, 1000),
    delivered_at = case when p_outcome = 'delivered' then clock_timestamp() else delivered_at end,
    terminal_at = case when v_terminal then clock_timestamp() else terminal_at end,
    updated_at = clock_timestamp() where id = v_delivery.id;

  update public.notifications notification set
    push_started_at = null,
    push_sent_at = case when exists (
      select 1 from public.notification_deliveries_v2 delivery
      where delivery.notification_id = notification.id and delivery.status = 'delivered'
    ) then coalesce(notification.push_sent_at, clock_timestamp()) else null end,
    push_error = case when exists (
      select 1 from public.notification_deliveries_v2 delivery
      where delivery.notification_id = notification.id and delivery.status in ('pending','processing','retryable','terminal')
    ) then 'Notification v2 has pending or failed device deliveries' else null end
  where notification.id = v_delivery.notification_id;
end $$;

create or replace function public.notification_v2_metrics()
returns jsonb language sql security definer set search_path = '' as $$
  select jsonb_build_object(
    'queue_depth', count(*) filter (where status in ('pending','processing','retryable')),
    'oldest_pending_at', min(created_at) filter (where status in ('pending','processing','retryable')),
    'terminal_events', count(*) filter (where status = 'terminal'),
    'recipients', coalesce(sum(recipient_count), 0),
    'batches', coalesce(sum(batch_count), 0),
    'retries', coalesce(sum(greatest(attempt_count - 1, 0)), 0),
    'delivery_retryable', (select count(*) from public.notification_deliveries_v2 where status='retryable'),
    'delivery_terminal', (select count(*) from public.notification_deliveries_v2 where status='terminal'),
    'invalid_tokens', (select count(*) from public.notification_deliveries_v2 where last_error_code='invalid_token')
  ) from public.notification_outbox_v2
$$;

create or replace function private.cleanup_notification_v2(
  p_batch_size integer default 5000
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_outbox integer; v_deliveries integer;
begin
  with doomed as (
    select id from public.notification_deliveries_v2
    where (status = 'delivered' and updated_at < clock_timestamp() - interval '30 days')
       or (status = 'terminal' and updated_at < clock_timestamp() - interval '90 days')
    order by updated_at limit least(greatest(p_batch_size,1),20000)
  ) delete from public.notification_deliveries_v2 delivery using doomed where delivery.id = doomed.id;
  get diagnostics v_deliveries = row_count;
  with doomed as (
    select id from public.notification_outbox_v2
    where (status = 'expanded' and completed_at < clock_timestamp() - interval '30 days')
       or (status = 'terminal' and completed_at < clock_timestamp() - interval '90 days')
    order by completed_at limit least(greatest(p_batch_size,1),20000)
  ) delete from public.notification_outbox_v2 outbox using doomed where outbox.id = doomed.id;
  get diagnostics v_outbox = row_count;
  return jsonb_build_object('outbox',v_outbox,'deliveries',v_deliveries);
end $$;

revoke all on function private.cleanup_notification_v2(integer) from public,anon,authenticated;

create or replace function private.enqueue_chat_notification_outbox_v2(
  p_thread_id text,
  p_message_id uuid
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid(); v_target uuid; v_audience text; v_audience_id uuid;
  v_recipients jsonb := '[]'::jsonb; v_type text; v_title text; v_body text;
  v_args jsonb := '{}'::jsonb; v_event_key text; v_content text; v_kind text;
  v_payload jsonb; v_actor_name text; v_group_name text; v_club_name text;
  v_sender_profile uuid; v_inbox record;
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select coalesce(nullif(profile.full_name,''),'Someone') into v_actor_name
  from public.profiles profile where profile.id=v_actor;
  v_actor_name := coalesce(v_actor_name,'Someone');

  if left(p_thread_id,3)='dm:' then
    select message.sender_id, message.receiver_id, message.content, message.message_kind, message.payload
      into v_actor, v_target, v_content, v_kind, v_payload
    from public.direct_messages message where message.id=p_message_id and message.sender_id=auth.uid();
    v_type:='direct_message'; v_audience:='direct_user'; v_recipients:=jsonb_build_array(v_target);
    v_target:=v_actor;
    v_event_key:='direct_message:'||p_message_id; v_title:=v_actor_name;
    v_body:=v_actor_name||': '||private.chat_notification_preview(v_kind,v_content,v_payload);
  elsif left(p_thread_id,6)='group:' then
    select message.group_id, message.content, message.message_kind, message.payload
      into v_target, v_content, v_kind, v_payload
    from public.group_messages message where message.id=p_message_id and message.sender_id=v_actor;
    select coalesce(nullif(chat.custom_name,''),'Group chat') into v_group_name from public.group_chats chat where chat.id=v_target;
    v_type:='group_message'; v_audience:='group_members'; v_audience_id:=v_target;
    v_event_key:='group_message:'||p_message_id; v_title:=v_group_name;
    v_body:=v_actor_name||': '||private.chat_notification_preview(v_kind,v_content,v_payload);
  elsif left(p_thread_id,5)='club:' then
    select message.club_id, message.content, message.message_kind, message.payload
      into v_target, v_content, v_kind, v_payload
    from public.club_channel_messages message where message.id=p_message_id and message.sender_auth_id=v_actor;
    select coalesce(nullif(club.name,''),'A club') into v_club_name from public.clubs club where club.id=v_target;
    v_type:='club_channel_message'; v_audience_id:=v_target; v_title:=v_club_name;
    v_body:=v_club_name||': '||private.chat_notification_preview(v_kind,v_content,v_payload);
    if v_kind='announcement' or coalesce(v_payload->'mentions','[]'::jsonb) ? 'everyone' then
      v_audience:='club_followers'; v_event_key:='club_channel_message:'||p_message_id;
    else
      v_audience:='explicit_users';
      select coalesce(jsonb_agg(value), '[]'::jsonb) into v_recipients
      from jsonb_array_elements_text(coalesce(v_payload->'mentions','[]'::jsonb)) value
      where value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
      v_event_key:='club_channel_mention:'||p_message_id;
    end if;
  elsif left(p_thread_id,7)='clubdm:' then
    select message.thread_id, message.content, message.message_kind, message.payload, message.sender_profile_id
      into v_target, v_content, v_kind, v_payload, v_sender_profile
    from public.club_inbox_messages message where message.id=p_message_id and message.sender_auth_id=v_actor;
    select thread.club_id, thread.profile_id into v_inbox from public.club_inbox_threads thread where thread.id=v_target;
    select coalesce(nullif(club.name,''),'A club') into v_club_name from public.clubs club where club.id=v_inbox.club_id;
    v_type:='club_inbox_message'; v_event_key:='club_inbox_message:'||p_message_id;
    if v_sender_profile is not null then
      v_audience:='club_board'; v_audience_id:=v_inbox.club_id; v_title:=v_actor_name;
      v_body:=v_actor_name||': '||private.chat_notification_preview(v_kind,v_content,v_payload);
    else
      v_audience:='direct_user'; v_recipients:=jsonb_build_array(v_inbox.profile_id); v_title:=v_club_name;
      v_body:=v_club_name||': '||private.chat_notification_preview(v_kind,v_content,v_payload);
    end if;
  else
    raise exception 'Unsupported conversation' using errcode='22023';
  end if;
  if v_event_key is null then raise exception 'Canonical message not found' using errcode='P0002'; end if;
  v_args:=jsonb_build_object('actorName',v_actor_name,'groupName',coalesce(v_group_name,'Group chat'),
    'clubName',coalesce(v_club_name,'A club'),'content',private.chat_notification_preview(v_kind,v_content,v_payload),
    'messageKind',private.chat_notification_message_kind(v_kind,v_payload));
  return private.enqueue_notification_outbox_v2(v_event_key,v_type,v_actor,'message',v_target,v_audience,
    v_audience_id,jsonb_build_object('recipient_ids',v_recipients),v_title,v_body,v_args,null);
end $$;

revoke all on function private.enqueue_chat_notification_outbox_v2(text,uuid)
  from public,anon,authenticated;
grant execute on function private.enqueue_chat_notification_outbox_v2(text,uuid)
  to authenticated;

revoke all on function public.claim_notification_outbox_v2(text,integer,integer) from public, anon, authenticated;
revoke all on function public.expand_notification_outbox_v2(uuid,uuid,integer) from public, anon, authenticated;
revoke all on function public.fail_notification_outbox_v2(uuid,uuid,text,text,boolean,integer) from public, anon, authenticated;
revoke all on function public.claim_notification_deliveries_v2(text,integer,integer,integer) from public, anon, authenticated;
revoke all on function public.complete_notification_delivery_v2(uuid,uuid,text,integer,text,text,text,integer) from public, anon, authenticated;
revoke all on function public.notification_v2_metrics() from public, anon, authenticated;
grant execute on function public.claim_notification_outbox_v2(text,integer,integer) to service_role;
grant execute on function public.expand_notification_outbox_v2(uuid,uuid,integer) to service_role;
grant execute on function public.fail_notification_outbox_v2(uuid,uuid,text,text,boolean,integer) to service_role;
grant execute on function public.claim_notification_deliveries_v2(text,integer,integer,integer) to service_role;
grant execute on function public.complete_notification_delivery_v2(uuid,uuid,text,integer,text,text,text,integer) to service_role;
grant execute on function public.notification_v2_metrics() to service_role;

-- New content RPCs use the caller's existing RLS policies for the canonical
-- insert. The transaction-local flag makes the legacy triggers skip this row.
create or replace function public.create_club_post_v2(
  p_club_id uuid, p_content text, p_author_id uuid default null,
  p_image_path text default null, p_image_url text default null,
  p_is_announcement boolean default false, p_mentioned_user_ids uuid[] default '{}'
) returns public.club_posts language plpgsql security invoker set search_path = '' as $$
declare v_post public.club_posts%rowtype; v_club_name text; v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform private.enforce_authenticated_rate_limit('post_create:actor', null);
  perform private.enforce_authenticated_rate_limit('post_create:resource', p_club_id::text);
  perform set_config('app.notification_pipeline', 'v2', true);
  insert into public.club_posts(club_id,content,author_id,image_path,image_url,is_announcement)
  values(p_club_id,p_content,p_author_id,p_image_path,p_image_url,coalesce(p_is_announcement,false)) returning * into v_post;
  select coalesce(nullif(name,''),'A club') into v_club_name from public.clubs where id=p_club_id;
  perform private.enqueue_notification_outbox_v2('club_post:'||v_post.id,'club_post',v_actor,'post',v_post.id,
    'club_followers',p_club_id,jsonb_build_object('exclude_recipient_ids',to_jsonb(coalesce(p_mentioned_user_ids,'{}'::uuid[]))),v_club_name||' posted something new',
    v_club_name||' shared “'||left(p_content,360)||'”. Tap to view the post.',
    jsonb_build_object('clubName',v_club_name,'content',left(p_content,360)),null);
  if cardinality(coalesce(p_mentioned_user_ids,'{}')) > 0 then
    perform private.enqueue_notification_outbox_v2('post_mention:'||v_post.id,'club_post',v_actor,'post',v_post.id,
      'explicit_users',null,jsonb_build_object('recipient_ids',to_jsonb(p_mentioned_user_ids)),
      v_club_name||' mentioned you',v_club_name||' mentioned you in a post.',
      jsonb_build_object('clubName',v_club_name,'content',left(p_content,360)),null);
  end if;
  return v_post;
end $$;

create or replace function public.create_club_event_v2(
  p_club_id uuid, p_title text, p_description text, p_location text,
  p_event_date date, p_starts_at timestamptz, p_ends_at timestamptz,
  p_created_by_user_id uuid, p_image_path text default null, p_image_url text default null,
  p_tags text[] default '{}', p_registration_url text default null,
  p_schedule jsonb default null, p_speakers jsonb default '[]'
) returns public.events language plpgsql security invoker set search_path = '' as $$
declare v_event public.events%rowtype; v_club_name text; v_actor uuid:=auth.uid();
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform private.enforce_authenticated_rate_limit('event_create:actor', null);
  perform private.enforce_authenticated_rate_limit('event_create:resource', p_club_id::text);
  perform set_config('app.notification_pipeline','v2',true);
  insert into public.events(club_id,title,description,location,event_date,starts_at,ends_at,is_public,
    created_by_user_id,image_path,image_url,tags,registration_url,schedule,speakers)
  values(p_club_id,p_title,p_description,p_location,p_event_date,p_starts_at,p_ends_at,true,
    p_created_by_user_id,p_image_path,p_image_url,coalesce(p_tags,'{}'),p_registration_url,p_schedule,p_speakers)
  returning * into v_event;
  select coalesce(nullif(name,''),'A club') into v_club_name from public.clubs where id=p_club_id;
  perform private.enqueue_notification_outbox_v2('club_event:'||v_event.id,'club_event',v_actor,'event',v_event.id,
    'club_followers',p_club_id,'{}','New event from '||v_club_name,
    v_club_name||' announced “'||left(p_title,300)||'”. Tap for details and RSVP.',
    jsonb_build_object('clubName',v_club_name,'eventTitle',left(p_title,300)),null);
  return v_event;
end $$;

revoke all on function public.create_club_post_v2(uuid,text,uuid,text,text,boolean,uuid[]) from public,anon,authenticated;
revoke all on function public.create_club_event_v2(uuid,text,text,text,date,timestamptz,timestamptz,uuid,text,text,text[],text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.create_club_post_v2(uuid,text,uuid,text,text,boolean,uuid[]) to authenticated;
grant execute on function public.create_club_event_v2(uuid,text,text,text,date,timestamptz,timestamptz,uuid,text,text,text[],text,jsonb,jsonb) to authenticated;

-- Existing trigger functions remain byte-for-byte compatible for v1. The
-- disjoint WHEN predicates make v2 authoritative for marked transactions.
drop trigger if exists club_post_notification on public.club_posts;
create trigger club_post_notification after insert on public.club_posts for each row
when (current_setting('app.notification_pipeline', true) is distinct from 'v2')
execute function private.notify_club_post();
drop trigger if exists club_event_notification on public.events;
create trigger club_event_notification after insert on public.events for each row
when (current_setting('app.notification_pipeline', true) is distinct from 'v2')
execute function private.notify_club_event();
drop trigger if exists direct_message_notification on public.direct_messages;
create trigger direct_message_notification after insert on public.direct_messages for each row
when (current_setting('app.notification_pipeline', true) is distinct from 'v2')
execute function private.notify_direct_message();
drop trigger if exists group_message_notification on public.group_messages;
create trigger group_message_notification after insert on public.group_messages for each row
when (current_setting('app.notification_pipeline', true) is distinct from 'v2')
execute function private.notify_group_message();
drop trigger if exists club_channel_message_notification on public.club_channel_messages;
create trigger club_channel_message_notification after insert on public.club_channel_messages for each row
when (new.message_kind = 'announcement' and current_setting('app.notification_pipeline', true) is distinct from 'v2')
execute function private.notify_club_channel_message();
drop trigger if exists club_channel_mention_notification on public.club_channel_messages;
create trigger club_channel_mention_notification after insert on public.club_channel_messages for each row
when (new.message_kind <> 'announcement' and jsonb_typeof(new.payload -> 'mentions') = 'array'
  and jsonb_array_length(new.payload -> 'mentions') > 0
  and current_setting('app.notification_pipeline', true) is distinct from 'v2')
execute function private.notify_club_channel_mention();
drop trigger if exists club_inbox_message_notification on public.club_inbox_messages;
create trigger club_inbox_message_notification after insert on public.club_inbox_messages for each row
when (current_setting('app.notification_pipeline', true) is distinct from 'v2')
execute function private.notify_club_inbox_message();

-- V2 canonical rows are pushed only by notification-worker-v2. Legacy rows
-- retain the original one-webhook-per-row behavior for released clients.
drop trigger if exists send_notification_push on public.notifications;
create trigger send_notification_push after insert on public.notifications for each row
when (new.pipeline_version = 1) execute function private.dispatch_notification_push();
drop trigger if exists send_grouped_notification_push on public.notifications;
create trigger send_grouped_notification_push after update of actor_user_id,type,title,body,target_type,target_id,
  dedupe_key,localization_args,notification_group_key,message_count,created_at on public.notifications
for each row when (new.notification_group_key is not null and new.pipeline_version = 1)
execute function private.dispatch_notification_push();

comment on table public.notification_outbox_v2 is
  'Durable logical notification events. Client roles have no table privileges; service workers use narrow RPCs.';
