-- LOCAL TEST DATA ONLY. Always rolls back fixtures and candidate indexes.
\set ON_ERROR_STOP on
begin;
-- Remove candidate indexes only inside this rolled-back local transaction,
-- so rerunning after migration still produces a true before/after comparison.
drop index if exists public.events_page_order_v1_idx;
drop index if exists public.events_club_page_order_v1_idx;
drop index if exists public.profiles_directory_order_v1_idx;
insert into auth.users(instance_id,id,aud,role,email,encrypted_password)
select '00000000-0000-0000-0000-000000000000',
 ('f2100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'authenticated','authenticated','benchmark'||n||'@ku.edu.tr','' from generate_series(0,10000) n;
insert into public.profiles(id,email,full_name)
select ('f2100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'benchmark'||n||'@ku.edu.tr','Performance Student '||lpad(n::text,5,'0') from generate_series(0,10000) n;
insert into public.clubs(id,name) values ('f2400000-0000-0000-0000-000000000001','Performance Benchmark Club');
insert into public.events(id,club_id,title,description,event_date,starts_at,ends_at)
select ('f2500000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'f2400000-0000-0000-0000-000000000001','Benchmark event '||n,repeat('Campus event description. ',12),current_date+1,
 now()+n*interval '1 minute',now()+n*interval '1 minute'+interval '2 hours' from generate_series(1,20000) n;
analyze public.events;
analyze public.profiles;
set local role authenticated;
select set_config('request.jwt.claim.sub','f2100000-0000-0000-0000-000000000000',true);
select 'before: upcoming events' as benchmark;
explain (analyze,buffers) select public.get_content_page_v1(p_from=>now(),p_until=>now()+interval '2 years');
select 'before: directory' as benchmark;
explain (analyze,buffers) select public.get_directory_page_v1();
select 'before: club history' as benchmark;
explain (analyze,buffers) select public.get_content_page_v1(p_club_id=>'f2400000-0000-0000-0000-000000000001',p_descending=>true);
select 'serialized payload comparison, no media downloads' as benchmark,
  octet_length(public.get_content_page_v1(p_club_id=>'f2400000-0000-0000-0000-000000000001')::text) as page_25_bytes,
  (select octet_length(jsonb_agg(to_jsonb(e))::text) from
    (select * from public.events where club_id='f2400000-0000-0000-0000-000000000001' order by starts_at limit 500) e) as old_500_events_bytes;
reset role;
create index if not exists events_page_order_v1_idx on public.events(starts_at,id);
create index if not exists events_club_page_order_v1_idx on public.events(club_id,starts_at,id);
create index if not exists profiles_directory_order_v1_idx on public.profiles(public.directory_fold_v1(full_name),id) where role='student';
analyze public.events;
analyze public.profiles;
set local role authenticated;
select 'after: upcoming events' as benchmark;
explain (analyze,buffers) select public.get_content_page_v1(p_from=>now(),p_until=>now()+interval '2 years');
select 'after: directory' as benchmark;
explain (analyze,buffers) select public.get_directory_page_v1();
select 'after: club history' as benchmark;
explain (analyze,buffers) select public.get_content_page_v1(p_club_id=>'f2400000-0000-0000-0000-000000000001',p_descending=>true);
rollback;
