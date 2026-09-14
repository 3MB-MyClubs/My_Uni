-- The transactional post-delete RPC originally reused the club-management
-- predicate. That predicate intentionally excludes the platform moderator,
-- so it overrode the existing RLS policy that permits the moderator to delete
-- any club post. Keep authoring permissions unchanged and add a deletion-only
-- capability for the RPC and its durable Storage cleanup.

create or replace function private.can_delete_club_content(target_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select private.can_manage_club_content(target_club_id))
    or exists (
      select 1
      from public.app_admins as app_admin
      where app_admin.auth_user_id = (select auth.uid())
    );
$$;

revoke all on function private.can_delete_club_content(uuid)
  from public, anon, authenticated;
grant execute on function private.can_delete_club_content(uuid)
  to authenticated;

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
  if not (select private.can_delete_club_content(p_club_id)) then
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
    v_actor, 'pending', 0,
    now() + greatest(coalesce(p_delay, interval '15 minutes'), interval '0'),
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

create or replace function public.delete_club_post_transactional_v2(
  p_post_id uuid,
  p_club_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_post public.club_posts%rowtype;
  v_cleanup_id uuid;
begin
  if not (select private.can_delete_club_content(p_club_id)) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  perform private.enforce_authenticated_rate_limit('post_delete:actor', null);
  perform private.enforce_authenticated_rate_limit(
    'post_delete:resource',
    p_club_id::text
  );
  -- DELETE ... RETURNING obtains the row lock and old media path in one
  -- statement. Unlike SELECT ... FOR UPDATE, it does not require an UPDATE
  -- policy in addition to the platform moderator's DELETE policy.
  delete from public.club_posts
  where id = p_post_id
    and club_id = p_club_id
  returning * into v_post;
  if not found then
    return jsonb_build_object('deleted', true, 'already_deleted', true);
  end if;
  if v_post.image_path is not null then
    v_cleanup_id := private.enqueue_storage_cleanup_v2(
      'post-images',
      v_post.image_path,
      'entity_deleted',
      'post',
      p_post_id,
      p_club_id,
      interval '0'
    );
  end if;
  return jsonb_build_object(
    'deleted', true,
    'cleanup_id', v_cleanup_id,
    'cleanup_path', v_post.image_path
  );
end;
$$;

create or replace function public.complete_storage_cleanup_v2(p_cleanup_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.storage_cleanup_queue_v2%rowtype;
begin
  select * into v_item
  from public.storage_cleanup_queue_v2
  where id = p_cleanup_id
  for update;
  if not found then
    return false;
  end if;
  if auth.uid() is null
     or not (select private.can_delete_club_content(v_item.club_id)) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  update public.storage_cleanup_queue_v2
  set status = 'completed',
      completed_at = now(),
      updated_at = now(),
      lease_token = null,
      lease_owner = null,
      lease_expires_at = null
  where id = p_cleanup_id;
  return true;
end;
$$;

comment on function private.can_delete_club_content(uuid) is
  'Deletion-only authorization for club managers and the singleton platform administrator.';
