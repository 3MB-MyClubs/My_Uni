-- F1 v2: capability-based signup and password-reset protocols. These tables
-- are intentionally separate from public.pending_* legacy state.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table private.signup_challenges_v2 (
  email text primary key,
  code_hash text not null,
  expires_at timestamptz not null,
  attempt_count smallint not null default 0,
  capability_hash text,
  capability_expires_at timestamptz,
  consumed_at timestamptz,
  last_sent_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint signup_challenges_v2_attempt_count_check
    check (attempt_count between 0 and 5),
  constraint signup_challenges_v2_capability_state_check
    check (
      (capability_hash is null and capability_expires_at is null)
      or
      (capability_hash is not null and capability_expires_at is not null)
    )
);

create table private.password_reset_challenges_v2 (
  email text primary key,
  code_hash text not null,
  expires_at timestamptz not null,
  attempt_count smallint not null default 0,
  capability_hash text,
  capability_expires_at timestamptz,
  consumed_at timestamptz,
  last_sent_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint password_reset_challenges_v2_attempt_count_check
    check (attempt_count between 0 and 5),
  constraint password_reset_challenges_v2_capability_state_check
    check (
      (capability_hash is null and capability_expires_at is null)
      or
      (capability_hash is not null and capability_expires_at is not null)
    )
);

alter table private.signup_challenges_v2 enable row level security;
alter table private.password_reset_challenges_v2 enable row level security;

revoke all on table private.signup_challenges_v2
  from public, anon, authenticated, service_role;
revoke all on table private.password_reset_challenges_v2
  from public, anon, authenticated, service_role;
grant select, insert, update, delete on table private.signup_challenges_v2
  to service_role;
grant select, insert, update, delete on table private.password_reset_challenges_v2
  to service_role;
grant usage on schema private to service_role;

create or replace function public.issue_signup_challenge_v2(
  p_email text,
  p_code_hash text,
  p_expires_at timestamptz
)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_issued boolean;
begin
  insert into private.signup_challenges_v2 (
    email, code_hash, expires_at, attempt_count, capability_hash,
    capability_expires_at, consumed_at, last_sent_at, created_at
  ) values (
    lower(trim(p_email)), p_code_hash, p_expires_at, 0, null,
    null, null, now(), now()
  )
  on conflict (email) do update
  set code_hash = excluded.code_hash,
      expires_at = excluded.expires_at,
      attempt_count = 0,
      capability_hash = null,
      capability_expires_at = null,
      consumed_at = null,
      last_sent_at = excluded.last_sent_at,
      created_at = excluded.created_at
  where private.signup_challenges_v2.last_sent_at <= now() - interval '60 seconds'
  returning true into v_issued;

  return case when coalesce(v_issued, false) then 'issued' else 'cooldown' end;
end
$function$;

create or replace function public.issue_password_reset_challenge_v2(
  p_email text,
  p_code_hash text,
  p_expires_at timestamptz
)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_issued boolean;
begin
  insert into private.password_reset_challenges_v2 (
    email, code_hash, expires_at, attempt_count, capability_hash,
    capability_expires_at, consumed_at, last_sent_at, created_at
  ) values (
    lower(trim(p_email)), p_code_hash, p_expires_at, 0, null,
    null, null, now(), now()
  )
  on conflict (email) do update
  set code_hash = excluded.code_hash,
      expires_at = excluded.expires_at,
      attempt_count = 0,
      capability_hash = null,
      capability_expires_at = null,
      consumed_at = null,
      last_sent_at = excluded.last_sent_at,
      created_at = excluded.created_at
  where private.password_reset_challenges_v2.last_sent_at <= now() - interval '60 seconds'
  returning true into v_issued;

  return case when coalesce(v_issued, false) then 'issued' else 'cooldown' end;
end
$function$;

create or replace function public.verify_signup_challenge_v2(
  p_email text,
  p_code_hash text,
  p_capability_hash text
)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_row private.signup_challenges_v2%rowtype;
begin
  select * into v_row
  from private.signup_challenges_v2
  where email = lower(trim(p_email))
  for update;

  if not found or v_row.consumed_at is not null
    or v_row.capability_hash is not null then
    return 'invalid';
  end if;
  if v_row.attempt_count >= 5 then
    return 'locked';
  end if;
  if v_row.expires_at <= now() then
    return 'expired';
  end if;
  if v_row.code_hash <> p_code_hash then
    update private.signup_challenges_v2
    set attempt_count = attempt_count + 1
    where email = v_row.email;
    return case when v_row.attempt_count + 1 >= 5 then 'locked' else 'invalid' end;
  end if;

  update private.signup_challenges_v2
  set code_hash = 'verified',
      capability_hash = p_capability_hash,
      capability_expires_at = least(v_row.expires_at, now() + interval '5 minutes')
  where email = v_row.email;
  return 'ok';
