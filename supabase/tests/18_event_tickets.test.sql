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

select ok(not has_table_privilege('anon','public.event_tickets','SELECT'),'anonymous cannot read tickets');
select ok(not has_function_privilege('anon','public.scan_event_ticket(uuid,text)','EXECUTE'),'anonymous cannot scan');
select ok(not has_function_privilege('anon','private.issue_event_ticket(uuid,uuid,boolean)','EXECUTE'),'private implementation is not public');
set local role authenticated;
select set_config('request.jwt.claim.sub','18000000-0000-0000-0000-000000000001',true);
select ok(public.can_manage_event_tickets('18200000-0000-0000-0000-000000000001'),'club account authorized');
select throws_ok($$select public.issue_event_ticket('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000003')$$,
 '22023','An RSVP is required','cannot issue without RSVP');
select throws_ok($$select public.issue_event_ticket('18200000-0000-0000-0000-000000000003','18000000-0000-0000-0000-000000000002')$$,
 '42501','Not authorized to manage this event','manager cannot issue for unrelated club');
select set_config('test.ticket', (public.issue_event_ticket('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002')).token,true);
select ok(current_setting('test.ticket') ~ '^[0-9a-f]{64}$','server generates 256-bit random credential');
select is((public.issue_event_ticket('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002')).token,
 current_setting('test.ticket'),'repeat issuance returns same ticket');
select is((select issued_by from public.event_tickets limit 1),auth.uid(),'issuer bound to caller');
select ok(not has_table_privilege('authenticated','public.event_tickets','INSERT'),'cannot forge ticket through direct insert');
select ok(not has_table_privilege('authenticated','public.event_tickets','UPDATE'),'cannot replace credential or clear consumption');
select ok(not has_table_privilege('authenticated','public.event_tickets','DELETE'),'cannot erase revocation history');

select set_config('request.jwt.claim.sub','18000000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.event_tickets),1::bigint,'holder can read own ticket');
select throws_ok($$select public.issue_event_ticket('18200000-0000-0000-0000-000000000001',auth.uid())$$,
 '42501','Not authorized to manage this event','holder cannot self-issue');
select throws_ok($$select public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.ticket'))$$,
 '42501','Not authorized to manage this event','holder cannot self-check-in');
select throws_ok($$select public.revoke_event_ticket('18200000-0000-0000-0000-000000000001',(select id from public.event_tickets limit 1))$$,
 '42501','Not authorized to manage this event','holder cannot revoke');
select set_config('request.jwt.claim.sub','18000000-0000-0000-0000-000000000003',true);
select is((select count(*) from public.event_tickets),0::bigint,'stranger cannot enumerate tickets');

select set_config('request.jwt.claim.sub','18000000-0000-0000-0000-000000000004',true);
select ok(public.can_manage_event_tickets('18200000-0000-0000-0000-000000000001'),'linked board staff authorized');
select is((select count(*) from public.event_tickets),1::bigint,'authorized staff can read tickets');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000002',current_setting('test.ticket')),
 '{"status":"wrong_event"}'::jsonb,'wrong event reveals no attendee data');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',repeat('f',64))->>'status','invalid','unknown token invalid');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002')->>'status','invalid','profile ID cannot admit');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',null)->>'status','invalid','null token invalid');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001','https://clubup.app/events/18200000-0000-0000-0000-000000000001')->>'status','invalid','sharing QR cannot admit');
select ok(public.revoke_event_ticket('18200000-0000-0000-0000-000000000001',(select id from public.event_tickets limit 1)),'staff can revoke');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.ticket'))->>'status','revoked','revoked token rejected');
select set_config('test.reissued',(public.issue_event_ticket('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002',true)).token,true);
select isnt(current_setting('test.reissued'),current_setting('test.ticket'),'reissue rotates secret');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.ticket'))->>'status','revoked','old secret remains revoked after reissue');
select set_config('test.rotated', (public.issue_event_ticket('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002',true)).token,true);
select isnt(current_setting('test.rotated'),current_setting('test.reissued'),'reissue can atomically replace an active ticket');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.reissued'))->>'status','revoked','active reissue invalidates its predecessor');
select set_config('test.reissued',current_setting('test.rotated'),true);
select is((select count(*) from public.event_tickets where revoked_at is null),1::bigint,'only one current ticket');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.reissued'))->>'status','checked_in','reissued ticket admits');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.reissued'))->>'status','already_used','duplicate scan rejected');
select is((select count(*) from public.event_checkins),1::bigint,'one canonical check-in');
select is((select checked_in_by from public.event_checkins limit 1),auth.uid(),'check-in actor is server bound');
select is((select method from public.event_checkins limit 1),'qr','check-in recorded as QR');
select ok(public.revoke_event_ticket('18200000-0000-0000-0000-000000000001',
 (select id from public.event_tickets where token=current_setting('test.reissued'))),
 'staff can revoke a used ticket');
select set_config('test.after_entry',
 (public.issue_event_ticket('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002',true)).token,true);
select isnt(current_setting('test.after_entry'),current_setting('test.reissued'),
 'new admission gets a new credential after entry and revocation');
select is((select count(*) from public.event_checkins where event_id='18200000-0000-0000-0000-000000000001'),
 0::bigint,'reissue clears the current check-in');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.reissued'))->>'status',
 'revoked','prior used credential remains unusable');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.after_entry'))->>'status',
 'checked_in','new ticket admits again');
select set_config('test.third_entry',
 (public.issue_event_ticket('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002',true)).token,true);
select isnt(current_setting('test.third_entry'),current_setting('test.after_entry'),
 'staff can reissue a used ticket directly without first revoking it');
select is((select count(*) from public.event_checkins where event_id='18200000-0000-0000-0000-000000000001'),
 0::bigint,'direct reissue clears admission for the next scan');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.third_entry'))->>'status',
 'checked_in','direct reissue admits again');
select public.remove_event_checkin_v2('18200000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000002');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.third_entry'))->>'status','already_used','manual removal cannot resurrect used QR');
select set_config('test.second',(public.issue_event_ticket('18200000-0000-0000-0000-000000000002','18000000-0000-0000-0000-000000000002')).token,true);
select public.check_in_event_v2('18200000-0000-0000-0000-000000000002','18000000-0000-0000-0000-000000000002','manual');
select is(public.scan_event_ticket('18200000-0000-0000-0000-000000000002',current_setting('test.second'))->>'status','already_used','manual admission prevents a second QR admission');

select set_config('request.jwt.claim.sub','18000000-0000-0000-0000-000000000002',true);
delete from public.event_rsvps where event_id='18200000-0000-0000-0000-000000000002' and profile_id=auth.uid();
select ok((select revoked_at is not null from public.event_tickets where token=current_setting('test.second')),'RSVP cancellation revokes ticket');
insert into public.event_rsvps(event_id,profile_id) values('18200000-0000-0000-0000-000000000002',auth.uid());
select ok((select revoked_at is not null from public.event_tickets where token=current_setting('test.second')),'RSVP again does not resurrect ticket');
reset role;
update public.club_followers set role='member' where profile_id='18000000-0000-0000-0000-000000000004';
set local role authenticated;
select set_config('request.jwt.claim.sub','18000000-0000-0000-0000-000000000004',true);
select is((select count(*) from public.event_tickets),0::bigint,'removed staff immediately loses ticket access');
select throws_ok($$select public.scan_event_ticket('18200000-0000-0000-0000-000000000001',current_setting('test.reissued'))$$,
 '42501','Not authorized to manage this event','removed staff cannot scan despite retained context');
select * from finish();
rollback;
