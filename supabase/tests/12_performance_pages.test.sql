begin;
create extension if not exists pgtap with schema extensions;
select plan(28);
insert into auth.users(instance_id,id,aud,role,email,encrypted_password)
select '00000000-0000-0000-0000-000000000000',
 ('f1100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'authenticated','authenticated','perf'||n||'@ku.edu.tr',''
from generate_series(0,125) n;
insert into public.majors(id,name) values ('f1200000-0000-0000-0000-000000000001','Performance & Engineering');
insert into public.academic_years(id,name) values ('f1300000-0000-0000-0000-000000000001','Performance Year');
insert into public.profiles(id,email,full_name,major_id,academic_year_id)
select ('f1100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'perf'||n||'@ku.edu.tr','zzPerformance Student '||lpad(n::text,3,'0'),
 'f1200000-0000-0000-0000-000000000001','f1300000-0000-0000-0000-000000000001'
from generate_series(0,125) n;
insert into public.clubs(id,name,description)
values ('f1400000-0000-0000-0000-000000000001','Performance Club','Fixture club');
insert into public.events(id,club_id,title,event_date,starts_at,ends_at,tags)
select ('f1500000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'f1400000-0000-0000-0000-000000000001','Performance event '||n,current_date+1,
 now()+interval '1 day'+(n/2)*interval '1 minute',now()+interval '2 days',array['Performance tag']
from generate_series(1,550) n;
insert into public.club_posts(id,club_id,author_id,content)
values ('f1600000-0000-0000-0000-000000000001','f1400000-0000-0000-0000-000000000001',
'f1100000-0000-0000-0000-000000000000','Performance post');

insert into public.club_followers(club_id,profile_id)
select 'f1400000-0000-0000-0000-000000000001',('f1100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(0,125) n;
set local role authenticated;
select set_config('request.jwt.claim.sub','f1100000-0000-0000-0000-000000000000',true);
select is(public.directory_fold_v1('İSTANBUL'),'istanbul','Turkish dotted capital I is searchable');
select is(jsonb_array_length(public.get_directory_page_v1(p_query=>'Student 125')->'items'),1,'search reaches beyond the old 100-profile limit');
select is(jsonb_array_length(public.get_directory_page_v1(p_query=>'zzPerformance')->'items'),25,'directory first page is bounded');
select is(jsonb_array_length(public.get_directory_page_v1(p_query=>'zzPerformance',p_limit=>500)->'items'),50,'directory limit is capped at 50');
select is(jsonb_array_length(public.get_directory_page_v1(p_query=>'zzPerformance',p_filters=>'{"majors":["Performance and Engineering"],"years":["Performance Year"]}')->'items'),25,'major aliases and year filters work server-side');
select ok(not (public.get_directory_page_v1(p_query=>'Student 125')->'items'->0 ? 'email'),'directory projection contains no email');
select is(jsonb_array_length(public.get_directory_page_v1(p_query=>'zzPerformance',p_filters=>'{"years":["Absent"]}')->'items'),0,'empty filtered results are authoritative');
create temporary table performance_first as select public.get_directory_page_v1(p_query=>'zzPerformance') as page;
select isnt((select page->'items'->0->>'id' from performance_first),
 public.get_directory_page_v1(p_query=>'zzPerformance',p_cursor=>(select page->'next_cursor' from performance_first))->'items'->0->>'id',
 'next page advances past the first page');
select is(jsonb_array_length(public.get_directory_page_v1(p_query=>'zzPerformance',p_cursor=>'{"rank":1,"name":"zzperformance student 125","id":"f1100000-0000-0000-0000-000000000125"}')->'items'),0,'final cursor ends the directory');
select is(jsonb_array_length(public.get_content_page_v1(p_club_id=>'f1400000-0000-0000-0000-000000000001')->'items'),25,'event page is bounded');
select is(jsonb_array_length(public.get_content_page_v1(p_club_id=>'f1400000-0000-0000-0000-000000000001',p_query=>'event 550')->'items'),1,'event search reaches beyond the old 500-event cap');
select is(public.get_content_page_v1(p_club_id=>'f1400000-0000-0000-0000-000000000001',p_descending=>true)->'items'->0->>'title','Performance event 550','descending history starts with newest event');
select is(jsonb_array_length(public.get_content_page_v1(p_club_id=>'f1400000-0000-0000-0000-000000000001',p_until=>now())->'items'),0,'date window excludes future events');
select ok(public.get_event_categories_v1(now(),now()+interval '3 days') ? 'Performance tag','facets include tags beyond a single page');
select is(jsonb_array_length(public.get_content_page_v1(p_kind=>'posts',p_club_id=>'f1400000-0000-0000-0000-000000000001')->'items'),1,'club post page remains available');
select is(jsonb_array_length(public.get_club_members_page_v1('f1400000-0000-0000-0000-000000000001')->'items'),25,'member directory is paged');
select is(jsonb_array_length(public.get_club_members_page_v1('f1400000-0000-0000-0000-000000000001',p_query=>'Student 125')->'items'),1,'member search reaches all members');
select is(jsonb_array_length(public.get_club_members_page_v1('f1400000-0000-0000-0000-000000000001',p_limit=>200)->'items'),50,'member reads are capped at 50');
select throws_ok('select public.get_admin_overview_v1()','42501','Platform administrator required','ordinary students cannot request admin aggregates');

select is((public.get_club_content_counts_v1('f1400000-0000-0000-0000-000000000001')->>'events')::integer,550,'profile totals are independent of loaded pages');
create temporary table performance_events_first as select public.get_content_page_v1(p_club_id=>'f1400000-0000-0000-0000-000000000001') as page;
reset role;
-- A row inserted before the cursor must not shift or repeat an existing page.
insert into public.events(id,club_id,title,event_date,starts_at,ends_at)
values ('f1500000-0000-0000-0000-000000999999','f1400000-0000-0000-0000-000000000001','Inserted before cursor',current_date,now(),now()+interval '2 days');
delete from public.events where id='f1500000-0000-0000-0000-000000000549';
insert into public.user_blocks(blocker_id,blocked_id) values
('f1100000-0000-0000-0000-000000000124','f1100000-0000-0000-0000-000000000000');
set local role authenticated;
select is(jsonb_array_length(public.get_directory_page_v1(p_query=>'Student 124')->'items'),0,'recipient-side blocks also hide search results');
create temporary table performance_seen(id text);
do $test$
declare page jsonb := (select p.page from performance_events_first p); cursor_value jsonb; i integer;
begin
  for i in 1..30 loop
    insert into performance_seen select r->>'id' from jsonb_array_elements(page->'items') r;
    cursor_value := page->'next_cursor';
    exit when cursor_value is null or cursor_value='null'::jsonb;
    page := public.get_content_page_v1(p_club_id=>'f1400000-0000-0000-0000-000000000001',p_cursor=>cursor_value);
  end loop;
end $test$;
select is((select count(*) from performance_seen),549::bigint,'cursor traverses all surviving original events despite inserts and deletes');
select is((select count(distinct id) from performance_seen),549::bigint,'tied timestamps and inserts never duplicate events');
select is((select count(*) from performance_seen where id='f1500000-0000-0000-0000-000000999999'),0::bigint,'an insertion before the cursor is discovered on refresh');
insert into public.user_blocks(blocker_id,blocked_id) values
('f1100000-0000-0000-0000-000000000000','f1100000-0000-0000-0000-000000000125');
select is(jsonb_array_length(public.get_directory_page_v1(p_query=>'Student 125')->'items'),0,'blocked students cannot reappear in server search');
insert into public.club_blocks(blocker_id,club_id) values
('f1100000-0000-0000-0000-000000000000','f1400000-0000-0000-0000-000000000001');
select is(jsonb_array_length(public.get_content_page_v1(p_club_id=>'f1400000-0000-0000-0000-000000000001')->'items'),0,'blocked club content stays hidden');
select is(jsonb_array_length(public.get_directory_page_v1(p_kind=>'clubs',p_query=>'Performance Club')->'items'),0,'blocked clubs stay hidden in discovery');
set local role anon;
select throws_ok('select public.get_directory_page_v1()','42501',null,'anonymous callers cannot execute directory API');
select * from finish();
rollback;
