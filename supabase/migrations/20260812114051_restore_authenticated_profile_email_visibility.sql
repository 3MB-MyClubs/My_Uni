-- Product policy: an authenticated caller may select email for every profile
-- row that existing RLS permits. Anonymous access remains unchanged/denied.

grant select (
  id,
  full_name,
  email,
  role,
  avatar_url,
  bio,
  major_id,
  academic_year_id,
  created_at,
  updated_at
) on table public.profiles to authenticated;

revoke select (email) on table public.profiles from anon;

-- get_private_profile_email(...) and get_private_profile_emails(...) remain in
-- place because already-built clients and admin flows may still call them.
