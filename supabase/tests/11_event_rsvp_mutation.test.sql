begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password)
values (
  '00000000-0000-0000-0000-000000000000',
  '81000000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'rsvp-mutation@ku.edu.tr',
  ''
);
insert into public.profiles (id, email, full_name)
values (
  '81000000-0000-0000-0000-000000000001',
  'rsvp-mutation@ku.edu.tr',
  'RSVP Mutation Tester'
);
insert into public.clubs (id, name)
values ('82000000-0000-0000-0000-000000000001', 'RSVP Mutation Club');
insert into public.events (id, club_id, title, event_date, starts_at, ends_at)
values (
  '83000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  'RSVP Mutation Event',
  current_date + 1,
  now() + interval '1 day',
  now() + interval '1 day 2 hours'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$insert into public.event_rsvps (event_id, profile_id)
    values (
      '83000000-0000-0000-0000-000000000001',
      '81000000-0000-0000-0000-000000000001'
    )$$,
  'authenticated user can RSVP to an event'
);
select is(
  (select count(*) from public.event_rsvps
   where event_id = '83000000-0000-0000-0000-000000000001'
     and profile_id = '81000000-0000-0000-0000-000000000001'),
  1::bigint,
  'RSVP row exists after insert'
);
select lives_ok(
  $$delete from public.event_rsvps
    where event_id = '83000000-0000-0000-0000-000000000001'
      and profile_id = '81000000-0000-0000-0000-000000000001'$$,
  'authenticated user can remove their RSVP'
);
select is(
  (select count(*) from public.event_rsvps
   where event_id = '83000000-0000-0000-0000-000000000001'
     and profile_id = '81000000-0000-0000-0000-000000000001'),
  0::bigint,
  'RSVP row is gone after delete'
);

select * from finish();
rollback;
