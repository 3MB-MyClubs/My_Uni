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
