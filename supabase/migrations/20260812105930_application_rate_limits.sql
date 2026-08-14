-- Shared abuse-protection infrastructure for opt-in v2 mutation APIs.
--
-- Released clients keep their direct Data API contracts and are deliberately
-- not placed behind table-wide rate-limit triggers. Secure v2 RPCs call the
-- authenticated helper explicitly. Pre-auth Edge Functions use the
-- service-role-only public.consume_edge_rate_limit RPC.
-- Scope material (user ids, IPs, emails, resource ids) is SHA-256 hashed before
-- storage; no OTPs, capabilities, passwords, JWTs, or raw network addresses are
-- retained here.

create schema if not exists private;
create extension if not exists pgcrypto with schema extensions;

create table private.rate_limit_rules (
  action text primary key
    constraint rate_limit_rules_action_format
      check (action ~ '^[a-z0-9_]+:[a-z0-9_]+$'),
  burst_capacity numeric(20, 4) not null
    constraint rate_limit_rules_burst_capacity_positive
      check (burst_capacity > 0),
  burst_window interval not null
    constraint rate_limit_rules_burst_window_positive
      check (burst_window > interval '0 seconds'),
  sustained_capacity numeric(20, 4) not null
    constraint rate_limit_rules_sustained_capacity_positive
      check (sustained_capacity > 0),
  sustained_window interval not null
    constraint rate_limit_rules_sustained_window_positive
      check (sustained_window > interval '0 seconds'),
  privileged_multiplier numeric(8, 2) not null default 4
    constraint rate_limit_rules_privileged_multiplier_valid
      check (privileged_multiplier >= 1 and privileged_multiplier <= 20),
  bucket_ttl interval not null default interval '2 days'
    constraint rate_limit_rules_bucket_ttl_valid
      check (bucket_ttl >= sustained_window),
  enabled boolean not null default true,
  description text not null
);

create table private.rate_limit_buckets (
  action text not null references private.rate_limit_rules(action)
    on update cascade on delete cascade,
  scope_hash text not null
    constraint rate_limit_buckets_scope_hash_format
      check (scope_hash ~ '^[0-9a-f]{64}$'),
  actor_class text not null
    constraint rate_limit_buckets_actor_class_valid
      check (actor_class in ('authenticated', 'privileged', 'unauthenticated')),
  burst_tokens numeric(20, 6) not null,
  burst_refilled_at timestamptz not null,
  sustained_tokens numeric(20, 6) not null,
  sustained_refilled_at timestamptz not null,
  allowed_count bigint not null default 0,
  rejected_count bigint not null default 0,
  last_allowed_at timestamptz,
  last_rejected_at timestamptz,
  expires_at timestamptz not null,
  primary key (action, scope_hash)
);

create index rate_limit_buckets_expiry_idx
  on private.rate_limit_buckets (expires_at);

-- Rejections from Edge Functions are aggregated hourly. Trigger rejections
-- cannot be retained in a table because the rejected parent transaction must
-- roll back; private.consume_rate_limit emits a structured PostgreSQL LOG for
-- those instead.
create table private.rate_limit_events (
  action text not null,
  scope_hash text not null
    constraint rate_limit_events_scope_hash_format
      check (scope_hash ~ '^[0-9a-f]{64}$'),
  actor_class text not null
    constraint rate_limit_events_actor_class_valid
      check (actor_class in ('authenticated', 'privileged', 'unauthenticated')),
  limiting_window text not null
    constraint rate_limit_events_window_valid
      check (limiting_window in ('burst', 'sustained', 'both')),
  window_started_at timestamptz not null,
  rejection_count bigint not null default 1,
  max_retry_after_seconds integer not null,
  last_rejected_at timestamptz not null,
  primary key (action, scope_hash, limiting_window, window_started_at)
);

create index rate_limit_events_window_idx
  on private.rate_limit_events (window_started_at);
create index rate_limit_events_action_window_idx
  on private.rate_limit_events (action, window_started_at desc);

-- A sequence is a non-blocking global request clock. It lets the limiter run
-- deterministic bounded cleanup even when pg_cron is unavailable, without a
-- hot singleton row or an unbounded housekeeping table.
create sequence private.rate_limit_cleanup_clock;

comment on table private.rate_limit_events is
  'Hourly aggregates of Edge rate-limit rejections. Scope hashes are pseudonymous and expire after 30 days.';

