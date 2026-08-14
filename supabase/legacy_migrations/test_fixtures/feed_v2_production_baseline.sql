-- Disposable test-only baseline for repositories whose historical migration
-- chain starts after the core production tables. This file is never deployed.

create schema if not exists private;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null,
  role text not null default 'student',
  avatar_url text,
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  major_id uuid,
  academic_year_id uuid,
  tes boolean
);

create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  short_name text,
  description text,
  logo_url text,
  category_id uuid,
  email text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  tes boolean
);

create table public.club_auth_accounts (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  club_id uuid not null references public.clubs(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table public.app_admins (
  singleton boolean primary key default true check (singleton),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  email text not null,
  created_at timestamptz not null default now()
);
create table public.club_followers (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  role_title text,
  created_at timestamptz not null default now(),
  unique (club_id, profile_id),
  unique (profile_id, club_id)
);
create table public.club_account_contexts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  club_id uuid not null references public.clubs(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.club_posts (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  content text not null,
  image_url text,
  image_path text,
  author_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index club_posts_club_created_idx
  on public.club_posts (club_id, created_at desc);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  title text not null,
  description text,
  location text,
  image_url text,
  image_path text,
  event_date date not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by_user_id uuid,
  tags text[] not null default '{}',
  registration_url text,
  schedule jsonb,
  speakers jsonb
);

create table public.post_likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.club_posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, profile_id),
  unique (profile_id, post_id)
);
create table public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.club_posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index post_comments_post_created_idx
  on public.post_comments (post_id, created_at);
create table public.post_views (
  post_id uuid not null references public.club_posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  viewed_at timestamptz default now(),
  primary key (post_id, profile_id)
);
create table public.event_rsvps (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (event_id, profile_id),
  unique (profile_id, event_id)
);
create table public.profile_follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (follower_id, following_id)
);
create table public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);
create table public.club_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  club_id uuid not null references public.clubs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, club_id)
);

create index club_followers_profile_idx on public.club_followers (profile_id);
create index post_likes_post_profile_idx on public.post_likes (post_id, profile_id);
create index event_rsvps_event_profile_idx on public.event_rsvps (event_id, profile_id);
create index profile_follows_following_idx on public.profile_follows (following_id, follower_id);
create index user_blocks_blocked_idx on public.user_blocks (blocked_id);
create index club_blocks_club_idx on public.club_blocks (club_id);

create or replace function private.can_view_club(target_club_id uuid)
returns boolean
language sql
stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.clubs as club
    where club.id = target_club_id
      and (
        club.tes is not true
        or exists (
          select 1 from public.profiles as profile
          where profile.id = (select auth.uid()) and profile.tes is true
        )
        or exists (
          select 1 from public.club_auth_accounts as account
          where account.auth_user_id = (select auth.uid())
        )
        or exists (
          select 1 from public.app_admins as app_admin
          where app_admin.auth_user_id = (select auth.uid())
        )
      )
  );
$$;

create or replace function private.can_manage_club_content(target_club_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.club_auth_accounts as account
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

grant usage on schema public, private to authenticated;
grant execute on function private.can_view_club(uuid) to anon, authenticated;
grant execute on function private.can_manage_club_content(uuid) to authenticated;

grant select on public.profiles, public.clubs, public.club_auth_accounts,
  public.app_admins, public.club_followers, public.club_account_contexts,
  public.club_posts, public.events, public.post_likes, public.post_comments,
  public.post_views, public.event_rsvps, public.profile_follows,
  public.user_blocks, public.club_blocks to authenticated;
grant insert, delete on public.post_likes, public.post_comments,
  public.post_views, public.event_rsvps, public.profile_follows,
  public.user_blocks, public.club_blocks to authenticated;
grant insert, update, delete on public.club_posts, public.events to authenticated;
grant insert, update, delete on public.club_followers to authenticated;

alter table public.profiles enable row level security;
alter table public.clubs enable row level security;
alter table public.club_auth_accounts enable row level security;
alter table public.app_admins enable row level security;
alter table public.club_followers enable row level security;
alter table public.club_account_contexts enable row level security;
alter table public.club_posts enable row level security;
alter table public.events enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.post_views enable row level security;
alter table public.event_rsvps enable row level security;
alter table public.profile_follows enable row level security;
alter table public.user_blocks enable row level security;
alter table public.club_blocks enable row level security;

create policy profiles_read on public.profiles for select to authenticated using (true);
create policy clubs_read on public.clubs for select to authenticated
  using (is_active is true and (select private.can_view_club(id)));
create policy club_auth_read_own on public.club_auth_accounts for select to authenticated
  using (auth_user_id = (select auth.uid()));
create policy app_admin_read_own on public.app_admins for select to authenticated
  using (auth_user_id = (select auth.uid()));
create policy club_followers_read on public.club_followers for select to authenticated using (true);
create policy club_followers_insert_own on public.club_followers for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy club_context_read_own on public.club_account_contexts for select to authenticated
  using (user_id = (select auth.uid()));
create policy posts_read on public.club_posts for select to authenticated
  using ((select private.can_view_club(club_id)));
create policy posts_write on public.club_posts for all to authenticated
  using ((select private.can_manage_club_content(club_id)))
  with check ((select private.can_manage_club_content(club_id)));
create policy events_read on public.events for select to authenticated
  using ((select private.can_view_club(club_id)));
create policy events_write on public.events for all to authenticated
  using ((select private.can_manage_club_content(club_id)))
  with check ((select private.can_manage_club_content(club_id)));
create policy post_likes_read on public.post_likes for select to authenticated using (true);
create policy post_likes_insert on public.post_likes for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy post_likes_delete on public.post_likes for delete to authenticated
  using (profile_id = (select auth.uid()));
create policy comments_read on public.post_comments for select to authenticated using (true);
create policy comments_insert on public.post_comments for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy comments_delete on public.post_comments for delete to authenticated
  using (profile_id = (select auth.uid()));
create policy views_read on public.post_views for select to authenticated using (true);
create policy views_insert on public.post_views for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy views_delete on public.post_views for delete to authenticated
  using (profile_id = (select auth.uid()));
create policy rsvps_read on public.event_rsvps for select to authenticated using (true);
create policy rsvps_insert on public.event_rsvps for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy rsvps_delete on public.event_rsvps for delete to authenticated
  using (profile_id = (select auth.uid()));
create policy follows_read on public.profile_follows for select to authenticated using (true);
create policy follows_insert on public.profile_follows for insert to authenticated
  with check (follower_id = (select auth.uid()));
create policy follows_delete on public.profile_follows for delete to authenticated
  using (follower_id = (select auth.uid()));
create policy user_blocks_read on public.user_blocks for select to authenticated
  using (blocker_id = (select auth.uid()));
create policy user_blocks_write on public.user_blocks for all to authenticated
  using (blocker_id = (select auth.uid()))
  with check (blocker_id = (select auth.uid()));
create policy club_blocks_read on public.club_blocks for select to authenticated
  using (blocker_id = (select auth.uid()));
create policy club_blocks_write on public.club_blocks for all to authenticated
  using (blocker_id = (select auth.uid()))
  with check (blocker_id = (select auth.uid()));

