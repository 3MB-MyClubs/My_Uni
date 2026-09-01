begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

-- Supabase's default privileges grant broad table access to anon and
-- authenticated; the ownership-scoped RLS policy is what actually restricts
-- club profile writes. Assert the grant the editor relies on plus the RLS
-- guard, then prove the behavior with a linked and an unlinked account.
select ok(
  has_column_privilege(
    'authenticated',
    'public.clubs',
    'short_name',
    'UPDATE'
  ),
  'authenticated clients can request a club initials update'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.clubs'::regclass
  ),
  'row level security guards club updates'
);
select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clubs'
      and cmd = 'UPDATE'
      and policyname = 'Club admins can update own club profile'
  ),
  'club updates are scoped to the owning account by policy'
);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '91000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'club-owner@ku.edu.tr',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '91000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'other-club@ku.edu.tr',
    ''
  );
insert into public.clubs (id, name, short_name)
values (
  '92000000-0000-0000-0000-000000000001',
  'Industrial Engineering Society',
  'ies'
);
insert into public.club_auth_accounts (auth_user_id, club_id)
values (
  '91000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000001'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000001',
  true
);
select lives_ok(
  $$update public.clubs
    set short_name = 'IES'
    where id = '92000000-0000-0000-0000-000000000001'$$,
  'the linked club account can update its initials'
);
select is(
  (
    select short_name
    from public.clubs
    where id = '92000000-0000-0000-0000-000000000001'
  ),
  'IES',
  'the linked club initials update is stored'
);

select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000002',
  true
);
-- RLS hides rows the caller does not own, so the foreign update succeeds but
-- matches nothing; the unchanged value below proves zero rows were written.
select lives_ok(
  $$update public.clubs
    set short_name = 'OTHER'
    where id = '92000000-0000-0000-0000-000000000001'$$,
  'a different authenticated account update matches no rows'
);

reset role;
select is(
  (
    select short_name
    from public.clubs
    where id = '92000000-0000-0000-0000-000000000001'
  ),
  'IES',
  'the rejected update leaves the initials unchanged'
);

select * from finish();
rollback;
