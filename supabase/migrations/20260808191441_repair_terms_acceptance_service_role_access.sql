-- The signup Edge Function uses service_role to persist the acceptance before
-- exposing the new account. Keep this backend grant limited to the columns and
-- operation that complete-signup actually needs.

grant select on table public.terms_acceptances to service_role;
grant insert (user_id, terms_version)
  on table public.terms_acceptances to service_role;
