-- Comments on club posts (flat in v1; parent_comment_id reserved for threads).
-- Run in the Supabase SQL editor. RLS mirrors the permissive prototype posture
-- of post_likes/event_rsvps: app-level gating, publishable-key client.

create table if not exists post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null,
  profile_id uuid not null references profiles(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 2000),
  parent_comment_id uuid references post_comments(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists post_comments_post_idx
  on post_comments (post_id, created_at);

alter table post_comments enable row level security;

create policy "post_comments_select" on post_comments
  for select using (true);

create policy "post_comments_insert" on post_comments
  for insert with check (true);

create policy "post_comments_delete" on post_comments
  for delete using (true);
