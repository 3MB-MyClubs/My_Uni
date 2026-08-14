-- Restore the database contract used by the currently released app while the
-- v2 capability protocol is rolled out independently.
--
-- TEMPORARY LEGACY COMPATIBILITY — remove after minimum supported app version advances.
-- The released client cannot carry a completion capability, so these legacy
-- rows deliberately retain the historical verified flag. V2 never reads or
-- writes these tables.

alter table public.pending_signups
  drop constraint if exists pending_signups_verified_is_legacy;

alter table public.pending_password_resets
  drop constraint if exists pending_password_resets_verified_is_legacy;

create or replace function public.issue_signup_challenge_legacy(
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
  insert into public.pending_signups (
    email,
    code_hash,
    verified,
    expires_at,
    created_at,
    attempt_count,
    max_attempts,
    capability_hash,
    capability_expires_at,
    consumed_at,
    last_sent_at
  ) values (
    lower(trim(p_email)),
    p_code_hash,
    false,
    p_expires_at,
    now(),
    0,
    5,
    null,
    null,
    null,
    now()
  )
  on conflict (email) do update
  set code_hash = excluded.code_hash,
      verified = false,
      expires_at = excluded.expires_at,
      created_at = excluded.created_at,
      attempt_count = 0,
      max_attempts = 5,
      capability_hash = null,
      capability_expires_at = null,
      consumed_at = null,
      last_sent_at = excluded.last_sent_at
  where public.pending_signups.last_sent_at <= now() - interval '60 seconds'
  returning true into v_issued;

  return case when coalesce(v_issued, false) then 'issued' else 'cooldown' end;
end
$function$;

create or replace function public.issue_password_reset_challenge_legacy(
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
  insert into public.pending_password_resets (
    email,
    code_hash,
    verified,
    expires_at,
    created_at,
    attempt_count,
    max_attempts,
    capability_hash,
    capability_expires_at,
    consumed_at,
    last_sent_at
  ) values (
    lower(trim(p_email)),
    p_code_hash,
    false,
    p_expires_at,
    now(),
    0,
    5,
    null,
    null,
    null,
    now()
  )
  on conflict (email) do update
  set code_hash = excluded.code_hash,
      verified = false,
      expires_at = excluded.expires_at,
      created_at = excluded.created_at,
      attempt_count = 0,
      max_attempts = 5,
      capability_hash = null,
      capability_expires_at = null,
      consumed_at = null,
      last_sent_at = excluded.last_sent_at
  where public.pending_password_resets.last_sent_at <= now() - interval '60 seconds'
  returning true into v_issued;

  return case when coalesce(v_issued, false) then 'issued' else 'cooldown' end;
end
$function$;

create or replace function public.verify_signup_challenge_legacy(
  p_email text,
  p_code_hash text
)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_row public.pending_signups%rowtype;
begin
  select * into v_row
  from public.pending_signups
  where email = lower(trim(p_email))
  for update;

  if not found then
    return 'missing';
  end if;
  if v_row.consumed_at is not null then
    return 'invalid';
  end if;
  if v_row.attempt_count >= v_row.max_attempts then
    return 'locked';
  end if;
  if v_row.expires_at <= now() then
    return 'expired';
  end if;
  if v_row.verified then
    return 'ok';
  end if;
  if v_row.code_hash <> p_code_hash then
    update public.pending_signups
    set attempt_count = attempt_count + 1
    where email = v_row.email;
    return case
      when v_row.attempt_count + 1 >= v_row.max_attempts then 'locked'
      else 'invalid'
    end;
  end if;

  update public.pending_signups
  set verified = true
  where email = v_row.email;
  return 'ok';
end
$function$;

create or replace function public.verify_password_reset_challenge_legacy(
  p_email text,
  p_code_hash text
)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_row public.pending_password_resets%rowtype;
begin
  select * into v_row
  from public.pending_password_resets
  where email = lower(trim(p_email))
  for update;

  if not found then
    return 'missing';
  end if;
  if v_row.consumed_at is not null then
    return 'invalid';
  end if;
  if v_row.attempt_count >= v_row.max_attempts then
    return 'locked';
  end if;
  if v_row.expires_at <= now() then
    return 'expired';
  end if;
  if v_row.verified then
    return 'ok';
  end if;
  if v_row.code_hash <> p_code_hash then
    update public.pending_password_resets
    set attempt_count = attempt_count + 1
    where email = v_row.email;
    return case
      when v_row.attempt_count + 1 >= v_row.max_attempts then 'locked'
      else 'invalid'
    end;
  end if;

  update public.pending_password_resets
  set verified = true
  where email = v_row.email;
  return 'ok';
end
$function$;

create or replace function public.consume_signup_verification_legacy(p_email text)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_row public.pending_signups%rowtype;
begin
  select * into v_row
  from public.pending_signups
  where email = lower(trim(p_email))
  for update;

  if not found or not v_row.verified or v_row.consumed_at is not null then
    return 'invalid';
  end if;
  if v_row.expires_at <= now() then
    return 'expired';
  end if;

  update public.pending_signups
  set verified = false,
      consumed_at = now()
  where email = v_row.email;
  return 'ok';
end
$function$;

create or replace function public.consume_password_reset_verification_legacy(
  p_email text
)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_row public.pending_password_resets%rowtype;
begin
  select * into v_row
  from public.pending_password_resets
  where email = lower(trim(p_email))
  for update;

  if not found or not v_row.verified or v_row.consumed_at is not null then
    return 'invalid';
  end if;
  if v_row.expires_at <= now() then
    return 'expired';
  end if;

  update public.pending_password_resets
  set verified = false,
      consumed_at = now()
  where email = v_row.email;
  return 'ok';
end
$function$;

revoke all on function public.issue_signup_challenge_legacy(text, text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.issue_password_reset_challenge_legacy(text, text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.verify_signup_challenge_legacy(text, text)
  from public, anon, authenticated;
revoke all on function public.verify_password_reset_challenge_legacy(text, text)
  from public, anon, authenticated;
revoke all on function public.consume_signup_verification_legacy(text)
  from public, anon, authenticated;
revoke all on function public.consume_password_reset_verification_legacy(text)
  from public, anon, authenticated;

grant execute on function public.issue_signup_challenge_legacy(text, text, timestamptz)
  to service_role;
grant execute on function public.issue_password_reset_challenge_legacy(text, text, timestamptz)
  to service_role;
grant execute on function public.verify_signup_challenge_legacy(text, text)
  to service_role;
grant execute on function public.verify_password_reset_challenge_legacy(text, text)
  to service_role;
grant execute on function public.consume_signup_verification_legacy(text)
  to service_role;
grant execute on function public.consume_password_reset_verification_legacy(text)
  to service_role;

comment on table public.pending_signups is
  'TEMPORARY LEGACY COMPATIBILITY — remove after minimum supported app version advances.';
comment on table public.pending_password_resets is
  'TEMPORARY LEGACY COMPATIBILITY — remove after minimum supported app version advances.';
