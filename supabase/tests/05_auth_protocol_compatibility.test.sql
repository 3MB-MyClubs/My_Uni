begin;
create extension if not exists pgtap with schema extensions;
select plan(59);

-- Legacy signup: exact released protocol state (verified=true), with bounded
-- attempts and atomic one-time completion.
select is(
  public.issue_signup_challenge_legacy(
    'legacy-signup@ku.edu.tr', 'legacy-signup-code', now() + interval '10 minutes'
  ),
  'issued',
  'legacy signup request is accepted'
);
select is(
  public.verify_signup_challenge_legacy(
    'legacy-signup@ku.edu.tr', 'wrong-code'
  ),
  'invalid',
  'legacy signup rejects a wrong code'
);
select is(
  (select attempt_count from public.pending_signups
   where email = 'legacy-signup@ku.edu.tr'),
  1::smallint,
  'legacy signup counts failed attempts'
);
select is(
  public.verify_signup_challenge_legacy(
    'legacy-signup@ku.edu.tr', 'legacy-signup-code'
  ),
  'ok',
  'legacy signup verifies the correct code'
);
select ok(
  (select verified from public.pending_signups
   where email = 'legacy-signup@ku.edu.tr'),
  'legacy signup exposes the released verified flag contract'
);
select is(
  public.consume_signup_verification_legacy('legacy-signup@ku.edu.tr'),
  'ok',
  'legacy signup completion consumes verification once'
);
select ok(
  not (select verified from public.pending_signups
       where email = 'legacy-signup@ku.edu.tr'),
  'legacy signup completion clears verified state'
);
select is(
  public.consume_signup_verification_legacy('legacy-signup@ku.edu.tr'),
  'invalid',
  'legacy signup completion replay fails'
);

select is(
  public.issue_signup_challenge_legacy(
    'legacy-lock@ku.edu.tr', 'never-guessed', now() + interval '10 minutes'
  ),
  'issued',
  'legacy signup lockout challenge is issued'
);
do $attempts$
begin
  perform public.verify_signup_challenge_legacy('legacy-lock@ku.edu.tr', 'wrong-1');
  perform public.verify_signup_challenge_legacy('legacy-lock@ku.edu.tr', 'wrong-2');
  perform public.verify_signup_challenge_legacy('legacy-lock@ku.edu.tr', 'wrong-3');
  perform public.verify_signup_challenge_legacy('legacy-lock@ku.edu.tr', 'wrong-4');
  perform public.verify_signup_challenge_legacy('legacy-lock@ku.edu.tr', 'wrong-5');
end
$attempts$;
select is(
  public.verify_signup_challenge_legacy('legacy-lock@ku.edu.tr', 'never-guessed'),
  'locked',
  'legacy signup locks on the fifth failed attempt'
);

select is(
  public.issue_signup_challenge_legacy(
    'legacy-expired@ku.edu.tr', 'expired-code', now() + interval '10 minutes'
  ),
  'issued',
  'legacy expiry challenge is issued'
);
update public.pending_signups
set expires_at = now() - interval '1 second'
where email = 'legacy-expired@ku.edu.tr';
select is(
  public.verify_signup_challenge_legacy('legacy-expired@ku.edu.tr', 'expired-code'),
  'expired',
  'legacy signup rejects an expired code'
);

select is(
  public.issue_password_reset_challenge_legacy(
    'legacy-reset@ku.edu.tr', 'legacy-reset-code', now() + interval '10 minutes'
  ),
  'issued',
  'legacy reset request is accepted'
);
select is(
  public.verify_password_reset_challenge_legacy(
    'legacy-reset@ku.edu.tr', 'legacy-reset-code'
  ),
  'ok',
  'legacy reset verifies the correct code'
);
select is(
  public.consume_password_reset_verification_legacy('legacy-reset@ku.edu.tr'),
  'ok',
  'legacy reset completion consumes verification once'
);
select is(
  public.consume_password_reset_verification_legacy('legacy-reset@ku.edu.tr'),
  'invalid',
  'legacy reset completion replay fails'
);

