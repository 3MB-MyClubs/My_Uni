-- Persist delegated group admins and allow any persisted group admin to
-- delete the group. Deleting the group cascades to members and messages.

alter table public.group_chats
  add column if not exists admin_ids uuid[] not null default '{}';

create or replace function private.is_group_chat_admin(target_group_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.group_chats
    where id = target_group_id
      and (
        creator_id = (select auth.uid())
        or (
          (select auth.uid()) = any(admin_ids)
          and exists (
            select 1
            from public.group_chat_members
            where group_id = public.group_chats.id
              and user_id = (select auth.uid())
          )
        )
      )
  );
$$;

grant usage on schema private to authenticated;
revoke all on function private.is_group_chat_admin(uuid) from public, anon;
grant execute on function private.is_group_chat_admin(uuid) to authenticated;

grant delete on public.group_chats to authenticated;

drop policy if exists "group_delete_admin" on public.group_chats;
create policy "group_delete_admin"
  on public.group_chats
  for delete to authenticated
  using ((select private.is_group_chat_admin(id)));
