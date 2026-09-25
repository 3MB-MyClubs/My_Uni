begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id, aud, role, email) values
 ('18000000-0000-0000-0000-000000000001','authenticated','authenticated','tickets-manager@ku.edu.tr'),
 ('18000000-0000-0000-0000-000000000002','authenticated','authenticated','tickets-holder@ku.edu.tr'),
 ('18000000-0000-0000-0000-000000000003','authenticated','authenticated','tickets-stranger@ku.edu.tr'),
 ('18000000-0000-0000-0000-000000000004','authenticated','authenticated','tickets-board@ku.edu.tr');
insert into public.profiles(id, email, full_name) values
 ('18000000-0000-0000-0000-000000000001','tickets-manager@ku.edu.tr','Manager'),
 ('18000000-0000-0000-0000-000000000002','tickets-holder@ku.edu.tr','Holder'),
 ('18000000-0000-0000-0000-000000000003','tickets-stranger@ku.edu.tr','Stranger'),
 ('18000000-0000-0000-0000-000000000004','tickets-board@ku.edu.tr','Board') on conflict(id) do nothing;
insert into public.clubs(id,name) values
 ('18100000-0000-0000-0000-000000000001','Ticket club'),
 ('18100000-0000-0000-0000-000000000002','Other ticket club');
insert into public.club_auth_accounts(auth_user_id,club_id) values
 ('18000000-0000-0000-0000-000000000001','18100000-0000-0000-0000-000000000001');
insert into public.club_followers(club_id,profile_id,role) values
 ('18100000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000004','board_member');
insert into public.club_account_contexts(user_id,club_id) values
 ('18000000-0000-0000-0000-000000000004','18100000-0000-0000-0000-000000000001');
insert into public.events(id,club_id,title,event_date,starts_at,is_ticketed) values
 ('18200000-0000-0000-0000-000000000001','18100000-0000-0000-0000-000000000001','Tickets A',current_date,now(),true),
 ('18200000-0000-0000-0000-000000000002','18100000-0000-0000-0000-000000000001','Tickets B',current_date,now(),true),
 ('18200000-0000-0000-0000-000000000003','18100000-0000-0000-0000-000000000002','Other club',current_date,now(),true);
insert into public.event_rsvps(event_id,profile_id) values
 ('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002'),
 ('18200000-0000-0000-0000-000000000002','18000000-0000-0000-0000-000000000002');


-- Reset these fixtures to ordinary events; the default for all newly created events.
update public.events set is_ticketed=false;
set local role authenticated;
select set_config('request.jwt.claim.sub','18000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.event_tickets),0::bigint,'RSVP never automatically issues tickets');
select ok(not public.can_manage_event_tickets('18200000-0000-0000-0000-000000000001'),'ordinary events do not expose scanner access');
select throws_ok($$select public.issue_event_ticket('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002')$$,
 '22023','Ticketing is not enabled for this event','server refuses ticket issuance for ordinary events');
select is((public.create_club_event_transactional_v4(
 '18200000-0000-0000-0000-000000000004','18100000-0000-0000-0000-000000000001',
 'Default ordinary event','','Campus',current_date,now(),now()+interval '1 hour')).is_ticketed,false,'create defaults to ordinary event');
select is((public.create_club_event_transactional_v4(
 '18200000-0000-0000-0000-000000000005','18100000-0000-0000-0000-000000000001',
 'Explicit ticketed event','','Campus',current_date,now(),now()+interval '1 hour',p_is_ticketed=>true)).is_ticketed,true,'create atomically stores opt-in');
select is((select count(*) from public.event_tickets),0::bigint,'creating a ticketed event does not issue tickets');
select is((public.update_club_event_transactional_v3(
 '18200000-0000-0000-0000-000000000001','Tickets A','','Campus',current_date,now(),now()+interval '1 hour',
 null,null,'{}',null,null,'[]',true))->'entity'->>'is_ticketed','true','editing persists opt-in and returns it');
select ok(public.can_manage_event_tickets('18200000-0000-0000-0000-000000000001'),'staff can scan after opt-in');
select is((select count(*) from public.event_tickets),0::bigint,'enabling tickets for existing RSVPs does not issue them');
select is((select item->>'is_ticketed' from jsonb_array_elements(public.get_feed_page_v2()->'upcoming_events') item
 where item->>'id'='18200000-0000-0000-0000-000000000001'),'true','feed carries ticket setting');
select set_config('test.optin_token',(public.issue_event_ticket('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002')).token,true);
select is((select count(*) from public.event_tickets),1::bigint,'explicit staff action issues ticket');
select public.update_club_event_transactional_v3(
 '18200000-0000-0000-0000-000000000001','Tickets A','','Campus',current_date,now(),now()+interval '1 hour',
 null,null,'{}',null,null,'[]',false);
select ok((select revoked_at is not null from public.event_tickets where token=current_setting('test.optin_token')),'disabling revokes existing ticket');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.optin_token'))->>'status','invalid','disabled event cannot admit via ticket');
select public.update_club_event_transactional_v3(
 '18200000-0000-0000-0000-000000000001','Tickets A','','Campus',current_date,now(),now()+interval '1 hour',
 null,null,'{}',null,null,'[]',true);
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.optin_token'))->>'status','revoked','reenabling cannot restore old QR');
select isnt((public.issue_event_ticket('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002')).token,current_setting('test.optin_token'),'organizer can explicitly issue replacement');
select set_config('request.jwt.claim.sub','18000000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.update_club_event_transactional_v3(
 '18200000-0000-0000-0000-000000000001','Forged','','Campus',current_date,now(),now()+interval '1 hour',
 null,null,'{}',null,null,'[]',false)$$,'42501','Not authorized','attendee cannot change ticket setting');
update public.events set is_ticketed=false where id='18200000-0000-0000-0000-000000000001';
select ok((select is_ticketed from public.events where id='18200000-0000-0000-0000-000000000001'),'RLS also blocks direct attendee toggle');
select throws_ok($$select public.issue_event_ticket('18200000-0000-0000-0000-000000000001',auth.uid())$$,
 '42501','Not authorized to manage this event','attendee cannot issue even on ticketed event');
select * from finish();
rollback;
