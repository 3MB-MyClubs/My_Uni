begin;
create extension if not exists pgtap with schema extensions;
select plan(19);
create temporary table notification_test_baseline as select count(*) as total from public.notifications;

insert into auth.users(id) values ('ffffffff-ffff-4fff-8fff-ffffffffffff');
insert into public.profiles(id,email,full_name)
values ('ffffffff-ffff-4fff-8fff-ffffffffffff','notification.actor@example.test','Actor');
insert into public.clubs(id,name)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Large Club');

insert into auth.users(id)
select md5('notification-recipient-'||i)::uuid from generate_series(1,1000) i;
insert into public.profiles(id,email,full_name)
select md5('notification-recipient-'||i)::uuid,
  'notification-recipient-'||i||'@example.test', 'Recipient '||i
from generate_series(1,1000) i;
insert into public.club_followers(club_id,profile_id)
select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', md5('notification-recipient-'||i)::uuid
from generate_series(1,1000) i;
select set_config('request.jwt.claim.sub',md5('notification-recipient-1')::uuid::text,true);
insert into public.push_devices(user_id,fcm_token,platform)
select md5('notification-recipient-1')::uuid, token, 'android'
from unnest(array['notification-device-a','notification-device-b']) token;

select set_config('request.jwt.claims',
  '{"sub":"ffffffff-ffff-4fff-8fff-ffffffffffff","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub','ffffffff-ffff-4fff-8fff-ffffffffffff',true);
select lives_ok($$
  select private.enqueue_notification_outbox_v2(
    'test:large-club','club_post','ffffffff-ffff-4fff-8fff-ffffffffffff',
    'post','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','club_followers',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','{}','Large Club posted',
    'Large Club shared a post.','{"clubName":"Large Club","content":"Post"}',null
  )
$$, 'one logical event enqueues');
select is((select count(*) from public.notification_outbox_v2 where event_key='test:large-club'),1::bigint,
  'one outbox row is durable');
select is((select count(*) from public.notifications),(select total from notification_test_baseline),
  'enqueue performs no synchronous recipient inserts');
select lives_ok($$
  select private.enqueue_notification_outbox_v2(
    'test:large-club','club_post','ffffffff-ffff-4fff-8fff-ffffffffffff',
    'post','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','club_followers',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','{}','Large Club posted',
    'Large Club shared a post.','{}',null
  )
$$, 'duplicate logical enqueue is idempotent');
select is((select count(*) from public.notification_outbox_v2 where event_key='test:large-club'),1::bigint,
  'idempotency key remains unique');

select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.sub','',true);
create temporary table notification_test_claim as
select public.claim_notification_outbox_v2('worker-a',90,8) claim;
select ok((select claim is not null from notification_test_claim),'first worker claims event');
select is(public.claim_notification_outbox_v2('worker-b',90,8),null::jsonb,
  'second worker cannot claim active lease');
update public.notification_outbox_v2 set lease_expires_at=clock_timestamp()-interval '1 second'
where event_key='test:large-club';
create temporary table notification_test_reclaim as
select public.claim_notification_outbox_v2('worker-b',90,8) claim;
select isnt((select claim->>'lease_token' from notification_test_reclaim),
  (select claim->>'lease_token' from notification_test_claim),'expired lease receives a new token');

select is(
  (public.expand_notification_outbox_v2(
    ((select claim->>'id' from notification_test_reclaim)::uuid),
    ((select claim->>'lease_token' from notification_test_reclaim)::uuid),250
  )->>'recipients')::integer,250,'first expansion is bounded to 250');

do $do$
declare v_claim jsonb;
begin
  for i in 1..3 loop
    v_claim:=public.claim_notification_outbox_v2('worker-loop',90,8);
    perform public.expand_notification_outbox_v2(
      (v_claim->>'id')::uuid,(v_claim->>'lease_token')::uuid,250);
  end loop;
end $do$;


select is((select count(*) from public.notifications where pipeline_version=2),1000::bigint,
  'large audience creates exactly one canonical row per recipient');
select is((select recipient_count from public.notification_outbox_v2 where event_key='test:large-club'),1000,
  'recipient accounting is exact');
select is((select batch_count from public.notification_outbox_v2 where event_key='test:large-club'),4,
  '1000 recipients require four bounded batches');
select is((select status from public.notification_outbox_v2 where event_key='test:large-club'),'expanded',
  'outbox completes after final recipient batch');
select is((select count(*) from public.notification_deliveries_v2),2::bigint,
  'one delivery row is created per enabled device');
select is((select count(*) from net.http_request_queue),0::bigint,
  'v2 canonical rows do not fire legacy pg_net webhooks');

-- Eliminate clock-resolution races between insert defaults and worker eligibility.
update public.notification_deliveries_v2 set next_attempt_at=clock_timestamp()-interval '1 second'
where outbox_id=(select id from public.notification_outbox_v2 where event_key='test:large-club');
create temporary table notification_test_deliveries as
select * from public.claim_notification_deliveries_v2('delivery-a',250,90,8);
select is((select count(*) from notification_test_deliveries),2::bigint,
  'delivery worker claims both devices in one bounded claim');
select is((select count(*) from public.claim_notification_deliveries_v2('delivery-b',250,90,8)),0::bigint,
  'a second delivery worker cannot claim active leases');
select public.complete_notification_delivery_v2(
  delivery_id,lease_token,case when row_number() over(order by device_id)=1 then 'delivered' else 'retryable' end,
  case when row_number() over(order by device_id)=1 then 200 else 503 end,
  case when row_number() over(order by device_id)=1 then null else 'fcm_503' end,null,null,8)
from notification_test_deliveries;
select is((select count(*) from public.notification_deliveries_v2 where status='delivered'),1::bigint,
  'successful device remains delivered after partial failure');
select is((select count(*) from public.notification_deliveries_v2 where status='retryable'),1::bigint,
  'transiently failed device remains independently retryable');

select * from finish();
rollback;
