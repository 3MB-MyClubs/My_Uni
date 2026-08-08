-- A personal account can temporarily act as its own club account when the
-- authenticated profile is a board member of that club. The row is the
-- server-side active-account context; RLS re-checks the board role for every
-- content mutation, so a stale client cannot retain access after demotion.
create table if not exists public.club_account_contexts (
  user_id uuid primary key references auth.users (id) on delete cascade,
  club_id uuid not null references public.clubs (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.club_account_contexts enable row level security;

revoke all on table public.club_account_contexts from anon;
grant select, insert, update, delete
  on table public.club_account_contexts to authenticated;

create index if not exists club_account_contexts_club_id_idx
  on public.club_account_contexts (club_id);

drop policy if exists "Users can read own club account context"
  on public.club_account_contexts;
create policy "Users can read own club account context"
  on public.club_account_contexts
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Board members can select own club account context"
  on public.club_account_contexts;
create policy "Board members can select own club account context"
  on public.club_account_contexts
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.club_followers as follower
      where follower.profile_id = (select auth.uid())
        and follower.club_id = club_account_contexts.club_id
        and follower.role = 'board_member'
    )
  );

drop policy if exists "Board members can update own club account context"
  on public.club_account_contexts;
create policy "Board members can update own club account context"
  on public.club_account_contexts
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.club_followers as follower
      where follower.profile_id = (select auth.uid())
        and follower.club_id = club_account_contexts.club_id
        and follower.role = 'board_member'
    )
  );

drop policy if exists "Users can clear own club account context"
  on public.club_account_contexts;
create policy "Users can clear own club account context"
  on public.club_account_contexts
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- Reusable invoker-side predicate for content and storage policies. It keeps
-- existing standalone club auth accounts working and adds only the selected,
-- board-member context for personal accounts.
create schema if not exists private;

create or replace function private.can_manage_club_content(target_club_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.club_auth_accounts as account
    where account.auth_user_id = (select auth.uid())
      and account.club_id = target_club_id
  )
  or exists (
    select 1
    from public.club_account_contexts as context
    join public.club_followers as follower
      on follower.profile_id = context.user_id
     and follower.club_id = context.club_id
     and follower.role = 'board_member'
    where context.user_id = (select auth.uid())
      and context.club_id = target_club_id
  );
$$;

revoke all on function private.can_manage_club_content(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.can_manage_club_content(uuid) to authenticated;

alter table public.club_posts
  add column if not exists author_id uuid references public.profiles (id) on delete set null;
create index if not exists club_posts_author_id_idx
  on public.club_posts (author_id);

drop policy if exists "Club auth accounts can create their club posts"
  on public.club_posts;
create policy "Club auth accounts can create their club posts"
  on public.club_posts
  for insert
  to authenticated
  with check ((select private.can_manage_club_content(club_id)));

drop policy if exists "Club auth accounts can update their club posts"
  on public.club_posts;
create policy "Club auth accounts can update their club posts"
  on public.club_posts
  for update
  to authenticated
  using ((select private.can_manage_club_content(club_id)))
  with check ((select private.can_manage_club_content(club_id)));

drop policy if exists "Club auth accounts can delete their club posts"
  on public.club_posts;
create policy "Club auth accounts can delete their club posts"
  on public.club_posts
  for delete
  to authenticated
  using ((select private.can_manage_club_content(club_id)));

drop policy if exists "Club auth accounts can create their club events"
  on public.events;
create policy "Club auth accounts can create their club events"
  on public.events
  for insert
  to authenticated
  with check ((select private.can_manage_club_content(club_id)));

drop policy if exists "Club auth accounts can update their club events"
  on public.events;
create policy "Club auth accounts can update their club events"
  on public.events
  for update
  to authenticated
  using ((select private.can_manage_club_content(club_id)))
  with check ((select private.can_manage_club_content(club_id)));

drop policy if exists "Club auth accounts can delete their club events"
  on public.events;
create policy "Club auth accounts can delete their club events"
  on public.events
  for delete
  to authenticated
  using ((select private.can_manage_club_content(club_id)));

-- The content objects are often accompanied by an image. Keep storage access
-- aligned with the database mutation rule for both linked board accounts and
-- the existing dedicated club auth accounts.
drop policy if exists "Club admins can read own post images" on storage.objects;
create policy "Club admins can read own post images"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = 'club_posts'
    and (select private.can_manage_club_content(((storage.foldername(name))[2])::uuid))
  );

drop policy if exists "Club admins can upload own post images" on storage.objects;
create policy "Club admins can upload own post images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = 'club_posts'
    and (select private.can_manage_club_content(((storage.foldername(name))[2])::uuid))
  );

drop policy if exists "Club admins can update own post images" on storage.objects;
create policy "Club admins can update own post images"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = 'club_posts'
    and (select private.can_manage_club_content(((storage.foldername(name))[2])::uuid))
  )
  with check (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = 'club_posts'
    and (select private.can_manage_club_content(((storage.foldername(name))[2])::uuid))
  );

drop policy if exists "Club admins can delete own post images" on storage.objects;
create policy "Club admins can delete own post images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = 'club_posts'
    and (select private.can_manage_club_content(((storage.foldername(name))[2])::uuid))
  );

drop policy if exists "Club admins can read own event images" on storage.objects;
create policy "Club admins can read own event images"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = 'events'
    and (select private.can_manage_club_content(((storage.foldername(name))[2])::uuid))
  );

drop policy if exists "Club admins can upload own event images" on storage.objects;
create policy "Club admins can upload own event images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = 'events'
    and (select private.can_manage_club_content(((storage.foldername(name))[2])::uuid))
  );

drop policy if exists "Club admins can update own event images" on storage.objects;
create policy "Club admins can update own event images"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = 'events'
    and (select private.can_manage_club_content(((storage.foldername(name))[2])::uuid))
  )
  with check (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = 'events'
    and (select private.can_manage_club_content(((storage.foldername(name))[2])::uuid))
  );

drop policy if exists "Club admins can delete own event images" on storage.objects;
create policy "Club admins can delete own event images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = 'events'
    and (select private.can_manage_club_content(((storage.foldername(name))[2])::uuid))
  );
