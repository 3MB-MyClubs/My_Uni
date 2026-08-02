-- Allow a non-creator to leave a group by deleting only their own
-- membership row. The creator retains the existing ability to remove members.

drop policy if exists "group_members_delete_creator"
  on public.group_chat_members;

drop policy if exists "group_members_delete_creator_or_self"
  on public.group_chat_members;

create policy "group_members_delete_creator_or_self"
  on public.group_chat_members
  for delete to authenticated
  using (
    private.is_group_chat_creator(group_id)
    or (
      user_id = (select auth.uid())
      and not private.is_group_chat_creator(group_id)
    )
  );
