-- Restore database-enforced moderator deletion for the singleton platform
-- administrator. Club accounts remain restricted to their own content by the
-- existing policies.

drop policy if exists "Platform admin can delete any club post"
  on public.club_posts;

create policy "Platform admin can delete any club post"
  on public.club_posts
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.app_admins as app_admin
      where app_admin.auth_user_id = (select auth.uid())
    )
  );

drop policy if exists "Platform admin can delete any event"
  on public.events;

create policy "Platform admin can delete any event"
  on public.events
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.app_admins as app_admin
      where app_admin.auth_user_id = (select auth.uid())
    )
  );

drop policy if exists "Platform admin can delete any post image"
  on storage.objects;

create policy "Platform admin can delete any post image"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'post-images'
    and exists (
      select 1
      from public.app_admins as app_admin
      where app_admin.auth_user_id = (select auth.uid())
    )
  );

drop policy if exists "Platform admin can delete any event image"
  on storage.objects;

create policy "Platform admin can delete any event image"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'event-images'
    and exists (
      select 1
      from public.app_admins as app_admin
      where app_admin.auth_user_id = (select auth.uid())
    )
  );
