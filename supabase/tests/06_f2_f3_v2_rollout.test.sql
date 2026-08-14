begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

delete from private.rate_limit_buckets;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password)
values
  ('00000000-0000-0000-0000-000000000000', '61000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'v2-manager@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '61000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'v2-member@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '61000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'v2-other@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '61000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'v2-other-manager@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '61000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'v2-admin@ku.edu.tr', '');

insert into public.profiles (id, email, full_name)
values
  ('61000000-0000-0000-0000-000000000001', 'v2-manager@ku.edu.tr', 'V2 manager'),
  ('61000000-0000-0000-0000-000000000002', 'v2-member@ku.edu.tr', 'V2 member'),
  ('61000000-0000-0000-0000-000000000003', 'v2-other@ku.edu.tr', 'V2 other'),
  ('61000000-0000-0000-0000-000000000004', 'v2-other-manager@ku.edu.tr', 'V2 other manager'),
  ('61000000-0000-0000-0000-000000000005', 'v2-admin@ku.edu.tr', 'V2 admin')
on conflict (id) do update set full_name = excluded.full_name;

insert into public.clubs (id, name) values
  ('62000000-0000-0000-0000-000000000001', 'V2 managed club'),
  ('62000000-0000-0000-0000-000000000002', 'V2 unrelated club');
insert into public.club_auth_accounts (auth_user_id, club_id) values
  ('61000000-0000-0000-0000-000000000001', '62000000-0000-0000-0000-000000000001'),
  ('61000000-0000-0000-0000-000000000004', '62000000-0000-0000-0000-000000000002');
insert into public.app_admins (singleton, auth_user_id, email)
values (true, '61000000-0000-0000-0000-000000000005', 'v2-admin@ku.edu.tr')
on conflict (singleton) do update
set auth_user_id = excluded.auth_user_id, email = excluded.email;
insert into public.events (id, club_id, title, event_date, starts_at) values
  ('63000000-0000-0000-0000-000000000001', '62000000-0000-0000-0000-000000000001', 'V2 managed event', current_date, now()),
  ('63000000-0000-0000-0000-000000000002', '62000000-0000-0000-0000-000000000002', 'V2 unrelated event', current_date, now());
insert into public.club_posts (id, club_id, content) values
  ('64000000-0000-0000-0000-000000000001', '62000000-0000-0000-0000-000000000001', 'Legacy poll post'),
  ('64000000-0000-0000-0000-000000000002', '62000000-0000-0000-0000-000000000001', 'V2 poll post'),
  ('64000000-0000-0000-0000-000000000003', '62000000-0000-0000-0000-000000000002', 'Unrelated poll post');

-- Released F2 contract: direct insert includes checked_in_by and direct delete
-- filters by event_id/profile_id. The legacy field remains accepted but is
-- already rebound by the canonical trigger.
set local role authenticated;
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$insert into public.event_checkins (event_id, profile_id, checked_in_by, method)
    values (
      '63000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000002',
      '61000000-0000-0000-0000-000000000003',
      'manual'
    )$$,
  'released check-in insert contract still succeeds'
);
select is(
  (select checked_in_by from public.event_checkins
   where event_id = '63000000-0000-0000-0000-000000000001'
     and profile_id = '61000000-0000-0000-0000-000000000002'),
  '61000000-0000-0000-0000-000000000001'::uuid,
  'released checked_in_by payload remains untrusted'
);
delete from public.event_checkins
where event_id = '63000000-0000-0000-0000-000000000001'
  and profile_id = '61000000-0000-0000-0000-000000000002';
select is(
  (select count(*) from public.event_checkins
   where event_id = '63000000-0000-0000-0000-000000000001'),
  0::bigint,
  'released check-in removal contract still succeeds'
);

-- V2 F2 contract.
select lives_ok(
  $$select public.check_in_event_v2(
    '63000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000002',
    'qr'
  )$$,
  'v2 manager check-in succeeds'
);
select is(
  (select checked_in_by from public.event_checkins
   where event_id = '63000000-0000-0000-0000-000000000001'
     and profile_id = '61000000-0000-0000-0000-000000000002'),
  '61000000-0000-0000-0000-000000000001'::uuid,
  'v2 check-in actor is auth.uid'
);
select lives_ok(
  $$select public.check_in_event_v2(
    '63000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000002',
    'qr'
  )$$,
  'v2 duplicate check-in is idempotent'
);
select is(
  (select count(*) from public.event_checkins
   where event_id = '63000000-0000-0000-0000-000000000001'
     and profile_id = '61000000-0000-0000-0000-000000000002'),
  1::bigint,
  'v2 duplicate check-in keeps one canonical record'
);

select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.check_in_event_v2(
    '63000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000003',
    'manual'
  )$$,
  '42501',
  'Not authorized to manage this event',
  'ordinary user cannot use v2 to check in a profile'
);
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000004', true);
select throws_ok(
  $$select public.check_in_event_v2(
    '63000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000003',
    'manual'
  )$$,
  '42501',
  'Not authorized to manage this event',
  'unrelated club manager cannot use v2 check-in'
);
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000005', true);
select lives_ok(
  $$select public.check_in_event_v2(
    '63000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000003',
    'manual'
  )$$,
  'platform admin can use v2 check-in'
);
select is(
  public.remove_event_checkin_v2(
    '63000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000003'
  ),
  true,
  'v2 authorized check-in removal succeeds'
);
select ok(
  position(
    'actor' in pg_get_function_arguments(
      'public.check_in_event_v2(uuid,uuid,text)'::regprocedure
    )
  ) = 0,
  'v2 check-in signature has no caller-supplied actor'
);

