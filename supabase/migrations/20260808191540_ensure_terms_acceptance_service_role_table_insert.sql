-- PostgREST checks table-level INSERT access for the service-role client used
-- by the signup Edge Function. Keep SELECT separate and do not grant UPDATE or
-- DELETE to this role here.

grant insert on table public.terms_acceptances to service_role;
