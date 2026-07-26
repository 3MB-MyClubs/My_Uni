-- App Store Guideline 1.2 moderation queue and user blocking.
-- Apply before submitting the next iOS build.

create table if not exists moderation_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references profiles(id) on delete cascade,
  reported_user_id uuid references profiles(id) on delete set null,
  target_type text not null check (target_type in ('post', 'comment', 'profile', 'message', 'event')),
  target_id text not null,
  reason text not null check (reason in (
    'harassment',
    'hate_or_discrimination',
    'sexual_content',
    'violence_or_danger',
    'spam_or_scam',
    'other'
  )),
  source text not null default 'report' check (source in ('report', 'block')),
  content_snapshot text check (char_length(content_snapshot) <= 2000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'actioned', 'dismissed')),
  action_notes text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references profiles(id) on delete set null
);

create index if not exists moderation_reports_open_idx
  on moderation_reports (status, created_at);
create index if not exists moderation_reports_target_idx
  on moderation_reports (target_type, target_id);

alter table moderation_reports enable row level security;

create policy "moderation_reports_insert_own" on moderation_reports
  for insert with check (reporter_id = auth.uid());

-- Report contents are intentionally not readable through the publishable-key
-- client. Moderators review them through the Supabase dashboard/service role.

create table if not exists user_blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx
  on user_blocks (blocked_id);

alter table user_blocks enable row level security;

create policy "user_blocks_select_own" on user_blocks
  for select using (blocker_id = auth.uid());

create policy "user_blocks_insert_own" on user_blocks
  for insert with check (blocker_id = auth.uid());

create policy "user_blocks_update_own" on user_blocks
  for update using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

create policy "user_blocks_delete_own" on user_blocks
  for delete using (blocker_id = auth.uid());

-- The publishable client runs as the authenticated Postgres role after login.
-- RLS policies restrict rows; these grants expose only the operations the app
-- needs through the Data API.
grant insert on table moderation_reports to authenticated;
grant select, insert, update, delete on table user_blocks to authenticated;
