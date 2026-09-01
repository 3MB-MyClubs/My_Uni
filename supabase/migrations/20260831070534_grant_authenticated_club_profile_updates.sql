-- Club profile writes already have an ownership-scoped UPDATE RLS policy, but
-- authenticated clients were never granted UPDATE at the table/column level.
-- Grant only the fields the club profile editor can mutate; RLS continues to
-- restrict each caller to the club linked through club_auth_accounts.
grant update (name, short_name, description, logo_url)
  on table public.clubs
  to authenticated;
