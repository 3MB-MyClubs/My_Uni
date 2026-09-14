-- Local regression coverage; never run these fixture writes against production.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(instance_id,id,aud,role,email,encrypted_password)
select '00000000-0000-0000-0000-000000000000'::uuid,
  ('a1000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
  'authenticated','authenticated','security-' || n || '@example.test',''
from generate_series(1,3) n;
insert into public.profiles(id,email,full_name)
select ('a1000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
  'security-' || n || '@example.test','Security fixture ' || n
from generate_series(1,3) n;
insert into public.clubs(id,name,tes) values
('a2000000-0000-4000-8000-000000000001','Security ordinary club',false),
('a2000000-0000-4000-8000-000000000002','Security hidden test club',true);
insert into public.club_auth_accounts(auth_user_id,club_id) values
('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001');

insert into public.club_posts(id,club_id,content,audience)
select ('a3000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
 'a2000000-0000-4000-8000-000000000001','Audience fixture',audience
from (values (1,'everyone'),(2,'followers'),(3,'board')) a(n,audience);
insert into public.events(id,club_id,title,event_date,starts_at,is_public,audience)
select ('a4000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
 'a2000000-0000-4000-8000-000000000001','Audience fixture',current_date,now(),false,audience
from (values (1,'everyone'),(2,'followers'),(3,'board')) a(n,audience);
insert into public.club_posts(id,club_id,content) values
('a3000000-0000-4000-8000-000000000004','a2000000-0000-4000-8000-000000000002','Hidden test post');
insert into public.events(id,club_id,title,event_date,starts_at) values
('a4000000-0000-4000-8000-000000000004','a2000000-0000-4000-8000-000000000002','Hidden test event',current_date,now());

set local role anon;
select is((select count(*) from public.club_posts where id::text like 'a3000000-%'),1::bigint,
 'anonymous readers see everyone only; test-club isolation survives');
select is((select count(*) from public.events where id::text like 'a4000000-%'),1::bigint,
 'legacy visible events remain visible even with is_public=false');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000002',true);
select throws_ok($$insert into public.club_followers(club_id,profile_id,role) values
 ('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002','board_member')$$,
 '42501',null,'self-assigned board insertion is denied');
select lives_ok($$insert into public.club_followers(club_id,profile_id,role) values
 ('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002','member')$$,
 'released explicit member follow still succeeds');
select is((select count(*) from public.club_posts where id::text like 'a3000000-%'),2::bigint,
 'followers see everyone and followers, not board or test-club posts');
select is((select count(*) from public.events where id::text like 'a4000000-%'),2::bigint,
 'followers see everyone and followers events');
update public.club_followers set role='board_member'
 where club_id='a2000000-0000-4000-8000-000000000001'
 and profile_id='a1000000-0000-4000-8000-000000000002';
select is((select role from public.club_followers
 where club_id='a2000000-0000-4000-8000-000000000001'
 and profile_id='a1000000-0000-4000-8000-000000000002'),'member',
 'self-promotion update cannot change the role');

select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
select lives_ok($$update public.club_followers set role='board_member',role_title='Secretary'
 where club_id='a2000000-0000-4000-8000-000000000001'
 and profile_id='a1000000-0000-4000-8000-000000000002'$$,
 'released club-manager role and title update still succeeds');
select is((select role from public.club_followers
 where club_id='a2000000-0000-4000-8000-000000000001'
 and profile_id='a1000000-0000-4000-8000-000000000002'),'board_member',
 'authorized promotion is persisted');
select throws_ok($$update public.club_followers
 set profile_id='a1000000-0000-4000-8000-000000000003'
 where club_id='a2000000-0000-4000-8000-000000000001'
 and profile_id='a1000000-0000-4000-8000-000000000002'$$,
 '42501',null,'manager cannot reassign a membership identity');
select is((select count(*) from public.club_posts where id::text like 'a3000000-%'),4::bigint,
 'linked club manager sees own audiences and retains legacy test-feed access');

select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.club_posts where id::text like 'a3000000-%'),3::bigint,
 'promoted board member sees board posts');
select is((select count(*) from public.events where id::text like 'a4000000-%'),3::bigint,
 'promoted board member sees board events');
select lives_ok($$delete from public.club_followers
 where club_id='a2000000-0000-4000-8000-000000000001'
 and profile_id='a1000000-0000-4000-8000-000000000002'$$,
 'released unfollow still succeeds');
select is((select count(*) from public.club_posts where id::text like 'a3000000-%'),1::bigint,
 'unfollow immediately removes restricted post access');
select lives_ok($$insert into public.club_followers(club_id,profile_id) values
 ('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002')$$,
 'older follow payload omitting role defaults to member');

-- Simulate another legacy permissive policy: it must not bypass audience RLS.
reset role;
create policy "Security test broad legacy posts" on public.club_posts
 for select to anon using (true);
create policy "Security test broad legacy events" on public.events
 for select to anon using (true);
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select is((select count(*) from public.club_posts
 where club_id='a2000000-0000-4000-8000-000000000001'),1::bigint,
 'additional permissive post policy cannot expose restricted audiences');
select is((select count(*) from public.events
 where club_id='a2000000-0000-4000-8000-000000000001'),1::bigint,
 'additional permissive event policy cannot expose restricted audiences');

select * from finish();
rollback;
