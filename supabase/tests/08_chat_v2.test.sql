begin;
create extension if not exists pgtap with schema extensions;
select plan(51);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password)
values
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'chat-viewer@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'chat-peer@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'chat-outsider@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'chat-board@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'chat-blocker@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000006', 'authenticated', 'authenticated', 'chat-club@ku.edu.tr', '');

insert into public.profiles (id, email, full_name, avatar_url)
values
  ('81000000-0000-0000-0000-000000000001', 'chat-viewer@ku.edu.tr', 'Chat Viewer', 'viewer.png'),
  ('81000000-0000-0000-0000-000000000002', 'chat-peer@ku.edu.tr', 'Chat Peer', 'peer.png'),
  ('81000000-0000-0000-0000-000000000003', 'chat-outsider@ku.edu.tr', 'Chat Outsider', null),
  ('81000000-0000-0000-0000-000000000004', 'chat-board@ku.edu.tr', 'Chat Board', null),
  ('81000000-0000-0000-0000-000000000005', 'chat-blocker@ku.edu.tr', 'Chat Blocker', null);

insert into public.clubs (id, name, short_name, logo_url)
values
  ('82000000-0000-0000-0000-000000000001', 'Chat Club', 'CHAT', 'club.png'),
  ('82000000-0000-0000-0000-000000000002', 'Other Club', 'OTHER', null);
