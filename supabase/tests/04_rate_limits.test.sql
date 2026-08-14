begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

delete from private.rate_limit_buckets;
delete from private.rate_limit_events;

select ok(
  (select allowed from public.consume_edge_rate_limit(
    'auth_signup_request:identity', 'test-ip|student-a@ku.edu.tr'
  )),
  'the first request is allowed'
);
select ok(
  (select allowed from public.consume_edge_rate_limit(
    'auth_signup_request:identity', 'test-ip|student-a@ku.edu.tr'
  )),
  'a normal short burst is allowed'
);
select ok(
  (select allowed from public.consume_edge_rate_limit(
    'auth_signup_request:identity', 'test-ip|student-a@ku.edu.tr'
  )),
  'the configured burst capacity is allowed'
);
select is(
  (select allowed from public.consume_edge_rate_limit(
    'auth_signup_request:identity', 'test-ip|student-a@ku.edu.tr'
  )),
  false,
  'a request above the burst capacity is rejected'
);
select cmp_ok(
  (select retry_after_seconds from public.consume_edge_rate_limit(
    'auth_signup_request:identity', 'test-ip|student-a@ku.edu.tr'
  )),
  '>=',
  1,
  'a rejection includes a positive retry-after duration'
);
select ok(
  (select allowed from public.consume_edge_rate_limit(
    'auth_signup_request:identity', 'test-ip|student-b@ku.edu.tr'
  )),
  'one identity reaching its limit does not block another identity'
);
select is(
  (select sum(rejection_count) from private.rate_limit_events
   where action = 'auth_signup_request:identity'),
  2::numeric,
  'Edge rejections are aggregated without storing a raw scope'
);
select ok(
  not exists (
    select 1 from information_schema.columns
    where table_schema = 'private'
      and table_name in ('rate_limit_buckets', 'rate_limit_events')
      and column_name in ('email', 'ip', 'scope', 'user_id')
  ),
  'counter and event tables expose no raw identity or network columns'
);

-- Isolate sustained-window behavior from the production values inside this
-- rolled-back test transaction.
update private.rate_limit_rules set
  burst_capacity = 100,
  sustained_capacity = 2
where action = 'auth_signup_verify:identity';
select ok(
  (select allowed from public.consume_edge_rate_limit(
    'auth_signup_verify:identity', 'sustained-test'
  )),
  'the first sustained-window request is allowed'
);
select ok(
  (select allowed from public.consume_edge_rate_limit(
    'auth_signup_verify:identity', 'sustained-test'
  )),
  'the second sustained-window request is allowed'
);
select is(
  (select limiting_window from public.consume_edge_rate_limit(
    'auth_signup_verify:identity', 'sustained-test'
  )),
  'sustained',
  'sustained abuse is rejected independently of the burst window'
);

create temporary table rate_limit_test_results (
  class text not null,
  allowed boolean not null
) on commit drop;
do $test$
declare
  i integer;
  decision record;
begin
  for i in 1..6 loop
    select * into decision from private.consume_rate_limit(
      'group_create:actor',
      'regular-test',
      'authenticated',
      false,
      1,
      false,
      false
    );
    insert into rate_limit_test_results values ('regular', decision.allowed);

    select * into decision from private.consume_rate_limit(
      'group_create:actor',
      'privileged-test',
      'privileged',
      true,
      1,
      false,
      false
    );
    insert into rate_limit_test_results values ('privileged', decision.allowed);
  end loop;
end
$test$;
select is(
  (select count(*) from rate_limit_test_results
   where class = 'regular' and allowed),
  5::bigint,
  'ordinary users receive the configured group-create burst'
);
select is(
  (select count(*) from rate_limit_test_results
   where class = 'privileged' and allowed),
  6::bigint,
  'privileged users receive the intended higher ceiling'
);

-- The authenticated helper accepts no actor parameter and derives its bucket
-- from auth.uid(). A forged resource string cannot select another actor.
select set_config(
  'request.jwt.claim.sub',
  '70000000-0000-0000-0000-000000000001',
  true
);
select lives_ok(
  $$select private.enforce_authenticated_rate_limit(
    'like_change:actor',
    'forged-user=70000000-0000-0000-0000-000000000002'
  )$$,
  'authenticated enforcement derives a server-side actor'
);
select ok(
  exists (
    select 1 from private.rate_limit_buckets
    where action = 'like_change:actor'
      and scope_hash = encode(
        extensions.digest(
          convert_to(
            'like_change:actor' || chr(31) ||
            'actor=70000000-0000-0000-0000-000000000001' ||
            '|resource=forged-user=70000000-0000-0000-0000-000000000002',
            'UTF8'
          ),
          'sha256'
        ),
        'hex'
      )
  ),
  'the stored bucket uses auth.uid rather than a caller-provided user id'
);
select ok(
  position(
    'p_actor' in pg_get_function_arguments(
      'private.enforce_authenticated_rate_limit(text,text)'::regprocedure
    )
  ) = 0,
  'the authenticated enforcement API has no caller-supplied actor argument'
);

select ok(
  position(
    'for update' in lower(pg_get_functiondef(
      'private.consume_rate_limit(text,text,text,boolean,numeric,boolean,boolean)'::regprocedure
    ))
  ) > 0,
  'concurrent requests serialize on the bucket row'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.consume_edge_rate_limit(text,text)',
    'EXECUTE'
  ),
  'authenticated clients cannot choose pre-auth Edge scopes'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.consume_edge_rate_limit(text,text)',
    'EXECUTE'
  ),
  'only the service role can call the pre-auth limiter'
);

update private.rate_limit_buckets
set expires_at = now() - interval '1 second'
where action = 'group_create:actor';
select cmp_ok(
  (private.cleanup_rate_limits(100) ->> 'deleted_buckets')::integer,
  '>=',
  2,
  'expired buckets are removed in a bounded cleanup batch'
);
select ok(
  exists (
    select 1 from pg_indexes
    where schemaname = 'private'
      and tablename = 'rate_limit_buckets'
      and indexdef like '%expires_at%'
  ),
  'expiry cleanup is supported by an index'
);

select * from finish();
rollback;
