-- Hide test clubs and their content from users who are not test-enabled.
-- `tes` is intentionally nullable: only an explicit TRUE grants test access.

alter table public.profiles
  add column if not exists tes boolean;

alter table public.clubs
  add column if not exists tes boolean;

create schema if not exists private;

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
        club.tes is not true
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

revoke all on function private.can_view_club(uuid) from public;
grant usage on schema private to anon, authenticated;
grant execute on function private.can_view_club(uuid) to anon, authenticated;

drop policy if exists "Anyone can read active clubs" on public.clubs;
create policy "Test-visible active clubs are readable"
  on public.clubs
  for select
  to anon, authenticated
  using (
    is_active is true
    and (select private.can_view_club(id))
  );

drop policy if exists "Anyone can read club posts" on public.club_posts;
create policy "Test-visible club posts are readable"
  on public.club_posts
  for select
  to anon, authenticated
  using ((select private.can_view_club(club_id)));

drop policy if exists "Anyone can read events" on public.events;
drop policy if exists "Anyone can read public events" on public.events;
create policy "Test-visible events are readable"
  on public.events
  for select
  to anon, authenticated
  using ((select private.can_view_club(club_id)));

