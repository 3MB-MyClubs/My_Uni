-- Disposable test-only baseline for Chat v2. The repository's historical
-- migrations start after the production core schema, so this fixture recreates
-- the relevant production-shaped tables, grants, and RLS before applying the
-- additive rate-limit and Chat v2 migrations. It is never deployed.

\ir feed_v2_production_baseline.sql

create schema if not exists storage;
set role supabase_admin;
create table if not exists storage.buckets (
  id text primary key,
  file_size_limit bigint,
  allowed_mime_types text[]
);
reset role;

create table public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  message_kind text not null default 'text',
  payload jsonb not null default '{}'::jsonb,
  crypto_version smallint,
  created_at timestamptz not null default now(),
  delivered_at timestamptz not null default now(),
  seen_at timestamptz,
  read_at timestamptz,
  constraint direct_messages_content_check check (
    char_length(content) <= 4000
    and (char_length(content) >= 1 or (message_kind <> 'text' and payload <> '{}'::jsonb))
  ),
  constraint direct_messages_message_kind_check check (
    message_kind in ('text', 'announcement', 'poll', 'event', 'post_share', 'photo', 'file', 'system')
  ),
  constraint direct_messages_payload_size_check check (pg_column_size(payload) <= 65536)
);

create table public.group_chats (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  admin_ids uuid[] not null default '{}',
  custom_name text,
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.group_chat_members (
  group_id uuid not null references public.group_chats(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  position integer not null default 0,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table public.group_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.group_chats(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  message_kind text not null default 'text',
  payload jsonb not null default '{}'::jsonb,
  crypto_version smallint,
  created_at timestamptz not null default now(),
  constraint group_messages_content_check check (
    char_length(content) <= 4000
    and (char_length(content) >= 1 or (message_kind <> 'text' and payload <> '{}'::jsonb))
  ),
  constraint group_messages_message_kind_check check (
    message_kind in ('text', 'announcement', 'poll', 'event', 'post_share', 'photo', 'file', 'system')
  ),
  constraint group_messages_payload_size_check check (pg_column_size(payload) <= 65536)
);

create table public.group_message_receipts (
  message_id uuid not null references public.group_messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  delivered_at timestamptz,
  seen_at timestamptz,
  primary key (message_id, user_id)
);

create table public.club_channel_messages (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  sender_auth_id uuid not null references auth.users(id) on delete restrict,
  sender_profile_id uuid references public.profiles(id) on delete set null,
  sender_club_id uuid references public.clubs(id) on delete set null,
  content text not null default '',
  message_kind text not null default 'text',
  payload jsonb not null default '{}'::jsonb,
  crypto_version smallint,
  created_at timestamptz not null default now(),
  check ((sender_profile_id is null) <> (sender_club_id is null)),
  check (sender_club_id is null or sender_club_id = club_id),
  constraint club_channel_messages_content_check check (
    char_length(content) <= 4000
    and (char_length(content) >= 1 or (message_kind <> 'text' and payload <> '{}'::jsonb))
  ),
  constraint club_channel_messages_payload_size_check check (pg_column_size(payload) <= 65536)
);

create table public.club_inbox_threads (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (club_id, profile_id)
);

create table public.club_inbox_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.club_inbox_threads(id) on delete cascade,
  sender_auth_id uuid not null references auth.users(id) on delete restrict,
  sender_profile_id uuid references public.profiles(id) on delete set null,
  sender_club_id uuid references public.clubs(id) on delete set null,
  content text not null default '',
  message_kind text not null default 'text',
  payload jsonb not null default '{}'::jsonb,
  crypto_version smallint,
  created_at timestamptz not null default now(),
  delivered_at timestamptz not null default now(),
  seen_at timestamptz,
  check ((sender_profile_id is null) <> (sender_club_id is null)),
  constraint club_inbox_messages_content_check check (
    char_length(content) <= 4000
    and (char_length(content) >= 1 or (message_kind <> 'text' and payload <> '{}'::jsonb))
  ),
  constraint club_inbox_messages_payload_size_check check (pg_column_size(payload) <= 65536)
);

create index group_chat_members_user_idx on public.group_chat_members (user_id, group_id);
create index group_message_receipts_user_seen_idx on public.group_message_receipts (user_id, seen_at);
create index club_inbox_threads_profile_updated_idx on public.club_inbox_threads (profile_id, updated_at desc);
create index club_inbox_threads_club_updated_idx on public.club_inbox_threads (club_id, updated_at desc);

create or replace function private.is_group_chat_member(target_group_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_chat_members as member
    where member.group_id = target_group_id
      and member.user_id = (select auth.uid())
  )
$$;

grant execute on function private.is_group_chat_member(uuid) to authenticated;

grant select, insert, update, delete on public.direct_messages,
  public.group_messages, public.club_channel_messages,
  public.club_inbox_messages to authenticated;
grant select, insert, update, delete on public.group_chats,
  public.group_chat_members, public.club_inbox_threads to authenticated;
grant select, insert, update on public.group_message_receipts to authenticated;

alter table public.direct_messages enable row level security;
alter table public.group_chats enable row level security;
alter table public.group_chat_members enable row level security;
alter table public.group_messages enable row level security;
alter table public.group_message_receipts enable row level security;
alter table public.club_channel_messages enable row level security;
alter table public.club_inbox_threads enable row level security;
alter table public.club_inbox_messages enable row level security;

create policy dm_select_participants on public.direct_messages
  for select to authenticated
  using ((select auth.uid()) in (sender_id, receiver_id));
create policy dm_insert_sender on public.direct_messages
  for insert to authenticated
  with check (sender_id = (select auth.uid()));
create policy dm_update_receiver on public.direct_messages
  for update to authenticated
  using (receiver_id = (select auth.uid()))
  with check (receiver_id = (select auth.uid()));
create policy dm_delete_sender on public.direct_messages
  for delete to authenticated using (sender_id = (select auth.uid()));

create policy group_chats_select_members on public.group_chats
  for select to authenticated
  using ((select private.is_group_chat_member(id)) or creator_id = (select auth.uid()));
create policy group_chats_insert_creator on public.group_chats
  for insert to authenticated with check (creator_id = (select auth.uid()));
create policy group_members_select_members on public.group_chat_members
  for select to authenticated using ((select private.is_group_chat_member(group_id)));
create policy group_members_insert_creator on public.group_chat_members
  for insert to authenticated
  with check (exists (
    select 1 from public.group_chats as chat
    where chat.id = group_id and chat.creator_id = (select auth.uid())
  ));
create policy group_messages_select_members on public.group_messages
  for select to authenticated using ((select private.is_group_chat_member(group_id)));
create policy group_messages_insert_members on public.group_messages
  for insert to authenticated
  with check (sender_id = (select auth.uid()) and (select private.is_group_chat_member(group_id)));
create policy group_messages_delete_sender on public.group_messages
  for delete to authenticated using (sender_id = (select auth.uid()));
create policy group_receipts_select_members on public.group_message_receipts
  for select to authenticated using (exists (
    select 1 from public.group_messages as message
    where message.id = message_id and (select private.is_group_chat_member(message.group_id))
  ));
create policy group_receipts_insert_own on public.group_message_receipts
  for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.group_messages as message
    where message.id = message_id and (select private.is_group_chat_member(message.group_id))
  ));
