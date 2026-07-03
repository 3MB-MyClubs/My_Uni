-- Event attendance check-ins (QR Event Pass scans + manual door check-ins).
-- Run in the Supabase SQL editor after 001_post_comments.sql.

create table if not exists event_checkins (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null,
  profile_id uuid not null references profiles(id) on delete cascade,
  checked_in_at timestamptz not null default now(),
  checked_in_by text,                       -- admin/club id (may not be an auth user)
  method text not null default 'qr' check (method in ('qr', 'manual')),
  unique (event_id, profile_id)
);

create index if not exists event_checkins_event_idx
  on event_checkins (event_id, checked_in_at);

alter table event_checkins enable row level security;

create policy "event_checkins_select" on event_checkins
  for select using (true);

create policy "event_checkins_insert" on event_checkins
  for insert with check (true);

create policy "event_checkins_delete" on event_checkins
  for delete using (true);