insert into public.club_auth_accounts (auth_user_id, club_id)
values ('81000000-0000-0000-0000-000000000006', '82000000-0000-0000-0000-000000000001');
insert into public.club_followers (club_id, profile_id, role)
values
  ('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'board_member'),
  ('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002', 'member'),
  ('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000004', 'board_member');

insert into public.group_chats (id, creator_id, admin_ids, custom_name, created_at)
values
  ('82000000-0000-0000-0000-000000000101', '81000000-0000-0000-0000-000000000001', '{81000000-0000-0000-0000-000000000001}', 'Visible group', '2026-08-12 11:00:00+00'),
  ('82000000-0000-0000-0000-000000000102', '81000000-0000-0000-0000-000000000003', '{}', 'Hidden group', '2026-08-12 11:00:00+00');
insert into public.group_chat_members (group_id, user_id, position)
values
  ('82000000-0000-0000-0000-000000000101', '81000000-0000-0000-0000-000000000001', 0),
  ('82000000-0000-0000-0000-000000000101', '81000000-0000-0000-0000-000000000002', 1),
  ('82000000-0000-0000-0000-000000000102', '81000000-0000-0000-0000-000000000003', 0);

insert into public.direct_messages (
  id, sender_id, receiver_id, content, created_at, delivered_at
) values
  ('84000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000001', 'DM older', '2026-08-12 10:00:00+00', '2026-08-12 10:00:00+00'),
  ('84000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000001', 'DM newest', '2026-08-12 11:00:00+00', '2026-08-12 11:00:00+00');

insert into public.group_messages (id, group_id, sender_id, content, created_at)
select
  ('83000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
  '82000000-0000-0000-0000-000000000101'::uuid,
  '81000000-0000-0000-0000-000000000002'::uuid,
  'Group message ' || n,
  case when n <= 2 then '2026-08-12 12:00:00+00'::timestamptz
       else '2026-08-12 12:00:00+00'::timestamptz - (n - 2) * interval '1 minute' end
from generate_series(1, 55) as n;
insert into public.group_messages (id, group_id, sender_id, content, created_at)
values ('83000000-0000-0000-0000-000000000099', '82000000-0000-0000-0000-000000000102', '81000000-0000-0000-0000-000000000003', 'Hidden', '2026-08-12 13:00:00+00');

insert into public.club_channel_messages (
  id, club_id, sender_auth_id, sender_profile_id, content, message_kind, payload, created_at
) values
  ('85000000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000004', '81000000-0000-0000-0000-000000000004', 'Board notice', 'announcement', '{}', '2026-08-12 09:00:00+00'),
  ('85000000-0000-0000-0000-000000000002', '82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000004', '81000000-0000-0000-0000-000000000004', 'Choose one', 'poll', '{"pollOptions":["A","B"]}', '2026-08-12 09:01:00+00');
insert into public.club_channel_poll_votes (message_id, voter_auth_id, option_index)
values ('85000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000001', 1);

insert into public.club_inbox_threads (id, club_id, profile_id, created_at, updated_at)
values
  ('82000000-0000-0000-0000-000000000201', '82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', '2026-08-12 08:00:00+00', '2026-08-12 08:01:00+00'),
  ('82000000-0000-0000-0000-000000000202', '82000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000003', '2026-08-12 08:00:00+00', '2026-08-12 08:01:00+00');
insert into public.club_inbox_messages (
  id, thread_id, sender_auth_id, sender_club_id, content, created_at, delivered_at
) values (
  '86000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000201',
  '81000000-0000-0000-0000-000000000006',
  '82000000-0000-0000-0000-000000000001',
  'Inbox reply', '2026-08-12 08:01:00+00', '2026-08-12 08:01:00+00'
);

create temp table chat_v2_test_state (
  key text primary key,
  value jsonb not null
);
grant select, insert, update, delete on chat_v2_test_state to authenticated;

select ok(
  has_function_privilege('authenticated', 'public.get_conversation_summaries_v2(integer,timestamptz,text)', 'EXECUTE'),
  'authenticated clients can execute the v2 summary RPC'
);
select ok(
  not has_function_privilege('anon', 'public.get_conversation_summaries_v2(integer,timestamptz,text)', 'EXECUTE'),
  'anonymous clients cannot execute the v2 summary RPC'
);
select ok(
  not has_function_privilege('anon', 'public.send_message_v2(text,uuid,text,text,jsonb,timestamptz,boolean)', 'EXECUTE'),
  'anonymous clients cannot execute the v2 send RPC'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.get_conversation_summaries_v2(50, null, null)$$,
  'one summary request succeeds for every visible conversation type'
);
insert into chat_v2_test_state values (
  'summary', public.get_conversation_summaries_v2(50, null, null)
);
select is(
  jsonb_array_length((select value->'items' from chat_v2_test_state where key = 'summary')),
  4,
  'the summary response contains only the four visible conversations'
);
select ok(
  position('email' in lower((select value::text from chat_v2_test_state where key = 'summary'))) = 0,
  'the summary payload contains no profile email'
);
select is(
  jsonb_array_length((select item->'group'->'members'
    from jsonb_array_elements((select value->'items' from chat_v2_test_state where key = 'summary')) as item
    where item->>'thread_type' = 'group')),
  2,
  'group participant metadata is embedded in the same summary response'
);
select is(
  (select (item->>'unread_board_count')::integer
   from jsonb_array_elements((select value->'items' from chat_v2_test_state where key = 'summary')) as item
   where item->>'thread_type' = 'club'),
  1,
  'Board unread is counted server-side'
);
select is(
  (select (item->>'unread_chat_count')::integer
   from jsonb_array_elements((select value->'items' from chat_v2_test_state where key = 'summary')) as item
   where item->>'thread_type' = 'club'),
  1,
  'Chat-lane unread is counted server-side'
);
select is(
  (select item->'read_boundaries'->'board'->>'id'
   from jsonb_array_elements((select value->'items' from chat_v2_test_state where key = 'summary')) as item
   where item->>'thread_type' = 'club'),
  '85000000-0000-0000-0000-000000000001',
  'the summary carries a bounded server read target for each club lane'
);

with first_page as (
  select public.get_conversation_summaries_v2(2, null, null) as page
), second_page as (
  select public.get_conversation_summaries_v2(
    2,
    (page->'next_cursor'->>'activity_at')::timestamptz,
    page->'next_cursor'->>'thread_id'
  ) as page from first_page
)
select is(jsonb_array_length(first_page.page->'items'), 2,
  'conversation summary pagination respects its requested bound')
from first_page;
with first_page as (
  select public.get_conversation_summaries_v2(2, null, null) as page
), second_page as (
  select public.get_conversation_summaries_v2(
    2,
    (page->'next_cursor'->>'activity_at')::timestamptz,
    page->'next_cursor'->>'thread_id'
  ) as page from first_page
), ids as (
  select item->>'thread_id' as id from first_page, jsonb_array_elements(first_page.page->'items') as item
  union all
  select item->>'thread_id' as id from second_page, jsonb_array_elements(second_page.page->'items') as item
)
select is(count(distinct id), count(*), 'summary keyset pages do not overlap') from ids;

insert into chat_v2_test_state values (
  'history_1',
  public.get_messages_page_v2('group:82000000-0000-0000-0000-000000000101', 40, null, null)
);
select is(jsonb_array_length((select value->'items' from chat_v2_test_state where key = 'history_1')), 40,
  'the initial history page is bounded to forty messages');
select ok((select (value->>'has_more')::boolean from chat_v2_test_state where key = 'history_1'),
  'the initial page advertises older history');
select is(
  (select value->'items'->0->>'id' from chat_v2_test_state where key = 'history_1'),
  '83000000-0000-0000-0000-000000000002',
  'equal timestamps use id as the stable newest-first tie-breaker'
);
insert into chat_v2_test_state
select
  'history_2',
  public.get_messages_page_v2(
    'group:82000000-0000-0000-0000-000000000101',
    40,
    (value->'next_cursor'->>'created_at')::timestamptz,
    (value->'next_cursor'->>'id')::uuid
  )
from chat_v2_test_state where key = 'history_1';
select is(jsonb_array_length((select value->'items' from chat_v2_test_state where key = 'history_2')), 15,
  'the second history page returns only the remaining rows');
with ids as (
  select item->>'id' as id from chat_v2_test_state, jsonb_array_elements(value->'items') as item
  where key in ('history_1', 'history_2')
)
select is(count(distinct id), 55::bigint, 'history pages contain no duplicate message ids') from ids;
select is(
  (select item->'poll_totals'->>1
   from jsonb_array_elements(public.get_messages_page_v2(
     'club:82000000-0000-0000-0000-000000000001', 40, null, null
   )->'items') item
   where item->>'id' = '85000000-0000-0000-0000-000000000002'),
  '1',
  'club history exposes aggregate poll totals'
);
select is(
  (select item->>'viewer_option_index'
   from jsonb_array_elements(public.get_messages_page_v2(
     'club:82000000-0000-0000-0000-000000000001', 40, null, null
   )->'items') item
   where item->>'id' = '85000000-0000-0000-0000-000000000002'),
  '1',
  'club history exposes only the current viewer poll choice'
);
select ok(
  (public.get_messages_page_v2(
    'club:82000000-0000-0000-0000-000000000001', 40, null, null
  )->'items'->1 ? 'poll_votes') is false,
  'club history does not expose the voter identity map'
);

select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.get_messages_page_v2(
    'group:82000000-0000-0000-0000-000000000101', 40, null, null
  )$$,
  '42501', 'Conversation is not visible',
  'a nonparticipant cannot read a conversation page'
);
select is(
  (select count(*) from public.chat_v2_change_log
   where thread_id = 'group:82000000-0000-0000-0000-000000000101'),
  0::bigint,
  'change-log RLS does not expose another group'
);

select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
reset role;
delete from private.rate_limit_buckets;
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.send_message_v2(
    'group:82000000-0000-0000-0000-000000000101',
    '87000000-0000-0000-0000-000000000001', 'Outbox message'
  )$$,
  'the v2 send RPC writes a canonical message'
);
select is(
  (select sender_id from public.group_messages where id = '87000000-0000-0000-0000-000000000001'),
  '81000000-0000-0000-0000-000000000001'::uuid,
  'the v2 sender is bound to auth.uid'
);
select lives_ok(
  $$select public.send_message_v2(
    'group:82000000-0000-0000-0000-000000000101',
    '87000000-0000-0000-0000-000000000001', 'Outbox message'
  )$$,
  'retrying the same client UUID is idempotent'
);
select is(
  (select count(*) from public.group_messages where id = '87000000-0000-0000-0000-000000000001'),
  1::bigint,
  'an idempotent retry leaves one canonical row'
);
reset role;
select is(
  (select count(*) from public.notifications
   where dedupe_key = 'group_message:87000000-0000-0000-0000-000000000001:81000000-0000-0000-0000-000000000002'),
  1::bigint,
  'the v2 chat insert fires the database notification trigger'
);
select is(
  (select sum(allowed_count) from private.rate_limit_buckets
   where action in ('message_send:actor', 'message_send:resource')),
  2::numeric,
  'an acknowledged outbox retry does not consume another rate-limit token'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select public.send_message_v2(
    'group:82000000-0000-0000-0000-000000000101',
    '87000000-0000-0000-0000-000000000001', 'Different payload'
  )$$,
  '23505', 'Message id is already used',
  'reusing a UUID for different content is rejected'
);

