-- F2/F3: authorization for event check-ins, poll administration, and voting.

create schema if not exists private;
grant usage on schema private to authenticated;

create or replace function private.can_manage_event(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.events as event
    join public.club_auth_accounts as account
      on account.club_id = event.club_id
    where event.id = p_event_id
      and account.auth_user_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.events as event
    join public.club_account_contexts as context
      on context.club_id = event.club_id
     and context.user_id = (select auth.uid())
    join public.club_followers as follower
      on follower.club_id = context.club_id
     and follower.profile_id = context.user_id
     and follower.role = 'board_member'
    where event.id = p_event_id
  )
  or exists (
    select 1
    from public.app_admins as app_admin
    where app_admin.auth_user_id = (select auth.uid())
  );
$function$;

revoke all on function private.can_manage_event(uuid) from public, anon;
grant execute on function private.can_manage_event(uuid) to authenticated;

create table if not exists public.event_checkins (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  checked_in_at timestamptz not null default now(),
  checked_in_by uuid not null references auth.users(id) on delete restrict,
  method text not null default 'manual'
    constraint event_checkins_method_check check (method in ('qr', 'manual')),
  constraint event_checkins_event_profile_key unique (event_id, profile_id)
);

-- The abandoned prototype used free-form text for checked_in_by. Preserve it
-- for forensic history if that prototype was applied, then introduce the
-- authenticated actor column used by the hardened policy.
do $migration$
declare
  v_type text;
begin
  select data_type into v_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'event_checkins'
    and column_name = 'checked_in_by';

  if v_type is not null and v_type <> 'uuid' then
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'event_checkins'
        and column_name = 'legacy_checked_in_by'
    ) then
      alter table public.event_checkins
        rename column checked_in_by to legacy_checked_in_by;
    else
      alter table public.event_checkins drop column checked_in_by;
    end if;
    alter table public.event_checkins add column checked_in_by uuid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.event_checkins'::regclass
      and conname = 'event_checkins_event_id_fkey'
  ) then
    alter table public.event_checkins
      add constraint event_checkins_event_id_fkey
      foreign key (event_id) references public.events(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.event_checkins'::regclass
      and conname = 'event_checkins_checked_in_by_fkey'
  ) then
    alter table public.event_checkins
      add constraint event_checkins_checked_in_by_fkey
      foreign key (checked_in_by) references auth.users(id) on delete restrict;
  end if;
end
$migration$;

create index if not exists event_checkins_event_checked_at_idx
  on public.event_checkins (event_id, checked_in_at desc);
create index if not exists event_checkins_profile_event_idx
  on public.event_checkins (profile_id, event_id);

create or replace function private.bind_event_checkin_actor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null then
    raise exception 'An authenticated actor is required'
      using errcode = '42501';
  end if;
  new.checked_in_by := auth.uid();
  return new;
end
$function$;

revoke all on function private.bind_event_checkin_actor() from public, anon, authenticated;

drop trigger if exists bind_event_checkin_actor on public.event_checkins;
create trigger bind_event_checkin_actor
before insert or update on public.event_checkins
for each row execute function private.bind_event_checkin_actor();

alter table public.event_checkins enable row level security;
revoke all on table public.event_checkins from public, anon, authenticated;
grant select, insert, delete on table public.event_checkins to authenticated;

drop policy if exists event_checkins_select on public.event_checkins;
drop policy if exists event_checkins_insert on public.event_checkins;
drop policy if exists event_checkins_delete on public.event_checkins;
drop policy if exists event_checkins_read_own_or_manager on public.event_checkins;
drop policy if exists event_checkins_insert_manager on public.event_checkins;
drop policy if exists event_checkins_delete_manager on public.event_checkins;

create policy event_checkins_read_own_or_manager
on public.event_checkins for select to authenticated
using (
  profile_id = (select auth.uid())
  or (select private.can_manage_event(event_id))
);

create policy event_checkins_insert_manager
on public.event_checkins for insert to authenticated
with check (
  checked_in_by = (select auth.uid())
  and (select private.can_manage_event(event_id))
);

create policy event_checkins_delete_manager
on public.event_checkins for delete to authenticated
using ((select private.can_manage_event(event_id)));

-- One optional poll per post; option indices are stable array positions.
create table if not exists public.polls (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null unique references public.club_posts(id) on delete cascade,
  question text not null,
  options jsonb not null,
  created_at timestamptz not null default now(),
  constraint polls_question_length_check
    check (char_length(btrim(question)) between 1 and 500),
  constraint polls_options_check
    check (
      jsonb_typeof(options) = 'array'
      and jsonb_array_length(options) between 2 and 10
    )
);

create table if not exists public.poll_votes (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.polls(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  option_index integer not null check (option_index >= 0),
  created_at timestamptz not null default now(),
  constraint poll_votes_poll_profile_key unique (poll_id, profile_id)
);

do $migration$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.polls'::regclass
      and conname = 'polls_post_id_fkey'
  ) then
    alter table public.polls
      add constraint polls_post_id_fkey
      foreign key (post_id) references public.club_posts(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.polls'::regclass
      and conname = 'polls_question_length_check'
  ) then
    alter table public.polls
      add constraint polls_question_length_check
      check (char_length(btrim(question)) between 1 and 500) not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.polls'::regclass
      and conname = 'polls_options_check'
  ) then
    alter table public.polls
      add constraint polls_options_check
      check (
        jsonb_typeof(options) = 'array'
        and jsonb_array_length(options) between 2 and 10
      ) not valid;
  end if;
