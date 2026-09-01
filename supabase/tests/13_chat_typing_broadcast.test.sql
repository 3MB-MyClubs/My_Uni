begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password)
values
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'typing-student@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'typing-peer@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'typing-outsider@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'typing-board@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'typing-club@ku.edu.tr', ''),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-0000-0000-000000000006', 'authenticated', 'authenticated', 'typing-removed@ku.edu.tr', '');

insert into public.profiles (id, email, full_name)
values
  ('91000000-0000-0000-0000-000000000001', 'typing-student@ku.edu.tr', 'Typing Student'),
  ('91000000-0000-0000-0000-000000000002', 'typing-peer@ku.edu.tr', 'Typing Peer'),
  ('91000000-0000-0000-0000-000000000003', 'typing-outsider@ku.edu.tr', 'Typing Outsider'),
  ('91000000-0000-0000-0000-000000000004', 'typing-board@ku.edu.tr', 'Typing Board'),
  ('91000000-0000-0000-0000-000000000006', 'typing-removed@ku.edu.tr', 'Typing Removed');

insert into public.clubs (id, name, short_name)
values ('92000000-0000-0000-0000-000000000001', 'Typing Club', 'TYPE');

insert into public.club_followers (club_id, profile_id, role)
values
  ('92000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', 'member'),
  ('92000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000004', 'board_member');

insert into public.club_auth_accounts (auth_user_id, club_id)
values ('91000000-0000-0000-0000-000000000005', '92000000-0000-0000-0000-000000000001');

insert into public.group_chats (id, creator_id, admin_ids, custom_name)
values (
  '92000000-0000-0000-0000-000000000101',
  '91000000-0000-0000-0000-000000000001',
  '{91000000-0000-0000-0000-000000000001}',
  'Typing group'
);
insert into public.group_chat_members (group_id, user_id, position)
values
  ('92000000-0000-0000-0000-000000000101', '91000000-0000-0000-0000-000000000001', 0),
  ('92000000-0000-0000-0000-000000000101', '91000000-0000-0000-0000-000000000002', 1);

insert into public.club_inbox_threads (id, club_id, profile_id)
values (
  '92000000-0000-0000-0000-000000000201',
  '92000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000001'
);

