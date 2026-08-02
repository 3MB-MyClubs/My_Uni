-- Harden public Data API/storage access and remove avoidable RLS work.
-- The statements are idempotent so this file can also be run from the
-- Supabase SQL editor in environments that predate the local migration set.

-- Aggregate views must obey the caller's RLS policies instead of executing
-- with the view owner's privileges.
alter view public.club_member_counts set (security_invoker = true);
alter view public.event_rsvp_counts set (security_invoker = true);
alter view public.post_like_counts set (security_invoker = true);

-- Auth hooks should not inherit a caller-controlled search_path, and an event
-- trigger helper is not a client-facing RPC endpoint.
alter function public.restrict_signup_to_ku(jsonb) set search_path = '';
revoke execute on function public.rls_auto_enable()
  from public, anon, authenticated;

-- Public bucket URLs are served without SELECT on storage.objects. Replace
-- broad listing policies with path-scoped authenticated maintenance access.
drop policy if exists "Anyone can view avatars" on storage.objects;
drop policy if exists "Club avatars are publicly readable" on storage.objects;
drop policy if exists "Event images are publicly readable" on storage.objects;
drop policy if exists "Post images are publicly readable" on storage.objects;

drop policy if exists "Users can list own avatar" on storage.objects;
create policy "Users can list own avatar"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Club admins can read own club avatars"
  on storage.objects;
create policy "Club admins can read own club avatars"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'club-avatars'
    and (storage.foldername(name))[1] = 'clubs'
    and exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2]
    )
  );

drop policy if exists "Club admins can read own post images"
  on storage.objects;
create policy "Club admins can read own post images"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = 'club_posts'
    and exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2]
    )
  );

drop policy if exists "Club admins can read own event images"
  on storage.objects;
create policy "Club admins can read own event images"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = 'events'
    and exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2]
    )
  );

-- Post/event object mutations used to be allowed for every authenticated
-- account. Restrict all three operations to the club encoded in the object
-- path. UPDATE remains for compatibility with older app versions that upsert.
drop policy if exists "Authenticated users can upload post images"
  on storage.objects;
drop policy if exists "Authenticated users can update post images"
  on storage.objects;
drop policy if exists "Authenticated users can delete post images"
  on storage.objects;

create policy "Club admins can upload own post images"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = 'club_posts'
    and exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2]
    )
  );

create policy "Club admins can update own post images"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = 'club_posts'
    and exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2]
    )
  )
  with check (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = 'club_posts'
    and exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2]
    )
  );

create policy "Club admins can delete own post images"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = 'club_posts'
    and exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2]
    )
  );

drop policy if exists "Authenticated users can upload event images"
  on storage.objects;
drop policy if exists "Authenticated users can update event images"
  on storage.objects;
drop policy if exists "Authenticated users can delete event images"
  on storage.objects;

create policy "Club admins can upload own event images"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = 'events'
    and exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2]
    )
  );

create policy "Club admins can update own event images"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = 'events'
    and exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2]
    )
  )
  with check (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = 'events'
    and exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2]
    )
  );

create policy "Club admins can delete own event images"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = 'events'
    and exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2]
    )
  );

-- Consolidate identical permissive policies. Besides being easier to audit,
-- Postgres no longer evaluates several equivalent expressions for each row.
drop policy if exists "Club followers are publicly readable"
  on public.club_followers;
drop policy if exists "Authenticated users can read club followers"
  on public.club_followers;
drop policy if exists "Anyone can read club followers"
  on public.club_followers;
create policy "Authenticated users can read club followers"
  on public.club_followers
  for select
  to authenticated
  using (true);

drop policy if exists "Club admins can create posts for their club"
  on public.club_posts;

drop policy if exists "Authenticated users can read interests"
  on public.interests;
drop policy if exists "Users can read interests" on public.interests;

drop policy if exists "Authenticated users can read post likes"
  on public.post_likes;
drop policy if exists "Anyone can read post likes" on public.post_likes;
create policy "Authenticated users can read post likes"
  on public.post_likes
  for select
  to authenticated
  using (true);

