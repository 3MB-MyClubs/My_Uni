-- Supabase no longer grants Data API access to new tables automatically.
-- Keep table privileges aligned with the existing authenticated-only RLS
-- policies so chat sync can reach Postgres without bypassing authorization.

grant select, insert, update on public.direct_messages to authenticated;

grant select, insert, update on public.group_chats to authenticated;
grant select, insert, update, delete on public.group_chat_members to authenticated;
grant select, insert on public.group_messages to authenticated;

-- Group membership order is maintained with an upsert. Existing rows require
-- an UPDATE policy in addition to the creator-only INSERT/DELETE policies.
create policy "group_members_update_creator"
  on public.group_chat_members
  for update to authenticated
  using (private.is_group_chat_creator(group_id))
  with check (private.is_group_chat_creator(group_id));