end
$function$;

create or replace function public.verify_password_reset_challenge_v2(
  p_email text,
  p_code_hash text,
  p_capability_hash text
)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_row private.password_reset_challenges_v2%rowtype;
begin
  select * into v_row
  from private.password_reset_challenges_v2
  where email = lower(trim(p_email))
  for update;

  if not found or v_row.consumed_at is not null
    or v_row.capability_hash is not null then
    return 'invalid';
  end if;
  if v_row.attempt_count >= 5 then
    return 'locked';
  end if;
  if v_row.expires_at <= now() then
    return 'expired';
  end if;
  if v_row.code_hash <> p_code_hash then
    update private.password_reset_challenges_v2
    set attempt_count = attempt_count + 1
    where email = v_row.email;
    return case when v_row.attempt_count + 1 >= 5 then 'locked' else 'invalid' end;
  end if;

  update private.password_reset_challenges_v2
  set code_hash = 'verified',
      capability_hash = p_capability_hash,
      capability_expires_at = least(v_row.expires_at, now() + interval '5 minutes')
  where email = v_row.email;
  return 'ok';
end
$function$;

create or replace function public.consume_signup_capability_v2(
  p_email text,
  p_capability_hash text
)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_row private.signup_challenges_v2%rowtype;
begin
  select * into v_row
  from private.signup_challenges_v2
  where email = lower(trim(p_email))
  for update;

  if not found or v_row.consumed_at is not null
    or v_row.capability_hash is null
    or v_row.capability_hash <> p_capability_hash then
    return 'invalid';
  end if;
  if v_row.capability_expires_at is null or v_row.capability_expires_at <= now() then
    return 'expired';
  end if;

  update private.signup_challenges_v2
  set consumed_at = now(),
      capability_hash = null,
      capability_expires_at = null
  where email = v_row.email;
  return 'ok';
end
$function$;

create or replace function public.consume_password_reset_capability_v2(
  p_email text,
  p_capability_hash text
)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_row private.password_reset_challenges_v2%rowtype;
begin
  select * into v_row
  from private.password_reset_challenges_v2
  where email = lower(trim(p_email))
  for update;

  if not found or v_row.consumed_at is not null
    or v_row.capability_hash is null
    or v_row.capability_hash <> p_capability_hash then
    return 'invalid';
  end if;
  if v_row.capability_expires_at is null or v_row.capability_expires_at <= now() then
    return 'expired';
  end if;

  update private.password_reset_challenges_v2
  set consumed_at = now(),
      capability_hash = null,
      capability_expires_at = null
  where email = v_row.email;
  return 'ok';
end
$function$;

create or replace function public.cancel_signup_challenge_v2(
  p_email text,
  p_code_hash text
)
returns void
language sql
set search_path = ''
as $function$
  delete from private.signup_challenges_v2
  where email = lower(trim(p_email))
    and code_hash = p_code_hash
    and capability_hash is null
    and consumed_at is null;
$function$;

create or replace function public.cancel_password_reset_challenge_v2(
  p_email text,
  p_code_hash text
)
returns void
language sql
set search_path = ''
as $function$
  delete from private.password_reset_challenges_v2
  where email = lower(trim(p_email))
    and code_hash = p_code_hash
    and capability_hash is null
    and consumed_at is null;
$function$;

revoke all on function public.issue_signup_challenge_v2(text, text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.issue_password_reset_challenge_v2(text, text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.verify_signup_challenge_v2(text, text, text)
  from public, anon, authenticated;
revoke all on function public.verify_password_reset_challenge_v2(text, text, text)
  from public, anon, authenticated;
revoke all on function public.consume_signup_capability_v2(text, text)
  from public, anon, authenticated;
revoke all on function public.consume_password_reset_capability_v2(text, text)
  from public, anon, authenticated;
revoke all on function public.cancel_signup_challenge_v2(text, text)
  from public, anon, authenticated;
revoke all on function public.cancel_password_reset_challenge_v2(text, text)
  from public, anon, authenticated;

grant execute on function public.issue_signup_challenge_v2(text, text, timestamptz)
  to service_role;
grant execute on function public.issue_password_reset_challenge_v2(text, text, timestamptz)
  to service_role;
grant execute on function public.verify_signup_challenge_v2(text, text, text)
  to service_role;
grant execute on function public.verify_password_reset_challenge_v2(text, text, text)
  to service_role;
grant execute on function public.consume_signup_capability_v2(text, text)
  to service_role;
grant execute on function public.consume_password_reset_capability_v2(text, text)
  to service_role;
grant execute on function public.cancel_signup_challenge_v2(text, text)
  to service_role;
grant execute on function public.cancel_password_reset_challenge_v2(text, text)
  to service_role;
