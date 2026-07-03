-- Club polls and announcements. Run after 002_event_checkins.sql.

-- Announcement flag on posts (megaphone banner + sorts to top).
alter table club_posts
  add column if not exists is_announcement boolean not null default false;

-- One optional poll per post; options stored as a jsonb string array
-- (the option index doubles as the option id).
create table if not exists polls (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null unique,
  question text not null,
  options jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists poll_votes (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references polls(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  option_index int not null,
  created_at timestamptz not null default now(),
  unique (poll_id, profile_id)
);

alter table polls enable row level security;
alter table poll_votes enable row level security;

create policy "polls_select" on polls for select using (true);
create policy "polls_insert" on polls for insert with check (true);
create policy "poll_votes_select" on poll_votes for select using (true);
create policy "poll_votes_insert" on poll_votes for insert with check (true);
create policy "poll_votes_update" on poll_votes for update using (true);
create policy "poll_votes_delete" on poll_votes for delete using (true);
