-- The profile test flag is an access-control attribute. Keep it managed by
-- trusted database roles instead of allowing users to enable it themselves.

revoke update on table public.profiles from authenticated;

grant update (
  full_name,
  avatar_url,
  bio,
  major_id,
  academic_year_id,
  updated_at
) on table public.profiles to authenticated;

