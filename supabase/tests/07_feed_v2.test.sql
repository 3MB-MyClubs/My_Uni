begin;
create extension if not exists pgtap with schema extensions;
select plan(35);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password)
values
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'feed-viewer@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'feed-other@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'feed-blocked@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'feed-manager@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'feed-empty@ku.edu.tr', '');

insert into public.profiles (id, email, full_name)
values
  ('71000000-0000-0000-0000-000000000001', 'feed-viewer@ku.edu.tr', 'Feed Viewer'),
  ('71000000-0000-0000-0000-000000000002', 'feed-other@ku.edu.tr', 'Feed Other'),
  ('71000000-0000-0000-0000-000000000003', 'feed-blocked@ku.edu.tr', 'Feed Blocked'),
  ('71000000-0000-0000-0000-000000000004', 'feed-manager@ku.edu.tr', 'Feed Manager'),
  ('71000000-0000-0000-0000-000000000005', 'feed-empty@ku.edu.tr', 'Feed Empty');

insert into public.clubs (id, name)
values
  ('72000000-0000-0000-0000-000000000001', 'Feed followed club'),
  ('72000000-0000-0000-0000-000000000002', 'Feed blocked club'),
  ('72000000-0000-0000-0000-000000000003', 'Feed other visible club');
insert into public.club_auth_accounts (auth_user_id, club_id)
values ('71000000-0000-0000-0000-000000000004', '72000000-0000-0000-0000-000000000001');
insert into public.club_followers (club_id, profile_id)
values ('72000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001');