reset role;
insert into public.user_blocks (blocker_id, blocked_id)
values ('81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000001');
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
select is(
  jsonb_array_length(public.get_conversation_summaries_v2(50, null, null)->'items'),
  3,
  'a reverse block removes the direct conversation from summaries'
);
select throws_ok(
  $$select public.send_message_v2(
    'dm:81000000-0000-0000-0000-000000000001|81000000-0000-0000-0000-000000000002',
    '87000000-0000-0000-0000-000000000002', 'Blocked send'
  )$$,
  '42501', 'Conversation is blocked',
  'a reverse block also prevents v2 sends'
);

reset role;
delete from private.rate_limit_buckets;
update private.rate_limit_rules set burst_capacity = 2, sustained_capacity = 100
where action = 'message_send:actor';
update private.rate_limit_rules set burst_capacity = 100, sustained_capacity = 100
where action = 'message_send:resource';
create temp table chat_v2_rate_error (state text, message text);
grant select, insert on chat_v2_rate_error to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.send_message_v2(
    'group:82000000-0000-0000-0000-000000000101',
    '87000000-0000-0000-0000-000000000011', 'Rate one'
  )$$,
  'a normal message remains below the v2 burst boundary'
);
select lives_ok(
  $$select public.send_message_v2(
    'group:82000000-0000-0000-0000-000000000101',
    '87000000-0000-0000-0000-000000000012', 'Rate two'
  )$$,
  'the configured v2 burst capacity is accepted'
);
do $rate_test$
begin
  perform public.send_message_v2(
    'group:82000000-0000-0000-0000-000000000101',
    '87000000-0000-0000-0000-000000000013', 'Rate three'
  );