revoke all on table private.rate_limit_rules from public, anon, authenticated;
revoke all on table private.rate_limit_buckets from public, anon, authenticated;
revoke all on table private.rate_limit_events from public, anon, authenticated;
revoke all on sequence private.rate_limit_cleanup_clock
  from public, anon, authenticated;

insert into private.rate_limit_rules (
  action,
  burst_capacity,
  burst_window,
  sustained_capacity,
  sustained_window,
  privileged_multiplier,
  description
) values
  -- Pre-auth flows. IP buckets are deliberately generous for university/NAT
  -- networks; the IP+email bucket is the tighter security boundary.
  ('auth_signup_request:ip', 10, interval '10 minutes', 100, interval '1 day', 1, 'Signup email requests per network address'),
  ('auth_signup_request:identity', 3, interval '10 minutes', 10, interval '1 day', 1, 'Signup email requests per network address and normalized email'),
  ('auth_signup_verify:ip', 100, interval '15 minutes', 1000, interval '1 day', 1, 'Signup verification attempts per network address'),
  ('auth_signup_verify:identity', 10, interval '15 minutes', 30, interval '1 day', 1, 'Signup verification attempts per network address and normalized email'),
  ('auth_signup_complete:ip', 50, interval '1 hour', 200, interval '1 day', 1, 'Signup completions per network address'),
  ('auth_signup_complete:identity', 5, interval '15 minutes', 20, interval '1 day', 1, 'Signup completions per network address and normalized email'),
  ('auth_password_reset_request:ip', 20, interval '1 hour', 100, interval '1 day', 1, 'Password-reset email requests per network address'),
  ('auth_password_reset_request:identity', 3, interval '10 minutes', 10, interval '1 day', 1, 'Password-reset email requests per network address and normalized email'),
  ('auth_password_reset_verify:ip', 100, interval '15 minutes', 1000, interval '1 day', 1, 'Password-reset verification attempts per network address'),
  ('auth_password_reset_verify:identity', 10, interval '15 minutes', 30, interval '1 day', 1, 'Password-reset verification attempts per network address and normalized email'),
  ('auth_password_reset_complete:ip', 50, interval '1 hour', 200, interval '1 day', 1, 'Password-reset completions per network address'),
  ('auth_password_reset_complete:identity', 5, interval '15 minutes', 20, interval '1 day', 1, 'Password-reset completions per network address and normalized email'),
  ('push_dispatch:ip', 5000, interval '1 minute', 50000, interval '1 hour', 1, 'High ceiling for database-webhook push dispatches sharing an egress address'),
  ('push_dispatch:resource', 2, interval '1 minute', 5, interval '1 hour', 1, 'Idempotent push claims per notification and address'),

  -- Fan-out/content operations. Resource scopes always also include the actor,
  -- so one club or conversation cannot cause unrelated actors to block.
  ('post_create:actor', 5, interval '1 minute', 50, interval '1 day', 4, 'Post creations per actor'),
  ('post_create:resource', 3, interval '1 minute', 25, interval '1 day', 4, 'Post creations per actor and club'),
  ('post_update:actor', 20, interval '1 minute', 250, interval '1 day', 4, 'Post updates per actor'),
  ('post_update:resource', 15, interval '1 minute', 150, interval '1 day', 4, 'Post updates per actor and club'),
  ('post_delete:actor', 10, interval '1 minute', 100, interval '1 day', 4, 'Post deletions per actor'),
  ('post_delete:resource', 8, interval '1 minute', 50, interval '1 day', 4, 'Post deletions per actor and club'),
  ('event_create:actor', 3, interval '1 minute', 25, interval '1 day', 4, 'Event creations per actor'),
  ('event_create:resource', 3, interval '1 minute', 20, interval '1 day', 4, 'Event creations per actor and club'),
  ('event_update:actor', 15, interval '1 minute', 150, interval '1 day', 4, 'Event updates per actor'),
  ('event_update:resource', 12, interval '1 minute', 100, interval '1 day', 4, 'Event updates per actor and club'),
  ('event_delete:actor', 8, interval '1 minute', 50, interval '1 day', 4, 'Event deletions per actor'),
  ('event_delete:resource', 6, interval '1 minute', 30, interval '1 day', 4, 'Event deletions per actor and club'),
  ('comment_create:actor', 25, interval '1 minute', 300, interval '1 hour', 4, 'Comment creations per actor'),
  ('comment_create:resource', 8, interval '1 minute', 80, interval '1 hour', 4, 'Comment creations per actor and post'),
  ('like_change:actor', 120, interval '1 minute', 3000, interval '1 day', 4, 'Like or unlike mutations per actor'),
  ('like_change:resource', 12, interval '1 minute', 50, interval '1 day', 4, 'Like cycling per actor and post'),
  ('profile_follow_change:actor', 30, interval '1 minute', 500, interval '1 day', 4, 'Profile follow or unfollow mutations per actor'),
  ('profile_follow_change:resource', 6, interval '10 minutes', 20, interval '1 day', 4, 'Follow cycling per actor and target profile'),
  ('club_follow_change:actor', 30, interval '1 minute', 500, interval '1 day', 4, 'Club follow or unfollow mutations per actor'),
  ('club_follow_change:resource', 6, interval '10 minutes', 20, interval '1 day', 4, 'Follow cycling per actor and club'),
  ('poll_create:actor', 5, interval '10 minutes', 25, interval '1 day', 4, 'Poll creations per actor'),
  ('poll_create:resource', 3, interval '10 minutes', 10, interval '1 day', 4, 'Poll creations per actor and post'),
  ('poll_vote_change:actor', 30, interval '1 minute', 500, interval '1 day', 4, 'Poll vote changes per actor'),
  ('poll_vote_change:resource', 6, interval '1 minute', 30, interval '1 day', 4, 'Poll vote changes per actor and poll'),
  ('event_rsvp_change:actor', 30, interval '1 minute', 300, interval '1 day', 4, 'RSVP mutations per actor'),
  ('event_rsvp_change:resource', 8, interval '10 minutes', 30, interval '1 day', 4, 'RSVP cycling per actor and event'),
  ('event_checkin_change:actor', 300, interval '1 minute', 10000, interval '1 day', 4, 'Scanner check-in mutations per actor'),
  ('event_checkin_change:resource', 120, interval '1 minute', 3000, interval '1 day', 4, 'Scanner check-in mutations per actor and event'),
  ('message_send:actor', 30, interval '1 minute', 400, interval '1 hour', 4, 'Messages across all conversations per actor'),
  ('message_send:resource', 15, interval '1 minute', 200, interval '1 hour', 4, 'Messages per actor and conversation'),
  ('moderation_report:actor', 5, interval '1 hour', 20, interval '1 day', 4, 'Moderation reports per actor'),
  ('moderation_report:resource', 2, interval '1 hour', 5, interval '1 day', 4, 'Repeated reports per actor and target'),
  ('group_create:actor', 5, interval '1 minute', 25, interval '1 day', 4, 'Group chats created per actor'),
  ('group_update:actor', 20, interval '1 minute', 100, interval '1 day', 4, 'Group chat updates per actor'),
  ('group_update:resource', 10, interval '1 minute', 60, interval '1 day', 4, 'Group chat updates per actor and group'),
  ('group_member_change:actor', 40, interval '1 minute', 500, interval '1 day', 4, 'Group membership mutations per actor'),
  ('group_member_change:resource', 25, interval '1 minute', 300, interval '1 day', 4, 'Group membership mutations per actor and group'),
  ('user_block_change:actor', 20, interval '1 minute', 200, interval '1 day', 4, 'Block or unblock mutations per actor'),
  ('user_block_change:resource', 4, interval '1 hour', 10, interval '1 day', 4, 'Block cycling per actor and target')
