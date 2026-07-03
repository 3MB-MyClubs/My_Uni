-- Direct messages between students, with realtime delivery.
-- Run after 003_polls_announcements.sql, then enable the table in the
-- Realtime publication (Database → Replication → supabase_realtime).

create table if not exists direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references profiles(id) on delete cascade,
  receiver_id uuid not null references profiles(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 4000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists direct_messages_pair_idx
  on direct_messages (sender_id, receiver_id, created_at);
create index if not exists direct_messages_receiver_idx
  on direct_messages (receiver_id, created_at);

alter table direct_messages enable row level security;

create policy "dm_select_participants" on direct_messages
  for select using (auth.uid() in (sender_id, receiver_id));

create policy "dm_insert_sender" on direct_messages
  for insert with check (sender_id = auth.uid());

create policy "dm_update_receiver" on direct_messages
  for update using (receiver_id = auth.uid());

alter publication supabase_realtime add table direct_messages;