-- Released F3 contract: direct poll insert and vote upsert payload with
-- profile_id remain accepted. The vote trigger still replaces profile_id.
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$insert into public.polls (id, post_id, question, options) values (
    '65000000-0000-0000-0000-000000000001',
    '64000000-0000-0000-0000-000000000001',
    'Legacy question',
    '["A", "B"]'::jsonb
  )$$,
  'released poll creation contract still succeeds'
);
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$insert into public.poll_votes (poll_id, profile_id, option_index) values (
    '65000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000003',
    0
  )$$,
  'released poll vote payload still succeeds'
);
select is(
  (select profile_id from public.poll_votes
   where poll_id = '65000000-0000-0000-0000-000000000001'),
  '61000000-0000-0000-0000-000000000002'::uuid,
  'released profile_id payload remains untrusted'
);

-- Calling v2 as the same user updates the legacy-created canonical vote.
select lives_ok(
  $$select public.vote_poll_v2(
    '65000000-0000-0000-0000-000000000001', 1
  )$$,
  'v2 can update a vote created through v1'
);
select is(
  (select option_index from public.poll_votes
   where poll_id = '65000000-0000-0000-0000-000000000001'
     and profile_id = '61000000-0000-0000-0000-000000000002'),
  1,
  'v1-created vote is interoperable with v2'
);

-- V2 F3 creation and vote contract.
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.create_poll_v2(
    '64000000-0000-0000-0000-000000000002',
    'V2 question',
    '["First", "Second"]'::jsonb
  )$$,
  'authorized v2 poll creation succeeds'
);
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.create_poll_v2(
    '64000000-0000-0000-0000-000000000003',
    'Unauthorized',
    '["A", "B"]'::jsonb
  )$$,
  '42501',
  'Not authorized to create a poll for this post',
  'unauthorized v2 poll creation fails'
);
select throws_ok(
  $$select public.vote_poll_v2(
    (select id from public.polls
     where post_id = '64000000-0000-0000-0000-000000000002'),
    2
  )$$,
  '23514',
  'Poll option index is out of range',
  'v2 rejects an invalid option index'
);
select lives_ok(
  $$select public.vote_poll_v2(
    (select id from public.polls
     where post_id = '64000000-0000-0000-0000-000000000002'),
    0
  )$$,
  'v2 own vote succeeds'
);
select is(
  (select profile_id from public.poll_votes
   where poll_id = (select id from public.polls
                    where post_id = '64000000-0000-0000-0000-000000000002')),
  '61000000-0000-0000-0000-000000000003'::uuid,
  'v2 voter identity is auth.uid'
);
select lives_ok(
  $$select public.vote_poll_v2(
    (select id from public.polls
     where post_id = '64000000-0000-0000-0000-000000000002'),
    1
  )$$,
  'v2 own vote update succeeds'
);

select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.vote_poll_v2(
    (select id from public.polls
     where post_id = '64000000-0000-0000-0000-000000000002'),
    0
  )$$,
  'a second v2 voter creates only their own vote'
);
select is(
  (select option_index from public.poll_votes
   where poll_id = (select id from public.polls
                    where post_id = '64000000-0000-0000-0000-000000000002')
     and profile_id = '61000000-0000-0000-0000-000000000003'),
  1,
  'another v2 caller cannot change the first voter vote'
);
select is(
  public.remove_poll_vote_v2(
    (select id from public.polls
     where post_id = '64000000-0000-0000-0000-000000000002')
  ),
  true,
  'v2 removal deletes the caller own vote'
);
select is(
  (select count(*) from public.poll_votes
   where poll_id = (select id from public.polls
                    where post_id = '64000000-0000-0000-0000-000000000002')
     and profile_id = '61000000-0000-0000-0000-000000000003'),
  1::bigint,
  'removing a vote cannot delete another user vote'
);
select ok(
  position(
    'profile' in pg_get_function_arguments(
      'public.vote_poll_v2(uuid,integer)'::regprocedure
    )
  ) = 0,
  'v2 vote signature has no caller-supplied profile identity'
);

reset role;
select ok(
  exists (
    select 1 from private.rate_limit_buckets
    where action in (
      'event_checkin_change:actor',
      'event_checkin_change:resource',
      'poll_create:actor',
      'poll_create:resource',
      'poll_vote_change:actor',
      'poll_vote_change:resource'
    )
  ),
  'v2 F2/F3 mutations consume logical-action rate buckets'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.vote_poll_v2(uuid,integer)',
    'EXECUTE'
  ),
  'anonymous callers cannot execute v2 vote'
);
select ok(
  not exists (
    select 1
    from pg_trigger
    where not tgisinternal
      and tgname like 'rate_limit_%'
  ),
  'v1 direct table paths are not placed behind rate-limit triggers'
);

select * from finish();
rollback;