create policy group_receipts_update_own on public.group_message_receipts
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy club_channel_read on public.club_channel_messages
  for select to authenticated using (
    exists (select 1 from public.club_followers as follower
      where follower.club_id = club_channel_messages.club_id
        and follower.profile_id = (select auth.uid()))
    or exists (select 1 from public.club_auth_accounts as account
      where account.club_id = club_channel_messages.club_id
        and account.auth_user_id = (select auth.uid()))
  );
create policy club_channel_insert_board on public.club_channel_messages
  for insert to authenticated with check (
    sender_auth_id = (select auth.uid()) and (
      (sender_profile_id = (select auth.uid()) and exists (
        select 1 from public.club_followers as follower
        where follower.club_id = club_channel_messages.club_id
          and follower.profile_id = (select auth.uid())
          and follower.role = 'board_member'
      ))
      or (sender_club_id = club_channel_messages.club_id and exists (
        select 1 from public.club_auth_accounts as account
        where account.club_id = club_channel_messages.club_id
          and account.auth_user_id = (select auth.uid())
      ))
    )
  );

create policy club_inbox_threads_read on public.club_inbox_threads
  for select to authenticated using (
    profile_id = (select auth.uid())
    or exists (select 1 from public.club_auth_accounts as account
      where account.club_id = club_inbox_threads.club_id
        and account.auth_user_id = (select auth.uid()))
    or exists (select 1 from public.club_followers as follower
      where follower.club_id = club_inbox_threads.club_id
        and follower.profile_id = (select auth.uid())
        and follower.role = 'board_member')
  );
create policy club_inbox_threads_insert on public.club_inbox_threads
  for insert to authenticated with check (
    profile_id = (select auth.uid()) and exists (
      select 1 from public.club_followers as follower
      where follower.club_id = club_inbox_threads.club_id
        and follower.profile_id = (select auth.uid())
    )
  );
create policy club_inbox_threads_update on public.club_inbox_threads
  for update to authenticated using (
    profile_id = (select auth.uid())
    or exists (select 1 from public.club_auth_accounts as account
      where account.club_id = club_inbox_threads.club_id
        and account.auth_user_id = (select auth.uid()))
    or exists (select 1 from public.club_followers as follower
      where follower.club_id = club_inbox_threads.club_id
        and follower.profile_id = (select auth.uid())
        and follower.role = 'board_member')
  );
create policy club_inbox_messages_read on public.club_inbox_messages
  for select to authenticated using (exists (
    select 1 from public.club_inbox_threads as inbox
    where inbox.id = club_inbox_messages.thread_id and (
      inbox.profile_id = (select auth.uid())
      or exists (select 1 from public.club_auth_accounts as account
        where account.club_id = inbox.club_id
          and account.auth_user_id = (select auth.uid()))
      or exists (select 1 from public.club_followers as follower
        where follower.club_id = inbox.club_id
          and follower.profile_id = (select auth.uid())
          and follower.role = 'board_member')
    )
  ));
create policy club_inbox_messages_insert on public.club_inbox_messages
  for insert to authenticated with check (
    sender_auth_id = (select auth.uid()) and exists (
      select 1 from public.club_inbox_threads as inbox
      where inbox.id = club_inbox_messages.thread_id and (
        (inbox.profile_id = (select auth.uid())
          and sender_profile_id = (select auth.uid()) and sender_club_id is null)
        or (sender_profile_id is null and sender_club_id = inbox.club_id and (
          exists (select 1 from public.club_auth_accounts as account
            where account.club_id = inbox.club_id
              and account.auth_user_id = (select auth.uid()))
          or exists (select 1 from public.club_followers as follower
            where follower.club_id = inbox.club_id
              and follower.profile_id = (select auth.uid())
              and follower.role = 'board_member')
        ))
      )
    )
  );
create policy club_inbox_messages_update_recipient on public.club_inbox_messages
  for update to authenticated using (sender_auth_id <> (select auth.uid()))
  with check (sender_auth_id <> (select auth.uid()));

