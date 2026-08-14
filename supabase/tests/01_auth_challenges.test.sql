begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

select is(
  public.issue_password_reset_challenge(
    'victim@ku.edu.tr', 'correct-code-hash', now() + interval '10 minutes'
  ),
  'issued',
  'a password-reset challenge is issued'
);
select is(
  public.issue_password_reset_challenge(
    'victim@ku.edu.tr', 'replacement', now() + interval '10 minutes'
  ),
  'cooldown',
  'the resend cooldown is atomic'
);
select is(
  public.verify_password_reset_challenge(
    'victim@ku.edu.tr', 'wrong-code-hash', 'unused-capability'
  ),
  'invalid',
  'a wrong reset code is rejected'
);
select is(
  (select attempt_count from public.pending_password_resets
   where email = 'victim@ku.edu.tr'),
  1::smallint,
  'a wrong code consumes an attempt'
);
select is(
  public.consume_password_reset_capability(
    'victim@ku.edu.tr', 'unused-capability'
  ),
  'invalid',
  'reset completion without verification is rejected'
);

update public.pending_password_resets
set expires_at = now() - interval '1 second'
where email = 'victim@ku.edu.tr';
select is(
  public.verify_password_reset_challenge(
    'victim@ku.edu.tr', 'correct-code-hash', 'capability-hash'
  ),
  'expired',
  'an expired code is rejected'
);

delete from public.pending_password_resets where email = 'victim@ku.edu.tr';
select is(
  public.issue_password_reset_challenge(
    'victim@ku.edu.tr', 'correct-code-hash', now() + interval '10 minutes'
  ),
  'issued',
  'a fresh reset can be requested after expiry'
);
select is(
  public.verify_password_reset_challenge(
    'victim@ku.edu.tr', 'correct-code-hash', 'victim-capability-hash'
  ),
  'ok',
  'the correct reset code mints a server-side capability hash'
);
select is(
  public.consume_password_reset_capability(
    'attacker@ku.edu.tr', 'victim-capability-hash'
  ),
  'invalid',
  'a capability cannot complete another account reset'
);
select is(
  public.consume_password_reset_capability(
    'victim@ku.edu.tr', 'victim-capability-hash'
  ),
  'ok',
  'the verified reset capability is consumed once'
);
select is(
  public.consume_password_reset_capability(
    'victim@ku.edu.tr', 'victim-capability-hash'
  ),
  'invalid',
  'replay is rejected'
);
select ok(
  pg_get_functiondef(
    'public.consume_password_reset_capability(text,text)'::regprocedure
  ) ilike '%FOR UPDATE%',
  'concurrent reset consumers serialize on the challenge row'
);
select ok(
  pg_get_functiondef('public.consume_signup_capability(text,text)'::regprocedure)
    ilike '%FOR UPDATE%',
  'concurrent signup consumers serialize on the challenge row'
);

select is(
  public.issue_signup_challenge(
    'new-student@ku.edu.tr', 'signup-code-hash', now() + interval '10 minutes'
  ),
  'issued',
  'a signup challenge is issued'
);
select is(
  public.consume_signup_capability('new-student@ku.edu.tr', 'signup-capability'),
  'invalid',
  'signup cannot complete without verification'
);
select is(
  public.verify_signup_challenge(
    'new-student@ku.edu.tr', 'wrong-code-hash', 'signup-capability'
  ),
  'invalid',
  'a wrong signup code is rejected'
);
select is(
  public.verify_signup_challenge(
    'new-student@ku.edu.tr', 'signup-code-hash', 'signup-capability'
  ),
  'ok',
  'the correct signup code mints a server-side capability hash'
);
select is(
  public.consume_signup_capability('other-student@ku.edu.tr', 'signup-capability'),
  'invalid',
  'a signup capability is bound to its account'
);
select is(
  public.consume_signup_capability('new-student@ku.edu.tr', 'signup-capability'),
  'ok',
  'a signup capability is consumed once'
);
select is(
  public.consume_signup_capability('new-student@ku.edu.tr', 'signup-capability'),
  'invalid',
  'signup capability replay is rejected'
);

select is(
  public.issue_signup_challenge(
    'brute-force@ku.edu.tr', 'never-guessed', now() + interval '10 minutes'
  ),
  'issued',
  'a challenge can be used to exercise attempt limiting'
);
do $attempts$
begin
  perform public.verify_signup_challenge('brute-force@ku.edu.tr', 'wrong-1', 'unused-1');
  perform public.verify_signup_challenge('brute-force@ku.edu.tr', 'wrong-2', 'unused-2');
  perform public.verify_signup_challenge('brute-force@ku.edu.tr', 'wrong-3', 'unused-3');
  perform public.verify_signup_challenge('brute-force@ku.edu.tr', 'wrong-4', 'unused-4');
  perform public.verify_signup_challenge('brute-force@ku.edu.tr', 'wrong-5', 'unused-5');
end
$attempts$;
select is(
  public.verify_signup_challenge(
    'brute-force@ku.edu.tr', 'never-guessed', 'too-late'
  ),
  'locked',
  'a correct code is rejected after the attempt limit is reached'
);

select * from finish();
rollback;
