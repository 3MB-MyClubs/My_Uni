-- F1: Replace reusable "verified" booleans with short-lived, single-use
-- capabilities. All state transitions are serialized in the database so two
-- concurrent completion requests cannot consume the same verification.

create table if not exists public.pending_signups (
  email text primary key,
  code_hash text not null,
  verified boolean not null default false,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.pending_password_resets (
  email text primary key,
  code_hash text not null,
  verified boolean not null default false,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

alter table public.pending_signups
  add column if not exists attempt_count smallint not null default 0,
  add column if not exists max_attempts smallint not null default 5,
  add column if not exists capability_hash text,
  add column if not exists capability_expires_at timestamptz,
  add column if not exists consumed_at timestamptz,
  add column if not exists last_sent_at timestamptz not null default now();

alter table public.pending_password_resets
  add column if not exists attempt_count smallint not null default 0,
  add column if not exists max_attempts smallint not null default 5,
  add column if not exists capability_hash text,
  add column if not exists capability_expires_at timestamptz,
  add column if not exists consumed_at timestamptz,
  add column if not exists last_sent_at timestamptz not null default now();

-- Invalidate every legacy verification immediately. During a rolling deploy an
-- old completion function must fail closed instead of accepting the old flag.
update public.pending_signups set verified = false where verified;
update public.pending_password_resets set verified = false where verified;

do $migration$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.pending_signups'::regclass
      and conname = 'pending_signups_verified_is_legacy'
  ) then
    alter table public.pending_signups
      add constraint pending_signups_verified_is_legacy check (not verified);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.pending_password_resets'::regclass
      and conname = 'pending_password_resets_verified_is_legacy'
  ) then
    alter table public.pending_password_resets
      add constraint pending_password_resets_verified_is_legacy check (not verified);
  end if;
end
$migration$;

alter table public.pending_signups enable row level security;
alter table public.pending_password_resets enable row level security;

revoke all on table public.pending_signups from public, anon, authenticated;
revoke all on table public.pending_password_resets from public, anon, authenticated;
grant select, insert, update, delete on table public.pending_signups to service_role;
grant select, insert, update, delete on table public.pending_password_resets to service_role;

create or replace function public.issue_signup_challenge(
  p_email text,
  p_code_hash text,
  p_expires_at timestamptz
)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_email text := lower(trim(p_email));
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
    v_email,
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

create or replace function public.issue_password_reset_challenge(
  p_email text,
  p_code_hash text,
  p_expires_at timestamptz
)
returns text
language plpgsql
set search_path = ''
as $function$
declare
  v_email text := lower(trim(p_email));
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
    v_email,
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

create or replace function public.verify_signup_challenge(
  p_email text,
  p_code_hash text,
  p_capability_hash text
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
    return 'invalid';
  end if;
  if v_row.consumed_at is not null or v_row.capability_hash is not null then
    return 'invalid';
  end if;
  if v_row.attempt_count >= v_row.max_attempts then
    return 'locked';
  end if;
  if v_row.expires_at <= now() then
    return 'expired';
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
  set code_hash = 'verified:' || p_capability_hash,
      verified = false,
      capability_hash = p_capability_hash,
      capability_expires_at = least(v_row.expires_at, now() + interval '5 minutes')
  where email = v_row.email;
  return 'ok';
end
$function$;

create or replace function public.verify_password_reset_challenge(
  p_email text,
  p_code_hash text,
  p_capability_hash text
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
    return 'invalid';
  end if;
  if v_row.consumed_at is not null or v_row.capability_hash is not null then
    return 'invalid';
  end if;
  if v_row.attempt_count >= v_row.max_attempts then
    return 'locked';
  end if;
  if v_row.expires_at <= now() then
    return 'expired';
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
  set code_hash = 'verified:' || p_capability_hash,
      verified = false,
      capability_hash = p_capability_hash,
      capability_expires_at = least(v_row.expires_at, now() + interval '5 minutes')
  where email = v_row.email;
  return 'ok';
end
$function$;

create or replace function public.consume_signup_capability(
  p_email text,
  p_capability_hash text
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

  if not found or v_row.consumed_at is not null
    or v_row.capability_hash is null
    or v_row.capability_hash <> p_capability_hash then
    return 'invalid';
  end if;
  if v_row.capability_expires_at is null or v_row.capability_expires_at <= now() then
    return 'expired';
  end if;

  update public.pending_signups
  set consumed_at = now(), capability_hash = null, capability_expires_at = null
  where email = v_row.email;
  return 'ok';
end
$function$;

create or replace function public.consume_password_reset_capability(
  p_email text,
  p_capability_hash text
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

  if not found or v_row.consumed_at is not null
    or v_row.capability_hash is null
    or v_row.capability_hash <> p_capability_hash then
    return 'invalid';
  end if;
  if v_row.capability_expires_at is null or v_row.capability_expires_at <= now() then
    return 'expired';
  end if;

  update public.pending_password_resets
  set consumed_at = now(), capability_hash = null, capability_expires_at = null
  where email = v_row.email;
  return 'ok';
end
$function$;

-- Password changes already revoke sessions in Supabase Auth. This explicit,
-- user-id-scoped function also removes every refresh session before the admin
-- password update, without requiring the old user JWT.
create or replace function public.revoke_user_sessions(p_user_id uuid)
returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_deleted bigint;
begin
  delete from auth.sessions where user_id = p_user_id;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end
$function$;

revoke all on function public.issue_signup_challenge(text, text, timestamptz) from public, anon, authenticated;
revoke all on function public.issue_password_reset_challenge(text, text, timestamptz) from public, anon, authenticated;
revoke all on function public.verify_signup_challenge(text, text, text) from public, anon, authenticated;
revoke all on function public.verify_password_reset_challenge(text, text, text) from public, anon, authenticated;
revoke all on function public.consume_signup_capability(text, text) from public, anon, authenticated;
revoke all on function public.consume_password_reset_capability(text, text) from public, anon, authenticated;
revoke all on function public.revoke_user_sessions(uuid) from public, anon, authenticated;

grant execute on function public.issue_signup_challenge(text, text, timestamptz) to service_role;
grant execute on function public.issue_password_reset_challenge(text, text, timestamptz) to service_role;
grant execute on function public.verify_signup_challenge(text, text, text) to service_role;
grant execute on function public.verify_password_reset_challenge(text, text, text) to service_role;
grant execute on function public.consume_signup_capability(text, text) to service_role;
grant execute on function public.consume_password_reset_capability(text, text) to service_role;
grant execute on function public.revoke_user_sessions(uuid) to service_role;
