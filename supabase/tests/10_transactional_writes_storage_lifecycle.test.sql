begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

insert into auth.users(instance_id,id,aud,role,email,encrypted_password) values
('00000000-0000-0000-0000-000000000000','81000000-0000-4000-8000-000000000001','authenticated','authenticated','tx-manager@example.test',''),
('00000000-0000-0000-0000-000000000000','81000000-0000-4000-8000-000000000002','authenticated','authenticated','tx-other@example.test','');
insert into public.profiles(id,email,full_name) values
('81000000-0000-4000-8000-000000000001','tx-manager@example.test','Before'),
('81000000-0000-4000-8000-000000000002','tx-other@example.test','Other');
insert into public.clubs(id,name) values
('82000000-0000-4000-8000-000000000001','Transactional Club');
insert into public.club_auth_accounts(auth_user_id,club_id) values
('81000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001');
insert into public.majors(id,name,sort_order,is_active) values
('83000000-0000-4000-8000-000000000001','Transactional Major',9001,true),
('83000000-0000-4000-8000-000000000002','Transactional Minor',9002,true);
insert into public.academic_years(id,name,sort_order,is_active) values
('84000000-0000-4000-8000-000000000001','Transactional Year',9001,true);
insert into public.interests(id,name,sort_order,is_active) values
('85000000-0000-4000-8000-000000000001','Transactional Interest',9001,true);

select has_function('public','update_profile_v2',array['text','text','uuid','uuid','uuid[]','uuid[]','uuid[]'],
  'atomic profile RPC exists');
select ok(not (select prosecdef from pg_proc where oid='public.update_profile_v2(text,text,uuid,uuid,uuid[],uuid[],uuid[])'::regprocedure),
  'profile RPC is security invoker');

set local role authenticated;
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
create temporary table tx_profile_result as select public.update_profile_v2(
  'After','Bio','83000000-0000-4000-8000-000000000001','84000000-0000-4000-8000-000000000001',
  array['85000000-0000-4000-8000-000000000001','85000000-0000-4000-8000-000000000001']::uuid[],
  array[]::uuid[],array['83000000-0000-4000-8000-000000000002']::uuid[]
) result;
select is((select result->>'full_name' from tx_profile_result),'After','profile response is final state');
select is((select count(*) from public.student_interests where user_id='81000000-0000-4000-8000-000000000001'),1::bigint,
  'duplicate relationship IDs are deduplicated');
select throws_ok($$select public.update_profile_v2('Broken','',null,null,array['85000000-0000-4000-8000-000000000099']::uuid[],array[]::uuid[],array[]::uuid[])$$,
  '23503','Invalid interest','invalid relationship fails');
select is((select full_name from public.profiles where id='81000000-0000-4000-8000-000000000001'),'After',
  'invalid relationship rolls back scalar state');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000002',true);
select public.update_profile_v2('Other changed','',null,null,array[]::uuid[],array[]::uuid[],array[]::uuid[]);
select is((select full_name from public.profiles where id='81000000-0000-4000-8000-000000000001'),'After',
  'caller cannot target another profile');

select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select is((public.create_club_post_transactional_v2(
  '86000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001','Atomic post',
  'club_posts/82000000-0000-4000-8000-000000000001/86000000-0000-4000-8000-000000000001/cover.jpg',null,false,array[]::uuid[],
  'Question','["A","B"]'::jsonb
)).id,'86000000-0000-4000-8000-000000000001'::uuid,'post creation accepts reserved ID');
select is((select count(*) from public.polls where post_id='86000000-0000-4000-8000-000000000001'),1::bigint,
  'post and poll commit together');
reset role;
select is((select count(*) from public.notification_outbox_v2 where event_key='club_post:86000000-0000-4000-8000-000000000001'),1::bigint,
  'notification enqueue commits once');
set local role authenticated;
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.create_club_post_transactional_v2(
  '86000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001','Atomic post',null,null,false,array[]::uuid[],'Question','["A","B"]'::jsonb
)$$,'same post ID is idempotent');
select is((select count(*) from public.club_posts where id='86000000-0000-4000-8000-000000000001'),1::bigint,
  'retry does not duplicate post');
reset role;
select is((select count(*) from public.notification_outbox_v2 where event_key='club_post:86000000-0000-4000-8000-000000000001'),1::bigint,
  'retry does not duplicate notification');
set local role authenticated;
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.create_club_post_transactional_v2(
  '86000000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000001','Bad poll',null,null,false,array[]::uuid[],'Question','["A","A"]'::jsonb
)$$,'22023','Invalid poll','invalid poll rejects transaction');
select is((select count(*) from public.club_posts where id='86000000-0000-4000-8000-000000000002'),0::bigint,
  'poll validation failure rolls back post');

select is((public.create_club_event_transactional_v2(
  '87000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001','Atomic event','','',current_date,
  now(),now()+interval '1 hour',null,null,array[]::text[],null,null,'[]'::jsonb
)).id,'87000000-0000-4000-8000-000000000001'::uuid,'event creation succeeds');
select lives_ok($$select public.create_club_event_transactional_v2(
  '87000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001','Atomic event','','',current_date,
  now(),now()+interval '1 hour',null,null,array[]::text[],null,null,'[]'::jsonb
)$$,'same event ID is idempotent');
select is((select count(*) from public.events where id='87000000-0000-4000-8000-000000000001'),1::bigint,
  'event retry does not duplicate');

select is(public.delete_club_post_transactional_v2(
  '86000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001')->>'deleted','true',
  'database delete succeeds independently of Storage');
select is((select count(*) from public.club_posts where id='86000000-0000-4000-8000-000000000001'),0::bigint,
  'deleted post is no longer visible');
reset role;
select is((select count(*) from public.storage_cleanup_queue_v2 where entity_id='86000000-0000-4000-8000-000000000001'),1::bigint,
  'failed or deferred Storage deletion remains durable');

select * from finish();
rollback;
