-- Student-created group conversations with optional custom names.

create table if not exists group_chats (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references profiles(id) on delete cascade,
  custom_name text check (custom_name is null or char_length(trim(custom_name)) between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists group_chat_members (
  group_id uuid not null references group_chats(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists group_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references group_chats(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index if not exists group_chat_members_user_idx
  on group_chat_members (user_id, group_id);
create index if not exists group_messages_group_created_idx
  on group_messages (group_id, created_at);

create or replace function is_group_chat_member(target_group_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from group_chat_members
    where group_id = target_group_id and user_id = auth.uid()
  );
$$;

create or replace function is_group_chat_creator(target_group_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from group_chats
    where id = target_group_id and creator_id = auth.uid()
  );
$$;

alter table group_chats enable row level security;
alter table group_chat_members enable row level security;
alter table group_messages enable row level security;

create policy "group_select_members" on group_chats
  for select using (is_group_chat_member(id) or creator_id = auth.uid());
create policy "group_insert_creator" on group_chats
  for insert with check (creator_id = auth.uid());
create policy "group_update_creator" on group_chats
  for update using (creator_id = auth.uid())
  with check (creator_id = auth.uid());

create policy "group_members_select_members" on group_chat_members
  for select using (is_group_chat_member(group_id) or is_group_chat_creator(group_id));
create policy "group_members_insert_creator" on group_chat_members
  for insert with check (is_group_chat_creator(group_id));
create policy "group_members_delete_creator" on group_chat_members
  for delete using (is_group_chat_creator(group_id));

create policy "group_messages_select_members" on group_messages
  for select using (is_group_chat_member(group_id));
create policy "group_messages_insert_members" on group_messages
  for insert with check (
    sender_id = auth.uid() and is_group_chat_member(group_id)
  );

alter table group_chats replica identity full;
alter table group_chat_members replica identity full;
alter table group_messages replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'group_chats'
  ) then
    alter publication supabase_realtime add table group_chats;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'group_chat_members'
  ) then
    alter publication supabase_realtime add table group_chat_members;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'group_messages'
  ) then
    alter publication supabase_realtime add table group_messages;
  end if;
end
$$;
