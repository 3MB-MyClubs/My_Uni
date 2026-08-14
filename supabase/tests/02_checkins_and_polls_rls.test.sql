begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password)
values
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'manager@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'member@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'other@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'other-manager@ku.edu.tr', '');

insert into public.profiles (id, email, full_name)
values
  ('10000000-0000-0000-0000-000000000001', 'manager@ku.edu.tr', 'Manager'),
  ('10000000-0000-0000-0000-000000000002', 'member@ku.edu.tr', 'Member'),
  ('10000000-0000-0000-0000-000000000003', 'other@ku.edu.tr', 'Other'),
  ('10000000-0000-0000-0000-000000000004', 'other-manager@ku.edu.tr', 'Other manager')
on conflict (id) do update set full_name = excluded.full_name;

insert into public.clubs (id, name) values
  ('20000000-0000-0000-0000-000000000001', 'Managed club'),
  ('20000000-0000-0000-0000-000000000002', 'Unrelated club');
insert into public.club_auth_accounts (auth_user_id, club_id) values
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000002');
insert into public.events (id, club_id, title, event_date, starts_at) values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Managed event', current_date, now()),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'Other event', current_date, now());
insert into public.club_posts (id, club_id, content) values
  ('40000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Poll post'),
  ('40000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'Other post');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
insert into public.event_checkins (event_id, profile_id, checked_in_by, method)
values (
  '30000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000003',
  'manual'
);
select is(
  (select checked_in_by from public.event_checkins
   where event_id = '30000000-0000-0000-0000-000000000001'),
  '10000000-0000-0000-0000-000000000001'::uuid,
  'checked_in_by is bound to auth.uid despite a forged payload'
);
select is((select count(*) from public.event_checkins), 1::bigint, 'event manager can read managed check-ins');

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$insert into public.event_checkins (event_id, profile_id, method)
    values ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 'manual')$$,
  '42501',
  'new row violates row-level security policy for table "event_checkins"',
  'an ordinary user cannot check in another profile'
);
delete from public.event_checkins
where event_id = '30000000-0000-0000-0000-000000000001'
  and profile_id = '10000000-0000-0000-0000-000000000002';
select is((select count(*) from public.event_checkins), 0::bigint, 'ordinary users cannot enumerate another profile check-in');

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is(
  (select count(*) from public.event_checkins
   where event_id = '30000000-0000-0000-0000-000000000001'),
  1::bigint,
  'an unauthorized delete leaves another profile check-in intact'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);
select throws_ok(
  $$insert into public.event_checkins (event_id, profile_id, method)
    values ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 'manual')$$,
  '42501',
  'new row violates row-level security policy for table "event_checkins"',
  'a manager cannot mutate an unrelated event'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
insert into public.polls (id, post_id, question, options) values (
  '50000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  'Choose one',
  '["A", "B"]'::jsonb
);
select ok(
  exists (select 1 from public.polls where id = '50000000-0000-0000-0000-000000000001'),
  'an authorized post manager can create a poll'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$insert into public.polls (post_id, question, options)
    values ('40000000-0000-0000-0000-000000000001', 'Forged poll', '["A", "B"]')$$,
  '42501',
  'new row violates row-level security policy for table "polls"',
  'an ordinary member cannot create a poll'
);
insert into public.poll_votes (poll_id, profile_id, option_index) values (
  '50000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000003',
  0
);
select is(
  (select profile_id from public.poll_votes where poll_id = '50000000-0000-0000-0000-000000000001'),
  '10000000-0000-0000-0000-000000000002'::uuid,
  'vote identity is bound to auth.uid'
);
update public.poll_votes set option_index = 1
where poll_id = '50000000-0000-0000-0000-000000000001';
select is(
  (select option_index from public.poll_votes where poll_id = '50000000-0000-0000-0000-000000000001'),
  1,
  'a voter can change their own vote'
);
select throws_ok(
  $$update public.poll_votes set option_index = 2
    where poll_id = '50000000-0000-0000-0000-000000000001'$$,
  '23514',
  'Poll option index is out of range',
  'the database rejects an invalid option index'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
update public.poll_votes set option_index = 0
where poll_id = '50000000-0000-0000-0000-000000000001';
select is(
  (select option_index from public.poll_votes where poll_id = '50000000-0000-0000-0000-000000000001'),
  1,
  'another user cannot change a vote'
);
delete from public.poll_votes
where poll_id = '50000000-0000-0000-0000-000000000001';
select is(
  (select count(*) from public.poll_votes where poll_id = '50000000-0000-0000-0000-000000000001'),
  1::bigint,
  'another user cannot delete a vote'
);
select is(
  (select count(*) from public.poll_votes where profile_id = '10000000-0000-0000-0000-000000000002'),
  1::bigint,
  'authenticated users can read aggregate vote rows for a visible poll'
);
select ok(
  not has_table_privilege('anon', 'public.poll_votes', 'INSERT'),
  'anonymous callers cannot vote'
);
select ok(
  not has_table_privilege('anon', 'public.event_checkins', 'DELETE'),
  'anonymous callers cannot delete check-ins'
);

select * from finish();
rollback;
