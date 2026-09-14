-- Local regression coverage; never run these fixture writes against production.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password)
values
  ('00000000-0000-0000-0000-000000000000', 'c1000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'follow-student@example.test', ''),
  ('00000000-0000-0000-0000-000000000000', 'c1000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'follow-moderator@example.test', ''),
  ('00000000-0000-0000-0000-000000000000', 'c1000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'follow-target@example.test', '');

insert into public.profiles (id, email, full_name)
values
  ('c1000000-0000-4000-8000-000000000001', 'follow-student@example.test', 'Follow Student'),
  ('c1000000-0000-4000-8000-000000000002', 'follow-moderator@example.test', 'Follow Moderator'),
  ('c1000000-0000-4000-8000-000000000003', 'follow-target@example.test', 'Follow Target');

insert into public.clubs (id, name)
values ('c2000000-0000-4000-8000-000000000001', 'Follow fixture club');

insert into public.app_admins (singleton, auth_user_id, email)
values (
  true,
  'c1000000-0000-4000-8000-000000000002',
  'follow-moderator@example.test'
)
on conflict (singleton) do update
set auth_user_id = excluded.auth_user_id,
    email = excluded.email;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c1000000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$insert into public.club_followers (club_id, profile_id, role)
    values (
      'c2000000-0000-4000-8000-000000000001',
      'c1000000-0000-4000-8000-000000000002',
      'member'
    )$$,
  '42501',
  null,
  'the platform moderator cannot follow a club'
);
select throws_ok(
  $$insert into public.profile_follows (follower_id, following_id)
    values (
      'c1000000-0000-4000-8000-000000000002',
      'c1000000-0000-4000-8000-000000000003'
    )$$,
  '42501',
  null,
  'the platform moderator cannot follow a student'
);
select is(
  (select count(*) from public.club_followers
   where profile_id = 'c1000000-0000-4000-8000-000000000002'),
  0::bigint,
  'the rejected club follow creates no row'
);
select is(
  (select count(*) from public.profile_follows
   where follower_id = 'c1000000-0000-4000-8000-000000000002'),
  0::bigint,
  'the rejected student follow creates no row'
);

select set_config(
  'request.jwt.claim.sub',
  'c1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$insert into public.club_followers (club_id, profile_id, role)
    values (
      'c2000000-0000-4000-8000-000000000001',
      'c1000000-0000-4000-8000-000000000001',
      'member'
    )$$,
  'a student can still follow a club'
);
select lives_ok(
  $$insert into public.profile_follows (follower_id, following_id)
    values (
      'c1000000-0000-4000-8000-000000000001',
      'c1000000-0000-4000-8000-000000000003'
    )$$,
  'a student can still follow another student'
);
select is(
  (select count(*) from public.club_followers
   where profile_id = 'c1000000-0000-4000-8000-000000000001'),
  1::bigint,
  'the student club follow is persisted'
);
select is(
  (select count(*) from public.profile_follows
   where follower_id = 'c1000000-0000-4000-8000-000000000001'),
  1::bigint,
  'the student profile follow is persisted'
);

select * from finish();
rollback;