on conflict (action) do update set
  burst_capacity = excluded.burst_capacity,
  burst_window = excluded.burst_window,
  sustained_capacity = excluded.sustained_capacity,
  sustained_window = excluded.sustained_window,
  privileged_multiplier = excluded.privileged_multiplier,
  bucket_ttl = excluded.bucket_ttl,
  enabled = excluded.enabled,
  description = excluded.description;

create or replace function private.cleanup_rate_limits(p_batch_size integer default 5000)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_batch_size integer := least(greatest(coalesce(p_batch_size, 5000), 1), 20000);
  v_deleted_buckets integer;
  v_deleted_events integer;
begin
  with expired as (
    select bucket.ctid
    from private.rate_limit_buckets as bucket
    where bucket.expires_at < clock_timestamp()
    order by bucket.expires_at
    limit v_batch_size
  )
  delete from private.rate_limit_buckets as bucket
  using expired
  where bucket.ctid = expired.ctid;
  get diagnostics v_deleted_buckets = row_count;

  with expired as (
    select event.ctid
    from private.rate_limit_events as event
    where event.window_started_at < clock_timestamp() - interval '30 days'
    order by event.window_started_at
    limit v_batch_size
  )
  delete from private.rate_limit_events as event
  using expired
  where event.ctid = expired.ctid;
  get diagnostics v_deleted_events = row_count;

  return jsonb_build_object(
    'deleted_buckets', v_deleted_buckets,
    'deleted_events', v_deleted_events
  );
