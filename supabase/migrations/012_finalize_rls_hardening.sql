-- Remove the final client-callable SECURITY DEFINER helper by expressing the
-- same club ownership rule directly in the event policies.
drop policy if exists "Club auth accounts can create their club events"
  on public.events;
create policy "Club auth accounts can create their club events"
  on public.events
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = events.club_id
    )
  );

drop policy if exists "Club auth accounts can update their club events"
  on public.events;
create policy "Club auth accounts can update their club events"
  on public.events
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = events.club_id
    )
  )
  with check (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = events.club_id
    )
  );

drop policy if exists "Club auth accounts can delete their club events"
  on public.events;
create policy "Club auth accounts can delete their club events"
  on public.events
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.club_auth_accounts as account
      where account.auth_user_id = (select auth.uid())
        and account.club_id = events.club_id
    )
  );

revoke execute on function public.is_club_auth_account_for(uuid)
  from public, anon, authenticated;

-- Categories are public reference data used by the pre-auth discovery/signup
-- UI. Only active rows are exposed.
drop policy if exists "Active club categories are readable"
  on public.club_categories;
create policy "Active club categories are readable"
  on public.club_categories
  for select
  to anon, authenticated
  using (is_active is true);

-- Comments are readable to signed-in community members, while writes remain
-- tied to the authenticated profile id supplied by the app.
drop policy if exists "post_comments_select" on public.post_comments;
create policy "post_comments_select"
  on public.post_comments
  for select
  to authenticated
  using (true);

drop policy if exists "post_comments_insert" on public.post_comments;
create policy "post_comments_insert"
  on public.post_comments
  for insert
  to authenticated
  with check (profile_id = (select auth.uid()));

drop policy if exists "post_comments_delete" on public.post_comments;
create policy "post_comments_delete"
  on public.post_comments
  for delete
  to authenticated
  using (profile_id = (select auth.uid()));
