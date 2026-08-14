begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

select ok(
  has_column_privilege('authenticated', 'public.profiles', 'email', 'SELECT'),
  'authenticated users can select profile email'
);
select ok(
  not has_table_privilege('authenticated', 'public.profiles', 'SELECT'),
  'authenticated profile access remains an explicit column grant'
);
select ok(
  has_column_privilege('authenticated', 'public.profiles', 'full_name', 'SELECT'),
  'authenticated users retain the other profile field grants'
);
select ok(
  not has_column_privilege('anon', 'public.profiles', 'email', 'SELECT'),
  'anonymous users cannot select profile email'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'profiles RLS remains enabled'
);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password)
values
  ('00000000-0000-0000-0000-000000000000', '60000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'owner@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '60000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'other@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '60000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'admin@example.com', '');
insert into public.profiles (id, email, full_name)
values
  ('60000000-0000-0000-0000-000000000001', 'owner@ku.edu.tr', 'Owner'),
  ('60000000-0000-0000-0000-000000000002', 'other@ku.edu.tr', 'Other')
on conflict (id) do update set email = excluded.email, full_name = excluded.full_name;
insert into public.app_admins (singleton, auth_user_id, email)
values (true, '60000000-0000-0000-0000-000000000003', 'admin@example.com')
on conflict (singleton) do update
set auth_user_id = excluded.auth_user_id, email = excluded.email;

set local role authenticated;
select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000001', true);
select is(
  (select email from public.profiles
   where id = '60000000-0000-0000-0000-000000000001'),
  'owner@ku.edu.tr',
  'an authenticated user can select their own email'
);
select is(
  (select email from public.profiles
   where id = '60000000-0000-0000-0000-000000000002'),
  'other@ku.edu.tr',
  'an authenticated user can select an RLS-visible peer email'
);
select is(
  (select count(*) from public.profiles
   where id = '60000000-0000-0000-0000-000000000002'),
  1::bigint,
  'the peer row is visible because existing profiles RLS permits it'
);
select is(
  public.get_private_profile_email('60000000-0000-0000-0000-000000000001'),
  'owner@ku.edu.tr',
  'the compatibility private RPC still returns the owner email'
);
select is(
  public.get_private_profile_email('60000000-0000-0000-0000-000000000002'),
  null,
  'the compatibility private RPC keeps its narrower ordinary-user behavior'
);

select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000003', true);
select is(
  public.get_private_profile_email('60000000-0000-0000-0000-000000000002'),
  'other@ku.edu.tr',
  'the compatibility private RPC still supports platform administration'
);

set local role anon;
select throws_ok(
  $$select email from public.profiles
    where id = '60000000-0000-0000-0000-000000000002'$$,
  '42501',
  'permission denied for table profiles',
  'anonymous callers cannot project profile email'
);

select * from finish();
rollback;
