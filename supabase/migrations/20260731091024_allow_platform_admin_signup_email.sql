create or replace function public.restrict_signup_to_ku(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  email text;
begin
  email := lower(event->'user'->>'email');

  if email is null
     or (
       email not like '%@ku.edu.tr'
       and email <> 'dev3mb@gmail.com'
     ) then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'Only @ku.edu.tr emails are allowed.',
        'http_code', 403
      )
    );
  end if;

  return '{}'::jsonb;
end;
$$;
