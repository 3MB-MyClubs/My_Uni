-- Give the singleton platform administrator complete content visibility and
-- deletion authority. Ordinary club accounts remain scoped to their own club.

create or replace function private.can_view_club(target_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.clubs as club
    where club.id = target_club_id
      and (
        exists (
          select 1
          from public.app_admins as app_admin
          where app_admin.auth_user_id = (select auth.uid())
        )
        or club.tes is not true
        or exists (
          select 1
          from public.profiles as profile
          where profile.id = (select auth.uid())
            and profile.tes is true
        )
        or exists (
          select 1
          from public.club_auth_accounts as account
          where account.auth_user_id = (select auth.uid())
            and account.club_id = target_club_id
        )
      )
  );
$$;

-- Platform moderation includes inactive clubs; everyone else keeps the
-- existing active/test-visibility rules.
drop policy if exists "Test-visible active clubs are readable"
  on public.clubs;
create policy "Test-visible active clubs are readable"
  on public.clubs
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.app_admins as app_admin
      where app_admin.auth_user_id = (select auth.uid())
    )
    or (
      is_active is true
      and (select private.can_view_club(id))
    )
  );

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
