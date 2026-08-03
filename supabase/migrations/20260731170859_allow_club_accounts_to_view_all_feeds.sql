-- Club accounts have no follow model. Treat every authenticated club
-- account as implicitly following every club for public feed visibility, while
-- preserving test-club isolation for ordinary student accounts.

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
        or exists (
          select 1
          from public.club_auth_accounts as club_account
          where club_account.auth_user_id = (select auth.uid())
        )
        or club.tes is not true
        or exists (
          select 1
          from public.profiles as profile
          where profile.id = (select auth.uid())
            and profile.tes is true
        )
      )
  );
$$;

revoke all on function private.can_view_club(uuid) from public;
grant usage on schema private to anon, authenticated;
grant execute on function private.can_view_club(uuid) to anon, authenticated;
