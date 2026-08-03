-- Per-member Delivered / Seen lifecycle for student group messages.

create table if not exists group_message_receipts (
  message_id uuid not null references group_messages(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  delivered_at timestamptz,
  seen_at timestamptz,
  primary key (message_id, user_id)
);

create index if not exists group_message_receipts_message_idx
  on group_message_receipts (message_id);
create index if not exists group_message_receipts_user_seen_idx
  on group_message_receipts (user_id, seen_at);

alter table group_message_receipts enable row level security;

revoke all on table group_message_receipts from anon;
grant select, insert, update on table group_message_receipts to authenticated;

drop policy if exists "group_receipts_select_members"
  on group_message_receipts;
create policy "group_receipts_select_members" on group_message_receipts
  for select to authenticated
  using (
    exists (
      select 1
      from group_messages as message
      join group_chat_members as member
        on member.group_id = message.group_id
      where message.id = group_message_receipts.message_id
        and member.user_id = (select auth.uid())
    )
  );

drop policy if exists "group_receipts_insert_own"
  on group_message_receipts;
create policy "group_receipts_insert_own" on group_message_receipts
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from group_messages as message
      join group_chat_members as member
        on member.group_id = message.group_id
      where message.id = group_message_receipts.message_id
        and member.user_id = (select auth.uid())
    )
  );

drop policy if exists "group_receipts_update_own"
  on group_message_receipts;
create policy "group_receipts_update_own" on group_message_receipts
  for update to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1
      from group_messages as message
      join group_chat_members as member
        on member.group_id = message.group_id
      where message.id = group_message_receipts.message_id
        and member.user_id = (select auth.uid())
    )
  )
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from group_messages as message
      join group_chat_members as member
        on member.group_id = message.group_id
      where message.id = group_message_receipts.message_id
        and member.user_id = (select auth.uid())
    )
  );

alter table group_message_receipts replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'group_message_receipts'
  ) then
    alter publication supabase_realtime add table group_message_receipts;
  end if;
end
$$;