exception when others then
  insert into chat_v2_rate_error values (sqlstate, sqlerrm);
end
$rate_test$;
select is((select state from chat_v2_rate_error), 'PGRST',
  'the v2 send boundary returns the PostgREST rate-limit SQLSTATE');
select ok(position('rate_limit_exceeded' in (select message from chat_v2_rate_error)) > 0,
  'the v2 send rejection carries the structured rate-limit code');

reset role;
delete from private.rate_limit_buckets;
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.mark_conversation_read_v2(
    'group:82000000-0000-0000-0000-000000000101',
    (select created_at from public.group_messages where id = '83000000-0000-0000-0000-000000000020'),
    '83000000-0000-0000-0000-000000000020', 'all'
  )$$,
  'one set-based RPC marks a group read boundary'
);
select is(
  (select count(*) from public.group_message_receipts
   where user_id = '81000000-0000-0000-0000-000000000001' and seen_at is not null),
  (select count(*) from public.group_messages
   where group_id = '82000000-0000-0000-0000-000000000101'
     and sender_id <> '81000000-0000-0000-0000-000000000001'
     and (created_at, id) <= (
       (select created_at from public.group_messages where id = '83000000-0000-0000-0000-000000000020'),
       '83000000-0000-0000-0000-000000000020'::uuid
     )),
  'group receipts are updated only through the requested boundary'
);
select ok(
  position('loop' in lower(pg_get_functiondef(
    'public.mark_conversation_read_v2(text,timestamptz,uuid,text)'::regprocedure
  ))) = 0,
  'the read RPC contains no per-message loop'
);
select lives_ok(
  $$select public.mark_conversation_read_v2(
    'club:82000000-0000-0000-0000-000000000001',
    '2026-08-12 09:00:00+00',
    '85000000-0000-0000-0000-000000000001', 'board'
  )$$,
  'a club Board lane can be marked independently'
);
select is(
  (select count(*) from public.chat_v2_read_state
   where viewer_id = '81000000-0000-0000-0000-000000000001'
     and thread_id = 'club:82000000-0000-0000-0000-000000000001'
     and read_scope = 'board'),
  1::bigint,
  'the scoped server read boundary is persisted'
);
insert into chat_v2_test_state values (
  'summary_after_read', public.get_conversation_summaries_v2(50, null, null)
);
select is(
  (select (item->>'unread_board_count')::integer
   from jsonb_array_elements((select value->'items' from chat_v2_test_state where key = 'summary_after_read')) as item
   where item->>'thread_type' = 'club'),
  0,
  'marking Board read clears only the Board server count'
);
select is(
  (select (item->>'unread_chat_count')::integer
   from jsonb_array_elements((select value->'items' from chat_v2_test_state where key = 'summary_after_read')) as item
   where item->>'thread_type' = 'club'),
  1,
  'the unread Chat lane survives a Board read'
);

