-- F1 v2 correctly removes PUBLIC access from the private schema, but the
-- historical migration also removed USAGE from authenticated/anon after
-- earlier RLS helpers had granted it. Restore schema traversal only; function
-- EXECUTE privileges remain individually allow-listed by their migrations.
grant usage on schema private to anon, authenticated, service_role;

-- 011 removed overlapping interest policies but did not recreate the active
-- reference-data read policy. Profile v2 validates IDs through caller RLS, so
-- the omission made every non-empty interest update fail on a clean schema.
drop policy if exists "Authenticated users can read interests"
  on public.interests;
create policy "Authenticated users can read interests"
  on public.interests
  for select
  to authenticated
  using (is_active is true);

-- The legacy comment migration created RLS policies without the Data API
-- table grant. Feed v2 is SECURITY INVOKER and therefore needs the same read
-- privilege as the released authenticated comment surface.
grant select on table public.post_comments to authenticated;

-- Chat v2 amortizes journal cleanup with this private sequence from an
-- authenticated SECURITY INVOKER RPC. The private schema remains closed and
-- the sequence contains no user data.
grant usage, select, update on sequence private.chat_v2_cleanup_clock
  to authenticated;

-- Interest IDs are part of authenticated profile discovery and profile edit
-- hydration. 011 removed the duplicate read policies without restoring one.
drop policy if exists "Authenticated users can read student interests"
  on public.student_interests;
create policy "Authenticated users can read student interests"
  on public.student_interests
  for select
  to authenticated
  using (true);

-- This RPC advances an amortized cleanup clock and may delete expired journal
-- rows, so declaring it STABLE was incorrect and is rejected by db lint.
alter function public.get_messages_since_v2(text, bigint, integer) volatile;

-- Remove the historical project URL/key from the legacy notification trigger.
-- Existing projects keep delivery semantics after the two named Vault secrets
-- are configured; fresh/local projects remain deterministic without secrets.
create or replace function private.dispatch_notification_push()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
  v_anon_key text;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'notification_push_url';
  select decrypted_secret into v_anon_key
  from vault.decrypted_secrets where name = 'notification_push_anon_key';
  if v_url is null or v_anon_key is null then return new; end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_anon_key
    ),
    body := jsonb_build_object(
      'type', 'INSERT', 'table', 'notifications', 'schema', 'public',
      'record', jsonb_build_object('id', new.id)
    ),
    timeout_milliseconds := 5000
  );
  return new;
end;
$$;
revoke all on function private.dispatch_notification_push()
  from public, anon, authenticated;

-- Replace the profile RPC without RETURNING the private email column. Column
-- privileges intentionally hide profiles.email from general directory reads;
-- the caller's verified JWT supplies its own email in the response.
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