-- V2 signup: separate private state with cooldown, attempts, capabilities,
-- expiry, account binding, and one-time consumption.
select is(
  public.issue_signup_challenge_v2(
    'v2-signup@ku.edu.tr', 'v2-signup-code', now() + interval '10 minutes'
  ),
  'issued',
  'v2 signup request is accepted'
);
select is(
  public.issue_signup_challenge_v2(
    'v2-signup@ku.edu.tr', 'replacement', now() + interval '10 minutes'
  ),
  'cooldown',
  'v2 signup resend cooldown is atomic'
);
select is(
  public.verify_signup_challenge_v2(
    'v2-signup@ku.edu.tr', 'wrong-code', 'unused-capability-hash'
  ),
  'invalid',
  'v2 signup rejects a wrong code'
);
select is(
  (select attempt_count from private.signup_challenges_v2
   where email = 'v2-signup@ku.edu.tr'),
  1::smallint,
  'v2 signup counts failed attempts'
);
select is(
  public.verify_signup_challenge_v2(
    'v2-signup@ku.edu.tr', 'v2-signup-code', 'v2-capability-hash'
  ),
  'ok',
  'v2 signup issues a capability hash'
);
select is(
  (select capability_hash from private.signup_challenges_v2
   where email = 'v2-signup@ku.edu.tr'),
  'v2-capability-hash',
  'v2 stores only the supplied capability hash'
);
select is(
  public.consume_signup_capability_v2(
    'other-v2-user@ku.edu.tr', 'v2-capability-hash'
  ),
  'invalid',
  'v2 signup capability is account-bound'
);
select is(
  public.consume_signup_capability_v2(
    'v2-signup@ku.edu.tr', 'v2-capability-hash'
  ),
  'ok',
  'v2 signup capability works once'
);
select is(
  public.consume_signup_capability_v2(
    'v2-signup@ku.edu.tr', 'v2-capability-hash'
  ),
  'invalid',
  'v2 signup capability replay fails'
);

select is(
  public.issue_signup_challenge_v2(
    'v2-expired-cap@ku.edu.tr', 'v2-expired-code', now() + interval '10 minutes'
  ),
  'issued',
  'v2 expired-capability challenge is issued'
);
select is(
  public.verify_signup_challenge_v2(
    'v2-expired-cap@ku.edu.tr', 'v2-expired-code', 'expired-capability-hash'
  ),
  'ok',
  'v2 capability exists before expiry'
);
update private.signup_challenges_v2
set capability_expires_at = now() - interval '1 second'
where email = 'v2-expired-cap@ku.edu.tr';
select is(
  public.consume_signup_capability_v2(
    'v2-expired-cap@ku.edu.tr', 'expired-capability-hash'
  ),
  'expired',
  'v2 signup rejects an expired capability'
);

select is(
  public.issue_signup_challenge_v2(
    'v2-lock@ku.edu.tr', 'v2-never-guessed', now() + interval '10 minutes'
  ),
  'issued',
  'v2 lockout challenge is issued'
);
do $attempts$
begin
  perform public.verify_signup_challenge_v2('v2-lock@ku.edu.tr', 'wrong-1', 'cap-1');
  perform public.verify_signup_challenge_v2('v2-lock@ku.edu.tr', 'wrong-2', 'cap-2');
  perform public.verify_signup_challenge_v2('v2-lock@ku.edu.tr', 'wrong-3', 'cap-3');
  perform public.verify_signup_challenge_v2('v2-lock@ku.edu.tr', 'wrong-4', 'cap-4');
  perform public.verify_signup_challenge_v2('v2-lock@ku.edu.tr', 'wrong-5', 'cap-5');
end
$attempts$;
select is(
  public.verify_signup_challenge_v2(
    'v2-lock@ku.edu.tr', 'v2-never-guessed', 'too-late'
  ),
  'locked',
  'v2 signup locks on the fifth failed attempt'
);

select is(
  public.issue_password_reset_challenge_v2(
    'v2-reset@ku.edu.tr', 'v2-reset-code', now() + interval '10 minutes'
  ),
  'issued',
  'v2 reset request is accepted'
);
select is(
  public.verify_password_reset_challenge_v2(
    'v2-reset@ku.edu.tr', 'v2-reset-code', 'v2-reset-capability-hash'
  ),
  'ok',
  'v2 reset issues a capability hash'
);
select is(
  public.consume_password_reset_capability_v2(
    'v2-reset@ku.edu.tr', 'v2-reset-capability-hash'
  ),
  'ok',
  'v2 reset capability works once'
);
select is(
  public.consume_password_reset_capability_v2(
    'v2-reset@ku.edu.tr', 'v2-reset-capability-hash'
  ),
  'invalid',
  'v2 reset capability replay fails'
);

-- Protocol isolation: neither protocol reads, consumes, nor invalidates the
-- other protocol's mutable challenge state.
select is(
  public.issue_signup_challenge_legacy(
    'isolated@ku.edu.tr', 'legacy-isolated-code', now() + interval '10 minutes'
  ),
  'issued',
  'legacy and v2 isolation starts with a legacy challenge'
);
select is(
  public.issue_signup_challenge_v2(
    'isolated@ku.edu.tr', 'v2-isolated-code', now() + interval '10 minutes'
  ),
  'issued',
  'the same email can independently request a v2 challenge'
);
select is(
  (select count(*) from public.pending_signups
   where email = 'isolated@ku.edu.tr')
  +
  (select count(*) from private.signup_challenges_v2
   where email = 'isolated@ku.edu.tr'),
  2::bigint,
  'legacy and v2 challenge rows coexist'
);
select is(
  public.verify_signup_challenge_legacy('isolated@ku.edu.tr', 'legacy-isolated-code'),
  'ok',
  'legacy verification succeeds independently'
);
select is(
  (select capability_hash from private.signup_challenges_v2
   where email = 'isolated@ku.edu.tr'),
  null,
  'legacy verification does not issue a v2 capability'
);
select is(
  public.verify_signup_challenge_v2(
    'isolated@ku.edu.tr', 'v2-isolated-code', 'isolated-v2-capability'
  ),
  'ok',
  'v2 verification succeeds independently'
);
select ok(
  (select verified from public.pending_signups
   where email = 'isolated@ku.edu.tr'),
  'v2 verification does not clear legacy verification'
);