drop policy if exists "Profiles are publicly readable" on public.profiles;
drop policy if exists "Users can read profiles" on public.profiles;
drop policy if exists "Anyone can read public profiles" on public.profiles;
drop policy if exists "Authenticated users can read profiles"
  on public.profiles;
create policy "Authenticated users can read profiles"
  on public.profiles
  for select
  to authenticated
  using (true);

drop policy if exists "Anyone can read post views" on public.post_views;
drop policy if exists "Post views are readable" on public.post_views;
drop policy if exists "Anyone can read post view counts"
  on public.post_views;
create policy "Authenticated users can read post views"
  on public.post_views
  for select
  to authenticated
  using (true);

drop policy if exists "Users can insert own post views"
  on public.post_views;
drop policy if exists "Users can record their own post views"
  on public.post_views;
drop policy if exists "Users can refresh their own post views"
  on public.post_views;
drop policy if exists "Users can update own post views"
  on public.post_views;

drop policy if exists "Users can read student interests"
  on public.student_interests;
drop policy if exists "Users can manage own interests"
  on public.student_interests;
drop policy if exists "Users can add own interests"
  on public.student_interests;
drop policy if exists "Users can remove own interests"
  on public.student_interests;

create policy "Users can add own interests"
  on public.student_interests
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update own interests"
  on public.student_interests
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can remove own interests"
  on public.student_interests
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- Cache auth.uid() once per statement instead of re-evaluating it for every
-- row in the app's hottest ownership policies.
drop policy if exists "Users can create own profile" on public.profiles;
create policy "Users can create own profile"
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "Users can follow clubs" on public.club_followers;
create policy "Users can follow clubs"
  on public.club_followers
  for insert
  to authenticated
  with check ((select auth.uid()) = profile_id);

drop policy if exists "Users can unfollow clubs" on public.club_followers;
create policy "Users can unfollow clubs"
  on public.club_followers
  for delete
  to authenticated
  using ((select auth.uid()) = profile_id);

drop policy if exists "Club admins can update follower board roles"
  on public.club_followers;
create policy "Club admins can update follower board roles"
  on public.club_followers
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = club_followers.club_id
    )
  )
  with check (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = club_followers.club_id
    )
  );

drop policy if exists "Users can like posts" on public.post_likes;
create policy "Users can like posts"
  on public.post_likes
  for insert
  to authenticated
  with check ((select auth.uid()) = profile_id);

drop policy if exists "Users can unlike posts" on public.post_likes;
create policy "Users can unlike posts"
  on public.post_likes
  for delete
  to authenticated
  using ((select auth.uid()) = profile_id);

drop policy if exists "Users can RSVP events" on public.event_rsvps;
create policy "Users can RSVP events"
  on public.event_rsvps
  for insert
  to authenticated
  with check ((select auth.uid()) = profile_id);

drop policy if exists "Users can cancel event RSVP" on public.event_rsvps;
create policy "Users can cancel event RSVP"
  on public.event_rsvps
  for delete
  to authenticated
  using ((select auth.uid()) = profile_id);

drop policy if exists "Club account can see itself"
  on public.club_auth_accounts;
create policy "Club account can see itself"
  on public.club_auth_accounts
  for select
  to authenticated
  using ((select auth.uid()) = auth_user_id);

drop policy if exists "Club auth accounts can create their club posts"
  on public.club_posts;
create policy "Club auth accounts can create their club posts"
  on public.club_posts
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = club_posts.club_id
    )
  );

drop policy if exists "Club auth accounts can update their club posts"
  on public.club_posts;
create policy "Club auth accounts can update their club posts"
  on public.club_posts
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = club_posts.club_id
    )
  )
  with check (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = club_posts.club_id
    )
  );

drop policy if exists "Club auth accounts can delete their club posts"
  on public.club_posts;
create policy "Club auth accounts can delete their club posts"
  on public.club_posts
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = club_posts.club_id
    )
  );

drop policy if exists "Authenticated users can insert their own post views"
  on public.post_views;