end
$function$;

revoke all on function private.cleanup_rate_limits(integer)
  from public, anon, authenticated;

create or replace function private.consume_rate_limit(
  p_action text,
  p_scope_material text,
  p_actor_class text,
  p_privileged boolean default false,
  p_cost numeric default 1,
  p_raise_on_reject boolean default true,
  p_record_event boolean default false
)
returns table (
  allowed boolean,
  retry_after_seconds integer,
  limiting_window text
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_rule private.rate_limit_rules%rowtype;
  v_bucket private.rate_limit_buckets%rowtype;
  v_now timestamptz := clock_timestamp();
  v_scope_hash text;
  v_multiplier numeric;
  v_burst_capacity numeric;
  v_sustained_capacity numeric;
  v_burst_seconds numeric;
  v_sustained_seconds numeric;
  v_burst_tokens numeric;
  v_sustained_tokens numeric;
  v_burst_retry numeric := 0;
  v_sustained_retry numeric := 0;
  v_retry integer := 0;
  v_limiting_window text;
  v_allowed boolean;
begin
  if p_actor_class not in ('authenticated', 'privileged', 'unauthenticated') then
    raise exception 'Invalid rate-limit actor class' using errcode = '22023';
  end if;
  if p_scope_material is null or btrim(p_scope_material) = ''
      or char_length(p_scope_material) > 2048 then
    raise exception 'Invalid rate-limit scope' using errcode = '22023';
  end if;
  if p_cost is null or p_cost <= 0 then
    raise exception 'Invalid rate-limit cost' using errcode = '22023';
  end if;

  select rule.* into v_rule
  from private.rate_limit_rules as rule
  where rule.action = p_action
    and rule.enabled;
  if not found then
    -- Missing protection is a deployment/configuration error. Failing closed
    -- keeps a misspelled trigger or Edge action from silently bypassing limits.
    raise exception 'Unknown or disabled rate-limit action: %', p_action
      using errcode = '22023';
  end if;

  v_multiplier := case when p_privileged then v_rule.privileged_multiplier else 1 end;
  v_burst_capacity := v_rule.burst_capacity * v_multiplier;
  v_sustained_capacity := v_rule.sustained_capacity * v_multiplier;
  if p_cost > v_burst_capacity or p_cost > v_sustained_capacity then
    raise exception 'Rate-limit cost exceeds configured capacity for %', p_action
      using errcode = '22023';
  end if;

  v_burst_seconds := extract(epoch from v_rule.burst_window);
  v_sustained_seconds := extract(epoch from v_rule.sustained_window);
  v_scope_hash := encode(
    extensions.digest(
      convert_to(p_action || chr(31) || p_scope_material, 'UTF8'),
      'sha256'
    ),
    'hex'
  );

  insert into private.rate_limit_buckets (
    action,
    scope_hash,
    actor_class,
    burst_tokens,
    burst_refilled_at,
    sustained_tokens,
    sustained_refilled_at,
    expires_at
  ) values (
    p_action,
    v_scope_hash,
    p_actor_class,
    v_burst_capacity,
    v_now,
    v_sustained_capacity,
    v_now,
    v_now + v_rule.bucket_ttl
  )
  on conflict (action, scope_hash) do nothing;

  -- This is the concurrency boundary. No network or unrelated table work is
  -- performed inside the limiter. PostgreSQL retains the row lock until the
  -- parent mutation commits, deliberately serializing one actor's writes; the
  -- existing synchronous notification fan-out is still a reason to adopt the
  -- later outbox architecture.
  select bucket.* into v_bucket
  from private.rate_limit_buckets as bucket
  where bucket.action = p_action
    and bucket.scope_hash = v_scope_hash
  for update;

  -- A concurrent insert may have waited on the unique key before reaching the
  -- row lock. Refresh the clock after serialization so refill timestamps never
  -- move backwards and lock-wait time is accounted for correctly.
  v_now := clock_timestamp();

  v_burst_tokens := least(
    v_burst_capacity,
    v_bucket.burst_tokens
      + greatest(extract(epoch from v_now - v_bucket.burst_refilled_at), 0)
        * v_burst_capacity / v_burst_seconds
  );
  v_sustained_tokens := least(
    v_sustained_capacity,
    v_bucket.sustained_tokens
      + greatest(extract(epoch from v_now - v_bucket.sustained_refilled_at), 0)
        * v_sustained_capacity / v_sustained_seconds
  );
  v_allowed := v_burst_tokens >= p_cost and v_sustained_tokens >= p_cost;

  if v_allowed then
    v_burst_tokens := v_burst_tokens - p_cost;
    v_sustained_tokens := v_sustained_tokens - p_cost;
    v_limiting_window := null;
  else
    if v_burst_tokens < p_cost then
      v_burst_retry := (p_cost - v_burst_tokens)
        * v_burst_seconds / v_burst_capacity;
    end if;
    if v_sustained_tokens < p_cost then
      v_sustained_retry := (p_cost - v_sustained_tokens)
        * v_sustained_seconds / v_sustained_capacity;
    end if;
    v_retry := greatest(1, ceil(greatest(v_burst_retry, v_sustained_retry))::integer);
    v_limiting_window := case
      when v_burst_tokens < p_cost and v_sustained_tokens < p_cost then 'both'
      when v_burst_tokens < p_cost then 'burst'
      else 'sustained'
    end;
  end if;

  update private.rate_limit_buckets as bucket set
    actor_class = p_actor_class,
    burst_tokens = v_burst_tokens,
    burst_refilled_at = v_now,
    sustained_tokens = v_sustained_tokens,
    sustained_refilled_at = v_now,
    allowed_count = bucket.allowed_count + case when v_allowed then 1 else 0 end,
    rejected_count = bucket.rejected_count + case when v_allowed then 0 else 1 end,
    last_allowed_at = case when v_allowed then v_now else bucket.last_allowed_at end,
    last_rejected_at = case when v_allowed then bucket.last_rejected_at else v_now end,
    expires_at = v_now + v_rule.bucket_ttl
  where bucket.action = p_action
    and bucket.scope_hash = v_scope_hash;

  if not v_allowed then
    raise log 'rate_limit_rejected action=% actor_class=% bucket=% scope_hash=% retry_after_seconds=%',
      p_action, p_actor_class, v_limiting_window, v_scope_hash, v_retry;

    if p_record_event then
      insert into private.rate_limit_events (
        action,
        scope_hash,
        actor_class,
        limiting_window,
        window_started_at,
        rejection_count,
        max_retry_after_seconds,
        last_rejected_at
      ) values (
        p_action,
        v_scope_hash,
        p_actor_class,
        v_limiting_window,
        date_trunc('hour', v_now),
        1,
        v_retry,
        v_now
      )
      on conflict on constraint rate_limit_events_pkey
      do update set
        rejection_count = private.rate_limit_events.rejection_count + 1,
        max_retry_after_seconds = greatest(
          private.rate_limit_events.max_retry_after_seconds,
          excluded.max_retry_after_seconds
        ),
        last_rejected_at = excluded.last_rejected_at;
    end if;
  end if;

  -- Every 1,024 checks, clean up to 5,000 expired rows. nextval does not lock a
  -- shared counter row, and inactive projects clean on their next request.
  if nextval('private.rate_limit_cleanup_clock'::regclass) % 1024 = 0 then
    perform private.cleanup_rate_limits(5000);
  end if;

  if not v_allowed and p_raise_on_reject then
    raise sqlstate 'PGRST'
      using
        message = jsonb_build_object(
          'code', 'rate_limit_exceeded',
          'message', 'Too many requests. Try again later.',
          'details', jsonb_build_object(
            'retry_after_seconds', v_retry,
            'action', p_action
          ),
          'hint', 'Respect Retry-After before retrying.'
        )::text,
        detail = jsonb_build_object(
          'status', 429,
          'headers', jsonb_build_object(
            'Retry-After', v_retry::text,
            'Cache-Control', 'no-store'
          )
        )::text;
  end if;

  return query select v_allowed, v_retry, v_limiting_window;
end
$function$;

revoke all on function private.consume_rate_limit(text, text, text, boolean, numeric, boolean, boolean)
  from public, anon, authenticated;

create or replace function private.enforce_authenticated_rate_limit(
  p_action text,
  p_resource text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_privileged boolean;
  v_scope text;
begin
  -- Migrations and trusted service-role maintenance do not represent an end
  -- user. Every authenticated Data API request must have a JWT-derived actor.
  if v_actor is null then
    if session_user = 'postgres'
        or coalesce(auth.jwt() ->> 'role', '') = 'service_role' then
      return;
    end if;
    raise exception 'An authenticated actor is required'
      using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.app_admins as app_admin
    where app_admin.auth_user_id = v_actor
  ) into v_privileged;

  v_scope := 'actor=' || v_actor::text;
  if p_resource is not null and btrim(p_resource) <> '' then
    v_scope := v_scope || '|resource=' || left(p_resource, 512);
  end if;

  perform * from private.consume_rate_limit(
    p_action,
    v_scope,
    case when v_privileged then 'privileged' else 'authenticated' end,
    v_privileged,
    1,
    true,
    false
  );
end
$function$;

revoke all on function private.enforce_authenticated_rate_limit(text, text)
  from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.enforce_authenticated_rate_limit(text, text)
  to authenticated;

comment on function private.enforce_authenticated_rate_limit(text, text) is
  'JWT-actor limiter for opt-in v2 RPCs; not exposed through the Data API private schema.';

create or replace function public.consume_edge_rate_limit(
  p_action text,
  p_scope text
)
returns table (
  allowed boolean,
  retry_after_seconds integer,
  limiting_window text
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  -- Caller-supplied pre-auth scopes are only accepted from server-side Edge
  -- Functions. Publishable-key callers cannot choose or drain another bucket.
  if session_user <> 'postgres'
      and coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Service role required' using errcode = '42501';
  end if;

  return query
  select result.allowed, result.retry_after_seconds, result.limiting_window
  from private.consume_rate_limit(
    p_action,
    'edge=' || p_scope,
    'unauthenticated',
    false,
    1,
    false,
    true
  ) as result;
end
$function$;

revoke all on function public.consume_edge_rate_limit(text, text)
  from public, anon, authenticated;
grant execute on function public.consume_edge_rate_limit(text, text)
  to service_role;

comment on function public.consume_edge_rate_limit(text, text) is
  'Service-role-only pre-auth limiter. Raw scopes are hashed before storage.';

-- Use pg_cron when already enabled; do not enable a new extension solely for
-- housekeeping because the bounded lazy cleanup above is sufficient fallback.
do $migration$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    execute $sql$
      select cron.unschedule(jobid)
      from cron.job
      where jobname = 'rate-limit-retention'
    $sql$;
    execute $sql$
      select cron.schedule(
        'rate-limit-retention',
        '17 3 * * *',
        'select private.cleanup_rate_limits(20000)'
      )
    $sql$;
  end if;
end
$migration$;

-- Deliberately no table-wide rate-limit triggers. Released clients still write
-- these tables directly. Installing triggers here would silently put v1 behind
-- new quotas and change successful legacy requests into 429 errors. Each new
-- v2 mutation RPC opts in by calling the authenticated helper above.

-- Preserve and make reproducible the live Storage size/MIME boundaries. Direct
-- Storage uploads cannot be atomically request/byte-rate-limited from an app
-- table trigger; doing so safely requires an authenticated upload broker (see
-- the accompanying audit). These bucket controls still reject oversized or
-- unexpected media at the Storage service boundary.
update storage.buckets set
  file_size_limit = 1048576,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id in ('avatars', 'club-avatars');

update storage.buckets set
  file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id in ('post-images', 'event-images', 'group-chat-photos');

update storage.buckets set
  file_size_limit = 10485760,
  allowed_mime_types = array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/heic',
    'image/heif'
  ]
where id = 'chat-attachments';
