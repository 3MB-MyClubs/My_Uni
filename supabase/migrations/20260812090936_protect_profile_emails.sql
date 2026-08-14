-- F4: profiles remain discoverable, but account email is no longer part of
-- the shared authenticated directory surface. RLS filters rows; column grants
-- independently restrict which fields a permitted row may expose.

revoke select on table public.profiles from public, anon, authenticated;

grant select (
  id,
  full_name,
  role,
  avatar_url,
  bio,
  major_id,
  academic_year_id,
  created_at,
  updated_at
) on table public.profiles to authenticated;

-- An explicit, audited path for the account owner and platform administrator.
-- Public directory/member queries intentionally do not call this function.
create or replace function public.get_private_profile_email(p_profile_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $function$
  select profile.email
  from public.profiles as profile
  where profile.id = p_profile_id
    and (
      profile.id = (select auth.uid())
      or exists (
        select 1
        from public.app_admins as app_admin
        where app_admin.auth_user_id = (select auth.uid())
      )
    );
$function$;

revoke all on function public.get_private_profile_email(uuid)
  from public, anon;
grant execute on function public.get_private_profile_email(uuid)
  to authenticated;

create or replace function public.get_private_profile_emails(p_profile_ids uuid[])
returns table (profile_id uuid, email text)
language sql
stable
security definer
set search_path = ''
as $function$
  select profile.id, profile.email
  from public.profiles as profile
  where profile.id = any(coalesce(p_profile_ids, array[]::uuid[]))
    and cardinality(coalesce(p_profile_ids, array[]::uuid[])) <= 200
    and (
      profile.id = (select auth.uid())
      or exists (
        select 1
        from public.app_admins as app_admin
        where app_admin.auth_user_id = (select auth.uid())
      )
    );
$function$;

revoke all on function public.get_private_profile_emails(uuid[])
  from public, anon;
grant execute on function public.get_private_profile_emails(uuid[])
  to authenticated;