end
$migration$;

create index if not exists poll_votes_profile_poll_idx
  on public.poll_votes (profile_id, poll_id);

create or replace function private.can_manage_poll(p_poll_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.polls as poll
    join public.club_posts as post on post.id = poll.post_id
    join public.club_auth_accounts as account on account.club_id = post.club_id
    where poll.id = p_poll_id
      and account.auth_user_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.polls as poll
    join public.club_posts as post on post.id = poll.post_id
    join public.club_account_contexts as context
      on context.club_id = post.club_id
     and context.user_id = (select auth.uid())
    join public.club_followers as follower
      on follower.club_id = context.club_id
     and follower.profile_id = context.user_id
     and follower.role = 'board_member'
    where poll.id = p_poll_id
  )
  or exists (
    select 1 from public.app_admins
    where auth_user_id = (select auth.uid())
  );
$function$;

create or replace function private.can_manage_poll_post(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select (select private.can_manage_club_content(post.club_id)
          from public.club_posts as post where post.id = p_post_id)
  or exists (
    select 1 from public.app_admins
    where auth_user_id = (select auth.uid())
  );
$function$;

revoke all on function private.can_manage_poll(uuid) from public, anon;
revoke all on function private.can_manage_poll_post(uuid) from public, anon;
grant execute on function private.can_manage_poll(uuid) to authenticated;
grant execute on function private.can_manage_poll_post(uuid) to authenticated;

create or replace function private.bind_and_validate_poll_vote()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_option_count integer;
begin
  if auth.uid() is null then
    raise exception 'An authenticated voter is required' using errcode = '42501';
  end if;
  new.profile_id := auth.uid();

  select jsonb_array_length(poll.options) into v_option_count
  from public.polls as poll
  where poll.id = new.poll_id;
  if v_option_count is null then
    raise exception 'Poll does not exist' using errcode = '23503';
  end if;
  if new.option_index < 0 or new.option_index >= v_option_count then
    raise exception 'Poll option index is out of range' using errcode = '23514';
  end if;
  return new;
end
$function$;

revoke all on function private.bind_and_validate_poll_vote() from public, anon, authenticated;

drop trigger if exists bind_and_validate_poll_vote on public.poll_votes;
create trigger bind_and_validate_poll_vote
before insert or update on public.poll_votes
for each row execute function private.bind_and_validate_poll_vote();

alter table public.polls enable row level security;
alter table public.poll_votes enable row level security;
revoke all on table public.polls from public, anon, authenticated;
revoke all on table public.poll_votes from public, anon, authenticated;
grant select, insert, update, delete on table public.polls to authenticated;
grant select, insert, update, delete on table public.poll_votes to authenticated;

drop policy if exists polls_select on public.polls;
drop policy if exists polls_insert on public.polls;
drop policy if exists polls_update on public.polls;
drop policy if exists polls_delete on public.polls;
drop policy if exists polls_read_visible_posts on public.polls;
drop policy if exists polls_insert_managers on public.polls;
drop policy if exists polls_update_managers on public.polls;
drop policy if exists polls_delete_managers on public.polls;

create policy polls_read_visible_posts
on public.polls for select to authenticated
using (exists (select 1 from public.club_posts where id = post_id));
create policy polls_insert_managers
on public.polls for insert to authenticated
with check ((select private.can_manage_poll_post(post_id)));
create policy polls_update_managers
on public.polls for update to authenticated
using ((select private.can_manage_poll(id)))
with check ((select private.can_manage_poll_post(post_id)));
create policy polls_delete_managers
on public.polls for delete to authenticated
using ((select private.can_manage_poll(id)));

drop policy if exists poll_votes_select on public.poll_votes;
drop policy if exists poll_votes_insert on public.poll_votes;
drop policy if exists poll_votes_update on public.poll_votes;
drop policy if exists poll_votes_delete on public.poll_votes;
drop policy if exists poll_votes_read_visible on public.poll_votes;
drop policy if exists poll_votes_insert_own on public.poll_votes;
drop policy if exists poll_votes_update_own on public.poll_votes;
drop policy if exists poll_votes_delete_own on public.poll_votes;

create policy poll_votes_read_visible
on public.poll_votes for select to authenticated
using (exists (select 1 from public.polls where id = poll_id));
create policy poll_votes_insert_own
on public.poll_votes for insert to authenticated
with check (profile_id = (select auth.uid()));
create policy poll_votes_update_own
on public.poll_votes for update to authenticated
using (profile_id = (select auth.uid()))
with check (profile_id = (select auth.uid()));
create policy poll_votes_delete_own
on public.poll_votes for delete to authenticated
using (profile_id = (select auth.uid()));