select has_function(
  'private', 'can_use_chat_typing_topic', array['text', 'text', 'boolean'],
  'typing authorization uses one private boolean helper'
);
select ok(
  has_function_privilege(
    'authenticated',
    'private.can_use_chat_typing_topic(text,text,boolean)',
    'EXECUTE'
  ),
  'authenticated Realtime authorization can execute the helper'
);
select ok(
  not has_function_privilege(
    'anon',
    'private.can_use_chat_typing_topic(text,text,boolean)',
    'EXECUTE'
  ),
  'anonymous clients cannot execute the typing helper'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000001', true);

select ok(private.can_use_chat_typing_topic(
  'chat:typing:dm:91000000-0000-0000-0000-000000000001|91000000-0000-0000-0000-000000000002',
  'broadcast', false
), 'a DM participant can receive typing events');
select ok(private.can_use_chat_typing_topic(
  'chat:typing:dm:91000000-0000-0000-0000-000000000001|91000000-0000-0000-0000-000000000002',
  'broadcast', true
), 'an unblocked DM participant can emit typing events');
select ok(private.can_use_chat_typing_topic(
  'chat:typing:group:92000000-0000-0000-0000-000000000101',
  'broadcast', false
), 'a group member can receive typing events');
select ok(private.can_use_chat_typing_topic(
  'chat:typing:group:92000000-0000-0000-0000-000000000101',
  'broadcast', true
), 'a group member can emit typing events');
select ok(private.can_use_chat_typing_topic(
  'chat:typing:club:92000000-0000-0000-0000-000000000001',
  'broadcast', false
), 'a club member can receive typing events');
select ok(not private.can_use_chat_typing_topic(
  'chat:typing:club:92000000-0000-0000-0000-000000000001',
  'broadcast', true
), 'a read-only club member cannot emit typing events');
select ok(private.can_use_chat_typing_topic(
  'chat:typing:clubdm:92000000-0000-0000-0000-000000000201',
  'broadcast', true
), 'the student in a private club inbox can emit typing events');

select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000004', true);
select ok(private.can_use_chat_typing_topic(
  'chat:typing:club:92000000-0000-0000-0000-000000000001',
  'broadcast', true
), 'a club board member can emit typing events');
select ok(private.can_use_chat_typing_topic(
  'chat:typing:clubdm:92000000-0000-0000-0000-000000000201',
  'broadcast', false
), 'a board member can receive private club-inbox typing events');
select ok(private.can_use_chat_typing_topic(
  'chat:typing:clubdm:92000000-0000-0000-0000-000000000201',
  'broadcast', true
), 'a board member can emit private club-inbox typing events');

select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000005', true);
select ok(private.can_use_chat_typing_topic(
  'chat:typing:club:92000000-0000-0000-0000-000000000001',
  'broadcast', true
), 'the linked club account can emit club typing events');
select ok(private.can_use_chat_typing_topic(
  'chat:typing:clubdm:92000000-0000-0000-0000-000000000201',
  'broadcast', true
), 'the linked club account can emit private inbox typing events');

select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000003', true);
select ok(not private.can_use_chat_typing_topic(
  'chat:typing:group:92000000-0000-0000-0000-000000000101',
  'broadcast', false
), 'an outsider cannot receive group typing events');
select ok(not private.can_use_chat_typing_topic(
  'chat:typing:clubdm:92000000-0000-0000-0000-000000000201',
  'broadcast', true
), 'an outsider cannot emit private inbox typing events');

select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000006', true);
select ok(not private.can_use_chat_typing_topic(
  'chat:typing:group:92000000-0000-0000-0000-000000000101',
  'broadcast', false
), 'a removed group member cannot receive typing events');

select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000001', true);
select ok(not private.can_use_chat_typing_topic(
  'chat:typing:not-a-thread', 'broadcast', false
), 'a malformed thread topic is denied');
select ok(not private.can_use_chat_typing_topic(
  'chat:typing:group:not-a-uuid', 'broadcast', false
), 'a malformed group topic is denied');
select ok(not private.can_use_chat_typing_topic(
  'other:typing:group:92000000-0000-0000-0000-000000000101',
  'broadcast', false
), 'a non-typing topic is denied');
select ok(not private.can_use_chat_typing_topic(
  'chat:typing:group:92000000-0000-0000-0000-000000000101',
  'presence', false
), 'a non-broadcast extension is denied');

reset role;
insert into public.user_blocks (blocker_id, blocked_id)
values ('91000000-0000-0000-0000-000000000002', '91000000-0000-0000-0000-000000000001');
set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000001', true);
select ok(private.can_use_chat_typing_topic(
  'chat:typing:dm:91000000-0000-0000-0000-000000000001|91000000-0000-0000-0000-000000000002',
  'broadcast', false
), 'blocked DM participants may still pass the receive membership check');
select ok(not private.can_use_chat_typing_topic(
  'chat:typing:dm:91000000-0000-0000-0000-000000000001|91000000-0000-0000-0000-000000000002',
  'broadcast', true
), 'a blocked DM participant cannot emit typing events');

reset role;
select is(
  (select count(*) from pg_policies
   where schemaname = 'realtime' and tablename = 'messages'
     and policyname in ('chat_typing_broadcast_receive', 'chat_typing_broadcast_send')),
  2::bigint,
  'Realtime has exactly the two typing Broadcast policies'
);
select is(
  (select count(*) from pg_policies
   where schemaname = 'realtime' and tablename = 'messages'
     and policyname in ('authenticated_app_presence_read', 'authenticated_app_presence_track')),
  2::bigint,
  'the existing app Presence policies remain installed'
);

select * from finish();
rollback;
