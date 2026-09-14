-- ClubUp is a moderation identity, not a social profile. Remove any legacy
-- outbound follows and prevent the singleton platform admin from creating new
-- club or student follow relationships. Student and club-account policies keep
-- their existing behavior.

delete from public.profile_follows as follow
using public.app_admins as app_admin
where follow.follower_id = app_admin.auth_user_id;

delete from public.club_followers as follow
using public.app_admins as app_admin
where follow.profile_id = app_admin.auth_user_id;

drop policy if exists "Users can follow clubs" on public.club_followers;
create policy "Users can follow clubs"
  on public.club_followers
  for insert
  to authenticated
  with check (
    (select auth.uid()) = profile_id
    and role = 'member'
    and not exists (
      select 1
      from public.app_admins as app_admin
      where app_admin.auth_user_id = (select auth.uid())
    )
  );

drop policy if exists "Users can follow people" on public.profile_follows;
create policy "Users can follow people"
  on public.profile_follows
  for insert
  to authenticated
  with check (
    (select auth.uid()) = follower_id
    and not exists (
      select 1
      from public.app_admins as app_admin
      where app_admin.auth_user_id = (select auth.uid())
    )
  );
