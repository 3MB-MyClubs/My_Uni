-- Local regression coverage; never run these fixture writes against production.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

delete from private.rate_limit_buckets;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password)
values
  ('00000000-0000-0000-0000-000000000000', 'b1000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'delete-owner@example.test', ''),
  ('00000000-0000-0000-0000-000000000000', 'b1000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'delete-moderator@example.test', ''),
  ('00000000-0000-0000-0000-000000000000', 'b1000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'delete-outsider@example.test', '');

insert into public.clubs (id, name)
values ('b2000000-0000-4000-8000-000000000001', 'Moderator delete fixture');

insert into public.club_auth_accounts (auth_user_id, club_id)
values (
  'b1000000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000001'
);

insert into public.app_admins (singleton, auth_user_id, email)
values (
  true,
  'b1000000-0000-4000-8000-000000000002',
  'delete-moderator@example.test'
)
on conflict (singleton) do update
set auth_user_id = excluded.auth_user_id,
    email = excluded.email;

insert into public.club_posts (id, club_id, content, image_path)
values
  (
    'b3000000-0000-4000-8000-000000000001',
    'b2000000-0000-4000-8000-000000000001',
    'A post the platform moderator may delete',
    'club_posts/b2000000-0000-4000-8000-000000000001/b3000000-0000-4000-8000-000000000001/cover.jpg'
  ),
  (
    'b3000000-0000-4000-8000-000000000002',
    'b2000000-0000-4000-8000-000000000001',
    'A post its club owner may still delete',
    null
  );

select has_function(
  'private',
  'can_delete_club_content',
  array['uuid'],
  'the deletion-only authorization helper exists'
);
select ok(
  (select prosecdef
   from pg_proc
   where oid = 'private.can_delete_club_content(uuid)'::regprocedure),
  'the private authorization lookup is security definer'
);
select ok(
  not has_function_privilege(
    'anon',
    'private.can_delete_club_content(uuid)',
    'EXECUTE'
  ),
  'anonymous callers cannot execute the deletion helper'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$select public.delete_club_post_transactional_v2(
    'b3000000-0000-4000-8000-000000000001',
    'b2000000-0000-4000-8000-000000000001'
  )$$,
  '42501',
  'Not authorized',
  'an unrelated authenticated user cannot delete the post'
);

reset role;
select is(
  (select count(*)
   from public.club_posts
   where id = 'b3000000-0000-4000-8000-000000000001'),
  1::bigint,
  'the rejected delete leaves the post intact'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000002',
  true
);
select is(
  (select private.can_manage_club_content(
    'b2000000-0000-4000-8000-000000000001'
  )),
  false,
  'the moderator does not gain club-authoring permission'
);
create temporary table moderator_delete_result as
select public.delete_club_post_transactional_v2(
  'b3000000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000001'
) as result;
select is(
  (select result ->> 'deleted' from moderator_delete_result),
  'true',
  'the platform moderator can use the transactional delete RPC'
);

reset role;
select is(
  (select count(*)
   from public.club_posts
   where id = 'b3000000-0000-4000-8000-000000000001'),
  0::bigint,
  'the moderator delete removes the post'
);
select is(
  (select requested_by
   from public.storage_cleanup_queue_v2
   where entity_id = 'b3000000-0000-4000-8000-000000000001'),
  'b1000000-0000-4000-8000-000000000002'::uuid,
  'the moderator delete durably queues its image cleanup'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000002',
  true
);
select is(
  public.complete_storage_cleanup_v2(
    ((select result ->> 'cleanup_id' from moderator_delete_result)::uuid)
  ),
  true,
  'the moderator can complete the queued image cleanup'
);

reset role;
select is(
  (select status
   from public.storage_cleanup_queue_v2
   where entity_id = 'b3000000-0000-4000-8000-000000000001'),
  'completed',
  'the durable cleanup row records completion'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000001',
  true
);
select is(
  public.delete_club_post_transactional_v2(
    'b3000000-0000-4000-8000-000000000002',
    'b2000000-0000-4000-8000-000000000001'
  ) ->> 'deleted',
  'true',
  'the club owner retains transactional delete access'
);

reset role;
select is(
  (select count(*)
   from public.club_posts
   where id = 'b3000000-0000-4000-8000-000000000002'),
  0::bigint,
  'the owner delete still removes its post'
);

select * from finish();
rollback;