select is(
  public.issue_signup_challenge_v2(
    'v2-only@ku.edu.tr', 'v2-only-code', now() + interval '10 minutes'
  ),
  'issued',
  'v2-only challenge is issued'
);
select is(
  public.verify_signup_challenge_v2(
    'v2-only@ku.edu.tr', 'v2-only-code', 'v2-only-capability'
  ),
  'ok',
  'v2-only challenge verifies'
);
select is(
  public.consume_signup_verification_legacy('v2-only@ku.edu.tr'),
  'invalid',
  'legacy completion cannot consume v2 state'
);

select is(
  public.issue_signup_challenge_legacy(
    'legacy-only@ku.edu.tr', 'legacy-only-code', now() + interval '10 minutes'
  ),
  'issued',
  'legacy-only challenge is issued'
);
select is(
  public.verify_signup_challenge_legacy('legacy-only@ku.edu.tr', 'legacy-only-code'),
  'ok',
  'legacy-only challenge verifies'
);
select is(
  public.consume_signup_capability_v2('legacy-only@ku.edu.tr', 'anything'),
  'invalid',
  'v2 completion cannot consume legacy verification'
);

select is(
  public.issue_signup_challenge_legacy(
    'legacy-resend-isolation@ku.edu.tr', 'legacy-before-resend', now() + interval '10 minutes'
  ),
  'issued',
  'legacy resend-isolation challenge is issued'
);
select is(
  public.issue_signup_challenge_v2(
    'legacy-resend-isolation@ku.edu.tr', 'v2-survives-legacy-resend', now() + interval '10 minutes'
  ),
  'issued',
  'v2 challenge exists before a legacy resend'
);
update public.pending_signups
set last_sent_at = now() - interval '61 seconds'
where email = 'legacy-resend-isolation@ku.edu.tr';
select is(
  public.issue_signup_challenge_legacy(
    'legacy-resend-isolation@ku.edu.tr', 'legacy-after-resend', now() + interval '10 minutes'
  ),
  'issued',
  'legacy code can be resent after cooldown'
);
select is(
  public.verify_signup_challenge_v2(
    'legacy-resend-isolation@ku.edu.tr',
    'v2-survives-legacy-resend',
    'v2-survived-capability'
  ),
  'ok',
  'requesting a legacy code does not invalidate the active v2 code'
);

select is(
  public.issue_signup_challenge_legacy(
    'v2-resend-isolation@ku.edu.tr', 'legacy-survives-v2-resend', now() + interval '10 minutes'
  ),
  'issued',
  'legacy challenge exists before a v2 resend'
);
select is(
  public.issue_signup_challenge_v2(
    'v2-resend-isolation@ku.edu.tr', 'v2-before-resend', now() + interval '10 minutes'
  ),
  'issued',
  'v2 resend-isolation challenge is issued'
);
update private.signup_challenges_v2
set last_sent_at = now() - interval '61 seconds'
where email = 'v2-resend-isolation@ku.edu.tr';
select is(
  public.issue_signup_challenge_v2(
    'v2-resend-isolation@ku.edu.tr', 'v2-after-resend', now() + interval '10 minutes'
  ),
  'issued',
  'v2 code can be resent after cooldown'
);
select is(
  public.verify_signup_challenge_legacy(
    'v2-resend-isolation@ku.edu.tr', 'legacy-survives-v2-resend'
  ),
  'ok',
  'requesting a v2 code does not invalidate the active legacy code'
);

select ok(
  pg_get_functiondef('public.consume_signup_verification_legacy(text)'::regprocedure)
    ilike '%FOR UPDATE%',
  'legacy signup completion serializes concurrent consumers'
);
select ok(
  pg_get_functiondef('public.consume_password_reset_verification_legacy(text)'::regprocedure)
    ilike '%FOR UPDATE%',
  'legacy reset completion serializes concurrent consumers'
);
select ok(
  pg_get_functiondef('public.consume_signup_capability_v2(text,text)'::regprocedure)
    ilike '%FOR UPDATE%',
  'v2 signup completion serializes concurrent consumers'
);
select ok(
  pg_get_functiondef('public.consume_password_reset_capability_v2(text,text)'::regprocedure)
    ilike '%FOR UPDATE%',
  'v2 reset completion serializes concurrent consumers'
);

select * from finish();
rollback;
