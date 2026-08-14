-- Canonical consolidation of the two historical 005 migrations.
-- Original byte-for-byte sources are retained in supabase/legacy_migrations/duplicates/.

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

-- ---- originally 005_direct_message_delivery_status.sql ----

-- Delivered / Seen lifecycle for student direct messages.
-- `delivered_at` is assigned when Supabase stores the message. `seen_at` is
-- written only by the recipient after opening that exact conversation.

alter table direct_messages
  add column if not exists delivered_at timestamptz;

alter table direct_messages
  add column if not exists seen_at timestamptz;

update direct_messages
set delivered_at = created_at
where delivered_at is null;

-- Preserve read receipts created by migration 004.
update direct_messages
set seen_at = read_at
where seen_at is null and read_at is not null;

alter table direct_messages
  alter column delivered_at set default now();

alter table direct_messages
  alter column delivered_at set not null;

create index if not exists direct_messages_unseen_recipient_idx
  on direct_messages (receiver_id, sender_id, created_at)
  where seen_at is null;

-- UPDATE events must carry the complete row so senders receive the new
-- `seen_at` value immediately through Supabase Realtime.
alter table direct_messages replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'direct_messages'
  ) then
    alter publication supabase_realtime add table direct_messages;
  end if;
end
$$;



