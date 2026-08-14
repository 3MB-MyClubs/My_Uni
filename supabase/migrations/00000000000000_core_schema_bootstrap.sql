-- Fresh-environment bootstrap for the production core schema that predates
-- this repository's legacy migration chain. This migration is intentionally
-- additive: it creates only objects that the historical 001+ migrations
-- assumed already existed. Applied production migrations are not rewritten.

create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;

create table public.academic_years (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.club_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  icon_name text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.interests (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.majors (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null,
  role text not null default 'student',
  avatar_url text,
  bio text,
  major_id uuid references public.majors(id) on delete set null,
  academic_year_id uuid references public.academic_years(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  short_name text,
  description text,
  logo_url text,
  category_id uuid references public.club_categories(id) on delete set null,
  email text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.club_auth_accounts (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  club_id uuid not null references public.clubs(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.club_followers (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  role_title text,
  created_at timestamptz not null default now(),
  constraint club_followers_club_profile_key unique (club_id, profile_id)
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
  created_by_user_id uuid,
  tags text[] not null default '{}',
  registration_url text,
  schedule jsonb,
  speakers jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.event_rsvps (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint event_rsvps_event_profile_key unique (event_id, profile_id)
);

create table public.post_likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.club_posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint post_likes_post_profile_key unique (post_id, profile_id)
);

create table public.post_views (
  post_id uuid not null references public.club_posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  viewed_at timestamptz default now(),
  primary key (post_id, profile_id)
);

create table public.profile_follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint profile_follows_pair_key unique (follower_id, following_id),
  constraint profile_follows_not_self check (follower_id <> following_id)
);

create table public.profile_double_majors (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  major_id uuid not null references public.majors(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint profile_double_majors_pair_key unique (profile_id, major_id)
);

create table public.profile_minors (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  major_id uuid not null references public.majors(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint profile_minors_pair_key unique (profile_id, major_id)
);

create table public.student_interests (
  user_id uuid not null references public.profiles(id) on delete cascade,
  interest_id uuid not null references public.interests(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, interest_id)
);

create index club_posts_club_created_idx on public.club_posts (club_id, created_at desc);
create index event_rsvps_profile_idx on public.event_rsvps (profile_id);
create index post_likes_profile_idx on public.post_likes (profile_id);
create index profile_follows_following_idx on public.profile_follows (following_id, follower_id);

create view public.club_member_counts
with (security_invoker = true) as
select club_id, count(*)::bigint as member_count
from public.club_followers group by club_id;

create view public.event_rsvp_counts
with (security_invoker = true) as
select event_id, count(*)::bigint as rsvp_count
from public.event_rsvps group by event_id;

create view public.post_like_counts
with (security_invoker = true) as
select post_id, count(*)::bigint as like_count
from public.post_likes group by post_id;

create or replace function public.is_club_auth_account_for(target_club_id uuid)
returns boolean
language sql stable security invoker
set search_path = ''
as $$
  select exists (
    select 1 from public.club_auth_accounts account
    where account.auth_user_id = (select auth.uid())
      and account.club_id = target_club_id
  );
$$;

create or replace function public.cleanup_expired_events()
returns integer
language plpgsql security invoker
set search_path = ''
as $$
declare deleted_count integer;
begin
  delete from public.events
  where coalesce(ends_at, starts_at) < clock_timestamp() - interval '90 days';
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

create or replace function public.restrict_signup_to_ku(event jsonb)
returns jsonb
language plpgsql stable
set search_path = ''
as $$
declare signup_email text := lower(coalesce(event #>> '{user,email}', ''));
begin
  if signup_email !~ '^[^@]+@ku\.edu\.tr$' then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 403,
      'message', 'Only ku.edu.tr email addresses may sign up.'
    ));
  end if;
  return '{}'::jsonb;
end;
$$;

create or replace function public.rls_auto_enable()
returns event_trigger
language plpgsql security definer
set search_path = ''
as $$
declare command record;
begin
  for command in select * from pg_event_trigger_ddl_commands() loop
    if command.object_type = 'table'
       and command.schema_name = 'public' then
      execute format('alter table %s enable row level security', command.object_identity);
    end if;
  end loop;
end;
$$;

revoke all on function public.rls_auto_enable() from public;

alter table public.academic_years enable row level security;
alter table public.club_categories enable row level security;
alter table public.interests enable row level security;
alter table public.majors enable row level security;
alter table public.profiles enable row level security;
alter table public.clubs enable row level security;
alter table public.club_auth_accounts enable row level security;
alter table public.club_followers enable row level security;
alter table public.club_posts enable row level security;
alter table public.events enable row level security;
alter table public.event_rsvps enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_views enable row level security;
alter table public.profile_follows enable row level security;
alter table public.profile_double_majors enable row level security;
alter table public.profile_minors enable row level security;
alter table public.student_interests enable row level security;

create policy "Reference academic years are readable" on public.academic_years
  for select to anon, authenticated using (is_active);
create policy "Active club categories are readable" on public.club_categories
  for select to anon, authenticated using (is_active);
create policy "Authenticated users can read interests" on public.interests
  for select to authenticated using (is_active);
create policy "Authenticated users can read majors" on public.majors
  for select to authenticated using (is_active);
create policy "Authenticated users can read profiles" on public.profiles
  for select to authenticated using (true);
create policy "Users can create own profile" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);
create policy "Users can update own profile" on public.profiles
  for update to authenticated using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
create policy "Anyone can read active clubs" on public.clubs
  for select to anon, authenticated using (is_active);
create policy "Club account can see itself" on public.club_auth_accounts
  for select to authenticated using ((select auth.uid()) = auth_user_id);
create policy "Anyone can read club followers" on public.club_followers
  for select to authenticated using (true);
create policy "Users can follow clubs" on public.club_followers
  for insert to authenticated with check ((select auth.uid()) = profile_id);
create policy "Users can unfollow clubs" on public.club_followers
  for delete to authenticated using ((select auth.uid()) = profile_id);
create policy "Anyone can read club posts" on public.club_posts
  for select to anon, authenticated using (true);
create policy "Anyone can read public events" on public.events
  for select to anon, authenticated using (is_public);
create policy "Authenticated users can read event RSVPs" on public.event_rsvps
  for select to authenticated using (true);
create policy "Users can RSVP events" on public.event_rsvps
  for insert to authenticated with check ((select auth.uid()) = profile_id);
create policy "Users can cancel event RSVP" on public.event_rsvps
  for delete to authenticated using ((select auth.uid()) = profile_id);
create policy "Authenticated users can read post likes" on public.post_likes
  for select to authenticated using (true);
create policy "Users can like posts" on public.post_likes
  for insert to authenticated with check ((select auth.uid()) = profile_id);
create policy "Users can unlike posts" on public.post_likes
  for delete to authenticated using ((select auth.uid()) = profile_id);
create policy "Anyone can read post views" on public.post_views
  for select to authenticated using (true);
create policy "Authenticated users can insert their own post views" on public.post_views
  for insert to authenticated with check ((select auth.uid()) = profile_id);
create policy "Authenticated users can update their own post views" on public.post_views
  for update to authenticated using ((select auth.uid()) = profile_id)
  with check ((select auth.uid()) = profile_id);
create policy "Users can read profile follows" on public.profile_follows
  for select to authenticated using (true);
create policy "Users can follow people" on public.profile_follows
  for insert to authenticated with check ((select auth.uid()) = follower_id);
create policy "Users can unfollow people" on public.profile_follows
  for delete to authenticated using ((select auth.uid()) = follower_id);
create policy "Users can manage own double majors" on public.profile_double_majors
  for all to authenticated using ((select auth.uid()) = profile_id)
  with check ((select auth.uid()) = profile_id);
create policy "Users can manage own minors" on public.profile_minors
  for all to authenticated using ((select auth.uid()) = profile_id)
  with check ((select auth.uid()) = profile_id);
create policy "Users can read student interests" on public.student_interests
  for select to authenticated using (true);
create policy "Users can manage own interests" on public.student_interests
  for all to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

grant usage on schema public to anon, authenticated;
grant select on public.academic_years, public.club_categories to anon;
grant select on public.academic_years, public.club_categories, public.interests,
  public.majors, public.profiles, public.clubs, public.club_auth_accounts,
  public.club_followers, public.club_posts, public.events, public.event_rsvps,
  public.post_likes, public.post_views, public.profile_follows,
  public.profile_double_majors, public.profile_minors, public.student_interests,
  public.club_member_counts, public.event_rsvp_counts, public.post_like_counts
  to authenticated;
grant insert, update on public.profiles to authenticated;
grant insert, update, delete on public.club_posts, public.events to authenticated;
grant insert, update, delete on public.club_followers to authenticated;
grant insert, delete on public.event_rsvps, public.post_likes,
  public.profile_follows to authenticated;
grant insert, update, delete on public.post_views, public.profile_double_majors,
  public.profile_minors, public.student_interests to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 10485760, array['image/jpeg','image/png','image/webp']),
  ('club-avatars', 'club-avatars', true, 10485760, array['image/jpeg','image/png','image/webp']),
  ('post-images', 'post-images', true, 10485760, array['image/jpeg','image/png','image/webp']),
  ('event-images', 'event-images', true, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Users can upload own avatar" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "Users can update own avatar" on storage.objects
  for update to authenticated using (
    bucket_id = 'avatars' and owner_id = (select auth.uid()::text)
  ) with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "Users can delete own avatar" on storage.objects
  for delete to authenticated using (
    bucket_id = 'avatars' and owner_id = (select auth.uid()::text)
  );
create policy "Club admins can upload own club avatars" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'club-avatars' and (storage.foldername(name))[1] = 'clubs'
    and exists (select 1 from public.club_auth_accounts account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2])
  );
create policy "Club admins can update own club avatars" on storage.objects
  for update to authenticated using (
    bucket_id = 'club-avatars' and exists (select 1 from public.club_auth_accounts account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2])
  ) with check (bucket_id = 'club-avatars');
create policy "Club admins can delete own club avatars" on storage.objects
  for delete to authenticated using (
    bucket_id = 'club-avatars' and exists (select 1 from public.club_auth_accounts account
      where account.auth_user_id = (select auth.uid())
        and account.club_id::text = (storage.foldername(name))[2])
  );