-- Fourteen visible followed posts. The first pair deliberately share a
-- timestamp so id is required as the cursor tie-breaker.
insert into public.club_posts (id, club_id, author_id, content, created_at)
select
  ('73000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
  '72000000-0000-0000-0000-000000000001'::uuid,
  '71000000-0000-0000-0000-000000000004'::uuid,
  'Feed post ' || n,
  case
    when n <= 2 then '2026-08-12 09:00:00+00'::timestamptz
    else '2026-08-12 09:00:00+00'::timestamptz - n * interval '1 minute'
  end
from generate_series(1, 14) as n;

-- These rows exercise caller blocks and followed-only filtering.
insert into public.club_posts (id, club_id, author_id, content, created_at)
values
  ('73000000-0000-0000-0000-000000000015', '72000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000003', 'Blocked author post', '2026-08-12 10:00:00+00'),
  ('73000000-0000-0000-0000-000000000016', '72000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000002', 'Blocked club post', '2026-08-12 10:00:00+00'),
  ('73000000-0000-0000-0000-000000000017', '72000000-0000-0000-0000-000000000003', '71000000-0000-0000-0000-000000000002', 'Unfollowed visible post', '2026-08-12 08:00:00+00');

insert into public.user_blocks (blocker_id, blocked_id)
values ('71000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000003');
insert into public.club_blocks (blocker_id, club_id)
values ('71000000-0000-0000-0000-000000000001', '72000000-0000-0000-0000-000000000002');

insert into public.post_likes (post_id, profile_id)
values
  ('73000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000001'),
  ('73000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000002');
insert into public.post_comments (post_id, profile_id, content)
values
  ('73000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000001', 'One'),
  ('73000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000002', 'Two'),
  ('73000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000003', 'Hidden by block');
insert into public.post_views (post_id, profile_id)
values
  ('73000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000001'),
  ('73000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000002');

insert into public.events (id, club_id, title, event_date, starts_at, ends_at)
values (
  '75000000-0000-0000-0000-000000000001',
  '72000000-0000-0000-0000-000000000001',
  'Feed event', current_date + 1, now() + interval '1 day', now() + interval '1 day 2 hours'
);
insert into public.event_rsvps (event_id, profile_id)
values
  ('75000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001'),
  ('75000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000002');

-- A released-style direct poll and vote, followed by a v2-created poll. Both
-- use the same canonical tables rendered by Feed v2.
set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000004', true);
insert into public.polls (id, post_id, question, options)
values (
  '74000000-0000-0000-0000-000000000001',
  '73000000-0000-0000-0000-000000000002',
  'Legacy feed poll', '["A", "B"]'::jsonb
);
select public.create_poll_v2(
  '73000000-0000-0000-0000-000000000001',
  'V2 feed poll',
  '["One", "Two"]'::jsonb
);

select set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000001', true);
insert into public.poll_votes (poll_id, profile_id, option_index)
values (
  '74000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000002',
  1
);
select public.vote_poll_v2(
  (select id from public.polls where post_id = '73000000-0000-0000-0000-000000000001'),
  0
);
select set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000002', true);
insert into public.poll_votes (poll_id, profile_id, option_index)
values ('74000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000002', 0);

reset role;
create temporary table feed_v2_test_pages (
  name text primary key,
  response jsonb not null
);
grant select, insert, update, delete on feed_v2_test_pages to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000001', true);
insert into feed_v2_test_pages (name, response)
values ('first', public.get_feed_page_v2(5, null, null, false));

select has_function(
  'public', 'get_feed_page_v2',
  array['integer', 'timestamp with time zone', 'uuid', 'boolean'],
  'Feed v2 RPC exists with a versioned signature'
);
select ok(
  not (select prosecdef from pg_proc where oid = 'public.get_feed_page_v2(integer,timestamptz,uuid,boolean)'::regprocedure),
  'Feed v2 uses security-invoker semantics'
);
select ok(
  has_function_privilege('authenticated', 'public.get_feed_page_v2(integer,timestamptz,uuid,boolean)', 'EXECUTE'),
  'authenticated callers can execute Feed v2'
);
select ok(
  not has_function_privilege('anon', 'public.get_feed_page_v2(integer,timestamptz,uuid,boolean)', 'EXECUTE'),
  'anonymous callers cannot execute Feed v2'
);
select is(
  jsonb_array_length((select response->'items' from feed_v2_test_pages where name = 'first')),
  5,
  'first page is limited to the requested size'
);
select ok(
  ((select response from feed_v2_test_pages where name = 'first')->>'has_more')::boolean,
  'first page reports more rows'
);
select is(
  (select response#>>'{items,0,id}' from feed_v2_test_pages where name = 'first'),
  '73000000-0000-0000-0000-000000000002',
  'equal timestamps use id descending as the stable tie-breaker'
);
select is(
  (select response#>>'{items,1,id}' from feed_v2_test_pages where name = 'first'),
  '73000000-0000-0000-0000-000000000001',
  'the second equal-timestamp row remains adjacent and ordered'
);
select ok(
  not ((select response from feed_v2_test_pages where name = 'first')->'items') @>
    '[{"id":"73000000-0000-0000-0000-000000000015"}]'::jsonb,
  'a post authored by a blocked user is excluded'
);
select ok(
  not ((select response from feed_v2_test_pages where name = 'first')->'items') @>
    '[{"id":"73000000-0000-0000-0000-000000000016"}]'::jsonb,
  'a post from a blocked club is excluded'
);
select is(
  ((select response#>>'{items,0,engagement,like_count}' from feed_v2_test_pages where name = 'first'))::integer,
  2,
  'like rows are aggregated in PostgreSQL'
);
select is(
  ((select response#>>'{items,0,engagement,comment_count}' from feed_v2_test_pages where name = 'first'))::integer,
  2,
  'comment count excludes blocked commenter identities'
);
select is(
  ((select response#>>'{items,0,engagement,view_count}' from feed_v2_test_pages where name = 'first'))::integer,
  2,
  'view rows are aggregated in PostgreSQL'
);
select ok(
  ((select response#>>'{items,0,engagement,viewer_has_liked}' from feed_v2_test_pages where name = 'first'))::boolean,
  'viewer like state is derived from auth.uid()'
);
select is(
  ((select response#>>'{items,0,poll,total_votes}' from feed_v2_test_pages where name = 'first'))::integer,
  2,
  'poll vote total is aggregated without voter identities'
);
select is(
  ((select response#>>'{items,0,poll,option_counts,0}' from feed_v2_test_pages where name = 'first'))::integer,
  1,
  'poll option totals are server composed'
);
select is(
  ((select response#>>'{items,0,poll,viewer_option_index}' from feed_v2_test_pages where name = 'first'))::integer,
  1,
  'viewer poll choice comes from auth.uid() despite forged legacy profile_id'
);
select is(
  ((select response#>>'{upcoming_events,0,rsvp_count}' from feed_v2_test_pages where name = 'first'))::integer,
  2,
  'RSVP rows are aggregated in PostgreSQL'
);
select ok(
  ((select response#>>'{upcoming_events,0,viewer_is_attending}' from feed_v2_test_pages where name = 'first'))::boolean,
  'viewer RSVP state is derived from auth.uid()'
);
select ok(
  position('email' in (select response::text from feed_v2_test_pages where name = 'first')) = 0,
  'Feed v2 does not expose profile or club email fields'
);
select ok(
  position('profile_id' in (select response::text from feed_v2_test_pages where name = 'first')) = 0
  and position('attendee_user_ids' in (select response::text from feed_v2_test_pages where name = 'first')) = 0,
  'Feed v2 does not expose voter, viewer, or attendee identity lists'
);
select is(
  jsonb_array_length(public.get_feed_page_v2(50, null, null, true)->'items'),
  14,
  'followed-only feed excludes otherwise-visible unfollowed clubs'
);

-- Preserve a cursor, then mutate rows before asking for the next page.
reset role;
insert into public.club_posts (id, club_id, author_id, content, created_at)
values (
  '73000000-0000-0000-0000-000000000099',
  '72000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000004',
  'Inserted after first page',
  '2026-08-12 11:00:00+00'
);
delete from public.club_posts where id = '73000000-0000-0000-0000-000000000010';
set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000001', true);
insert into feed_v2_test_pages (name, response)
select
  'second',
  public.get_feed_page_v2(
    5,
    (response#>>'{next_cursor,created_at}')::timestamptz,
    (response#>>'{next_cursor,id}')::uuid,
    false
  )
from feed_v2_test_pages where name = 'first';

select ok(
  not ((select response from feed_v2_test_pages where name = 'second')->'items') @>
    '[{"id":"73000000-0000-0000-0000-000000000099"}]'::jsonb,
  'a newer insert does not duplicate into a later cursor page'
);
select ok(
  not ((select response from feed_v2_test_pages where name = 'second')->'items') @>
    '[{"id":"73000000-0000-0000-0000-000000000010"}]'::jsonb,
  'a deleted row is absent from later pages'
);
select is(
  jsonb_array_length((select response->'items' from feed_v2_test_pages where name = 'second')),
  5,
  'deletion does not prevent a full next page when more rows remain'
);

select is(
  (
    with recursive pages(page_number, response) as (
      select 1, public.get_feed_page_v2(5, null, null, false)
      union all
      select
        page_number + 1,
        public.get_feed_page_v2(
          5,
          (response#>>'{next_cursor,created_at}')::timestamptz,
          (response#>>'{next_cursor,id}')::uuid,
          false
        )
      from pages
      where (response->>'has_more')::boolean and page_number < 20
    ), ids as (
      select item->>'id' as id
      from pages cross join lateral jsonb_array_elements(response->'items') as item
    )
    select count(*) from ids
  ),
  15::bigint,
  'all pages cover every currently visible row without skips'
);
select is(
  (
    with recursive pages(page_number, response) as (
      select 1, public.get_feed_page_v2(5, null, null, false)
      union all
      select
        page_number + 1,
        public.get_feed_page_v2(
          5,
          (response#>>'{next_cursor,created_at}')::timestamptz,
          (response#>>'{next_cursor,id}')::uuid,
          false
        )
      from pages
      where (response->>'has_more')::boolean and page_number < 20
    ), ids as (
      select item->>'id' as id
      from pages cross join lateral jsonb_array_elements(response->'items') as item
    )
    select count(distinct id) from ids
  ),
  15::bigint,
  'all pages contain no duplicate rows'
);

select set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000005', true);
select is(
  jsonb_array_length(public.get_feed_page_v2(25, null, null, true)->'items'),
  0,
  'a followed-only user with no follows receives an empty final page'
);
select throws_ok(
  $$select public.get_feed_page_v2(25, now(), null, false)$$,
  '22023',
  'Both cursor fields must be provided together',
  'partial cursors are rejected'
);

reset role;
select ok(
  exists (
    select 1 from public.polls
    where post_id = '73000000-0000-0000-0000-000000000001'
      and question = 'V2 feed poll'
  ),
  'a v2-created poll remains visible to legacy canonical reads'
);
select ok(
  exists (
    select 1 from public.poll_votes as vote
    join public.polls as poll on poll.id = vote.poll_id
    where poll.post_id = '73000000-0000-0000-0000-000000000001'
      and vote.profile_id = '71000000-0000-0000-0000-000000000001'
  ),
  'a v2 vote remains visible to legacy canonical reads'
);
select ok(
  has_table_privilege('authenticated', 'public.poll_votes', 'INSERT'),
  'Feed v2 does not remove released poll-vote direct-write compatibility'
);
select ok(
  has_table_privilege('authenticated', 'public.event_checkins', 'INSERT'),
  'Feed v2 does not alter released check-in compatibility grants'
);
select ok(
  has_table_privilege('authenticated', 'public.club_posts', 'INSERT'),
  'Feed v2 preserves the canonical legacy/new post creation table contract'
);
select ok(
  has_table_privilege('authenticated', 'public.events', 'INSERT'),
  'Feed v2 preserves the canonical legacy/new event creation table contract'
);

select * from finish();
rollback;