create policy "Authenticated users can insert their own post views"
  on public.post_views
  for insert
  to authenticated
  with check (profile_id = (select auth.uid()));

drop policy if exists "Authenticated users can update their own post views"
  on public.post_views;
create policy "Authenticated users can update their own post views"
  on public.post_views
  for update
  to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

drop policy if exists "Authenticated users can delete their own post views"
  on public.post_views;
create policy "Authenticated users can delete their own post views"
  on public.post_views
  for delete
  to authenticated
  using (profile_id = (select auth.uid()));

drop policy if exists "Users can follow people" on public.profile_follows;
create policy "Users can follow people"
  on public.profile_follows
  for insert
  to authenticated
  with check ((select auth.uid()) = follower_id);

drop policy if exists "Users can unfollow people" on public.profile_follows;
create policy "Users can unfollow people"
  on public.profile_follows
  for delete
  to authenticated
  using ((select auth.uid()) = follower_id);

drop policy if exists "Users can manage own double majors"
  on public.profile_double_majors;
create policy "Users can manage own double majors"
  on public.profile_double_majors
  for all
  to authenticated
  using ((select auth.uid()) = profile_id)
  with check ((select auth.uid()) = profile_id);

drop policy if exists "Users can manage own minors"
  on public.profile_minors;
create policy "Users can manage own minors"
  on public.profile_minors
  for all
  to authenticated
  using ((select auth.uid()) = profile_id)
  with check ((select auth.uid()) = profile_id);

drop policy if exists "Club admins can update own club profile"
  on public.clubs;
create policy "Club admins can update own club profile"
  on public.clubs
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = clubs.id
    )
  )
  with check (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = clubs.id
    )
  );

drop policy if exists "moderation_reports_insert_own"
  on public.moderation_reports;
create policy "moderation_reports_insert_own"
  on public.moderation_reports
  for insert
  to authenticated
  with check (reporter_id = (select auth.uid()));

drop policy if exists "user_blocks_select_own" on public.user_blocks;
create policy "user_blocks_select_own"
  on public.user_blocks
  for select
  to authenticated
  using (blocker_id = (select auth.uid()));

drop policy if exists "user_blocks_insert_own" on public.user_blocks;
create policy "user_blocks_insert_own"
  on public.user_blocks
  for insert
  to authenticated
  with check (blocker_id = (select auth.uid()));

drop policy if exists "user_blocks_update_own" on public.user_blocks;
create policy "user_blocks_update_own"
  on public.user_blocks
  for update
  to authenticated
  using (blocker_id = (select auth.uid()))
  with check (blocker_id = (select auth.uid()));

drop policy if exists "user_blocks_delete_own" on public.user_blocks;
create policy "user_blocks_delete_own"
  on public.user_blocks
  for delete
  to authenticated
  using (blocker_id = (select auth.uid()));

-- Cover foreign keys used by joins/cascades and remove one index duplicated by
-- the student_interests primary key.
create index if not exists club_auth_accounts_club_id_idx
  on public.club_auth_accounts (club_id);
create index if not exists moderation_reports_reported_user_id_idx
  on public.moderation_reports (reported_user_id);
create index if not exists moderation_reports_reporter_id_idx
  on public.moderation_reports (reporter_id);
create index if not exists moderation_reports_reviewed_by_idx
  on public.moderation_reports (reviewed_by);
create index if not exists post_comments_profile_id_idx
  on public.post_comments (profile_id);
create index if not exists post_views_profile_id_idx
  on public.post_views (profile_id);
create index if not exists profile_double_majors_major_id_idx
  on public.profile_double_majors (major_id);
create index if not exists profile_minors_major_id_idx
  on public.profile_minors (major_id);
create index if not exists profiles_academic_year_id_idx
  on public.profiles (academic_year_id);
create index if not exists profiles_major_id_idx
  on public.profiles (major_id);
create index if not exists student_interests_interest_id_idx
  on public.student_interests (interest_id);

alter table public.student_interests
  drop constraint if exists student_interests_user_interest_unique;