reset role;
insert into chat_v2_test_state values (
  'before_poll_vote_delete',
  jsonb_build_object('cursor', (select max(change_id) from public.chat_v2_change_log
    where thread_id = 'club:82000000-0000-0000-0000-000000000001'))
);
delete from public.club_channel_poll_votes
where message_id = '85000000-0000-0000-0000-000000000002'
  and voter_auth_id = '81000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
select ok(
  exists (
    select 1
    from jsonb_array_elements(public.get_messages_since_v2(
      'club:82000000-0000-0000-0000-000000000001',
      (select (value->>'cursor')::bigint from chat_v2_test_state
       where key = 'before_poll_vote_delete'),
      200
    )->'changes') as change
    where change->>'record_type' = 'poll_vote'
      and change->>'operation' = 'DELETE'
      and change->>'message_id' = '85000000-0000-0000-0000-000000000002'
  ),
  'poll-vote changes use the same participant-scoped delta stream'
);

reset role;
insert into chat_v2_test_state values (
  'before_delete', jsonb_build_object('cursor', (select max(change_id) from public.chat_v2_change_log
    where thread_id = 'group:82000000-0000-0000-0000-000000000101'))
);
delete from public.group_messages where id = '83000000-0000-0000-0000-000000000055';
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
insert into chat_v2_test_state values (
  'delta', public.get_messages_since_v2(
    'group:82000000-0000-0000-0000-000000000101',
    (select (value->>'cursor')::bigint from chat_v2_test_state where key = 'before_delete'),
    200
  )
);
select ok(
  exists (
    select 1 from jsonb_array_elements((select value->'changes' from chat_v2_test_state where key = 'delta')) as change
    where change->>'message_id' = '83000000-0000-0000-0000-000000000055'
      and change->>'operation' = 'DELETE'
  ),
  'delta reconciliation includes deletes made while disconnected'
);
select cmp_ok(
  (select (value->>'next_change_id')::bigint from chat_v2_test_state where key = 'delta'),
  '>',
  (select (value->>'cursor')::bigint from chat_v2_test_state where key = 'before_delete'),
  'delta reconciliation advances its durable cursor'
);

select lives_ok(
  $$insert into public.direct_messages (
    id, sender_id, receiver_id, content, created_at, delivered_at
  ) values (
    '88000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000003',
    'Released v1 insert', now(), now()
  )$$,
  'the released direct-table insert contract still works'
);
select is(
  (select count(*) from public.direct_messages where id = '88000000-0000-0000-0000-000000000001'),
  1::bigint,
  'the released v1 insert lands in the unchanged canonical table'
);
select ok(
  to_regclass('public.direct_messages') is not null
  and to_regclass('public.group_messages') is not null
  and to_regclass('public.club_channel_messages') is not null
  and to_regclass('public.club_inbox_messages') is not null,
  'all four released message tables remain present'
);
select ok(
  exists (select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'direct_messages'
      and column_name = 'read_at')
  and exists (select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'club_inbox_messages'
      and column_name = 'seen_at'),
  'released receipt columns remain present'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.chat_v2_change_log'::regclass)
  and (select relrowsecurity from pg_class where oid = 'public.chat_v2_read_state'::regclass),
  'new Chat v2 state is protected by RLS'
);
select ok(
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'chat_v2_change_log'
  ),
  'Realtime publishes the additive participant-scoped v2 journal'
);

select * from finish();
rollback;
