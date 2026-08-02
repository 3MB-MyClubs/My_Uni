-- Restore reliable server-backed messaging without client-managed E2EE keys.
--
-- Existing encrypted rows cannot be converted because the server never had
-- their plaintext or thread keys. Preserve every row and every key table in
-- place, but stop accepting new encrypted messages. The client ignores the
-- retained encrypted rows and uses the new plaintext payload column.

-- Rebuild the two insert policies that previously required a registered E2EE
-- device. Identity and conversation authorization remain unchanged.
drop policy if exists club_channel_insert_board
  on public.club_channel_messages;
create policy club_channel_insert_board
  on public.club_channel_messages for insert to authenticated
  with check (
    sender_auth_id = (select auth.uid())
    and (
      (
        sender_profile_id = (select auth.uid())
        and exists (
          select 1 from public.club_followers cf
          where cf.club_id = club_channel_messages.club_id
            and cf.profile_id = (select auth.uid())
            and cf.role = 'board_member'
        )
      )
      or
      (
        sender_club_id = club_channel_messages.club_id
        and exists (
          select 1 from public.club_auth_accounts ca
          where ca.club_id = club_channel_messages.club_id
            and ca.auth_user_id = (select auth.uid())
        )
      )
    )
  );

drop policy if exists club_inbox_messages_insert_participants
  on public.club_inbox_messages;
create policy club_inbox_messages_insert_participants
  on public.club_inbox_messages for insert to authenticated
  with check (
    sender_auth_id = (select auth.uid())
    and exists (
      select 1 from public.club_inbox_threads cit
      where cit.id = club_inbox_messages.thread_id
        and (
          (
            cit.profile_id = (select auth.uid())
            and sender_profile_id = (select auth.uid())
            and sender_club_id is null
          )
          or
          (
            sender_profile_id is null
            and sender_club_id = cit.club_id
            and exists (
              select 1 from public.club_auth_accounts ca
              where ca.club_id = cit.club_id
                and ca.auth_user_id = (select auth.uid())
            )
          )
          or
          (
            sender_profile_id is null
            and sender_club_id = cit.club_id
            and exists (
              select 1 from public.club_followers cf
              where cf.club_id = cit.club_id
                and cf.profile_id = (select auth.uid())
                and cf.role = 'board_member'
            )
          )
        )
    )
  );

alter table public.direct_messages
  drop constraint if exists direct_messages_crypto_shape_check,
  drop constraint if exists direct_messages_content_check,
  add column if not exists payload jsonb not null default '{}'::jsonb,
  alter column legacy_plaintext set default true;

alter table public.direct_messages
  add constraint direct_messages_content_check check (
    char_length(content) <= 4000
    and (
      char_length(content) >= 1
      or (message_kind <> 'text' and payload <> '{}'::jsonb)
    )
  ),
  add constraint direct_messages_message_kind_check check (
    message_kind in (
      'text', 'announcement', 'poll', 'event', 'post_share', 'photo',
      'file', 'system'
    )
  ),
  add constraint direct_messages_payload_size_check check (
    pg_column_size(payload) <= 65536
  );

alter table public.group_messages
  drop constraint if exists group_messages_crypto_shape_check,
  drop constraint if exists group_messages_content_check,
  add column if not exists payload jsonb not null default '{}'::jsonb,
  alter column legacy_plaintext set default true;

alter table public.group_messages
  add constraint group_messages_content_check check (
    char_length(content) <= 4000
    and (
      char_length(content) >= 1
      or (message_kind <> 'text' and payload <> '{}'::jsonb)
    )
  ),
  add constraint group_messages_message_kind_check check (
    message_kind in (
      'text', 'announcement', 'poll', 'event', 'post_share', 'photo',
      'file', 'system'
    )
  ),
  add constraint group_messages_payload_size_check check (
    pg_column_size(payload) <= 65536
  );

alter table public.club_channel_messages
  drop constraint if exists club_channel_messages_content_check,
  drop constraint if exists club_channel_messages_crypto_version_check,
  drop constraint if exists club_channel_messages_key_version_check,
  add column if not exists payload jsonb not null default '{}'::jsonb,
  alter column content set default '',
  alter column crypto_version drop default,
  alter column crypto_version drop not null,
  alter column key_version drop not null,
  alter column sender_device_id drop not null,
  alter column ciphertext drop not null,
  alter column nonce drop not null,
  alter column mac drop not null,
  alter column signature drop not null;

alter table public.club_channel_messages
  add constraint club_channel_messages_content_check check (
    char_length(content) <= 4000
    and (
      char_length(content) >= 1
      or (message_kind <> 'text' and payload <> '{}'::jsonb)
    )
  ),
  add constraint club_channel_messages_payload_size_check check (
    pg_column_size(payload) <= 65536
  );

alter table public.club_inbox_messages
  drop constraint if exists club_inbox_messages_content_check,
  drop constraint if exists club_inbox_messages_crypto_version_check,
  drop constraint if exists club_inbox_messages_key_version_check,
  add column if not exists payload jsonb not null default '{}'::jsonb,
  alter column content set default '',
  alter column crypto_version drop default,
  alter column crypto_version drop not null,
  alter column key_version drop not null,
  alter column sender_device_id drop not null,
  alter column ciphertext drop not null,
  alter column nonce drop not null,
  alter column mac drop not null,
  alter column signature drop not null;

alter table public.club_inbox_messages
  add constraint club_inbox_messages_content_check check (
    char_length(content) <= 4000
    and (
      char_length(content) >= 1
      or (message_kind <> 'text' and payload <> '{}'::jsonb)
    )
  ),
  add constraint club_inbox_messages_payload_size_check check (
    pg_column_size(payload) <= 65536
  );

create index if not exists club_channel_messages_sender_profile_idx
  on public.club_channel_messages (sender_profile_id)
  where sender_profile_id is not null;
create index if not exists club_channel_messages_sender_club_idx
  on public.club_channel_messages (sender_club_id)
  where sender_club_id is not null;
create index if not exists club_inbox_messages_sender_profile_idx
  on public.club_inbox_messages (sender_profile_id)
  where sender_profile_id is not null;
create index if not exists club_inbox_messages_sender_club_idx
  on public.club_inbox_messages (sender_club_id)
  where sender_club_id is not null;

-- Recipients may update receipts, but signed-message immutability is no
-- longer available to protect the body. Keep equivalent plaintext guards.
create or replace function private.protect_direct_message_body()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.sender_id is distinct from old.sender_id
    or new.receiver_id is distinct from old.receiver_id
    or new.content is distinct from old.content
    or new.message_kind is distinct from old.message_kind
    or new.payload is distinct from old.payload
    or new.crypto_version is distinct from old.crypto_version
    or new.key_version is distinct from old.key_version
    or new.sender_device_id is distinct from old.sender_device_id
    or new.ciphertext is distinct from old.ciphertext
    or new.nonce is distinct from old.nonce
    or new.mac is distinct from old.mac
    or new.signature is distinct from old.signature
    or new.legacy_plaintext is distinct from old.legacy_plaintext
    or new.created_at is distinct from old.created_at
    or new.delivered_at is distinct from old.delivered_at
  then
    raise exception 'direct message body is immutable';
  end if;
  return new;
end;
$$;

revoke all on function private.protect_direct_message_body()
  from public, anon, authenticated;

create or replace function private.protect_club_inbox_message_body()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.thread_id is distinct from old.thread_id
    or new.sender_auth_id is distinct from old.sender_auth_id
    or new.sender_profile_id is distinct from old.sender_profile_id
    or new.sender_club_id is distinct from old.sender_club_id
    or new.message_kind is distinct from old.message_kind
    or new.content is distinct from old.content
    or new.payload is distinct from old.payload
    or new.crypto_version is distinct from old.crypto_version
    or new.key_version is distinct from old.key_version
    or new.sender_device_id is distinct from old.sender_device_id
    or new.ciphertext is distinct from old.ciphertext
    or new.nonce is distinct from old.nonce
    or new.mac is distinct from old.mac
    or new.signature is distinct from old.signature
    or new.created_at is distinct from old.created_at
    or new.delivered_at is distinct from old.delivered_at
  then
    raise exception 'club inbox message body is immutable';
  end if;
  return new;
end;
$$;

revoke all on function private.protect_club_inbox_message_body()
  from public, anon, authenticated;

create or replace function private.notify_direct_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare sender_name text; preview text;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone') into sender_name
  from public.profiles p where p.id = new.sender_id;
  preview := case when new.message_kind = 'post_share' then 'Shared a post'
    else left(new.content, 440) end;
  perform private.enqueue_localized_notification(
    new.receiver_id, new.sender_id, 'direct_message',
    coalesce(sender_name, 'New message'),
    coalesce(sender_name, 'Someone') || ': ' || preview,
    'message', new.sender_id, 'direct_message:' || new.id::text,
    jsonb_build_object(
      'actorName', coalesce(sender_name, 'Someone'), 'content', preview
    )
  );
  return new;
end;
$$;

create or replace function private.notify_group_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare sender_name text; group_name text; preview text; member record;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone') into sender_name
  from public.profiles p where p.id = new.sender_id;
  select coalesce(nullif(g.custom_name, ''), 'Group chat') into group_name
  from public.group_chats g where g.id = new.group_id;
  preview := case when new.message_kind = 'post_share' then 'Shared a post'
    else left(new.content, 440) end;
  for member in
    select m.user_id from public.group_chat_members m
    where m.group_id = new.group_id and m.user_id <> new.sender_id
  loop
    perform private.enqueue_localized_notification(
      member.user_id, new.sender_id, 'group_message',
      coalesce(group_name, 'Group chat'),
      coalesce(sender_name, 'Someone') || ': ' || preview,
      'message', new.group_id,
      'group_message:' || new.id::text || ':' || member.user_id::text,
      jsonb_build_object(
        'actorName', coalesce(sender_name, 'Someone'),
        'groupName', coalesce(group_name, 'Group chat'), 'content', preview
      )
    );
  end loop;
  return new;
end;
$$;

create or replace function private.notify_club_channel_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare club_name text; preview text; follower record;
begin
  select coalesce(nullif(c.name, ''), 'A club') into club_name
  from public.clubs c where c.id = new.club_id;
  preview := case when new.message_kind = 'post_share' then 'Shared a post'
    else left(new.content, 440) end;
  for follower in
    select cf.profile_id from public.club_followers cf
    where cf.club_id = new.club_id and cf.profile_id <> new.sender_auth_id
  loop
    perform private.enqueue_localized_notification(
      follower.profile_id, new.sender_auth_id, 'club_channel_message',
      club_name, club_name || ': ' || preview,
      'message', new.club_id,
      'club_channel_message:' || new.id::text || ':' || follower.profile_id::text,
      jsonb_build_object(
        'actorName', club_name, 'clubName', club_name, 'content', preview
      )
    );
  end loop;
  return new;
end;
$$;

create or replace function private.notify_club_inbox_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  conversation record; club_name text; actor_name text; preview text;
  recipient record;
begin
  select cit.id, cit.club_id, cit.profile_id into conversation
  from public.club_inbox_threads cit where cit.id = new.thread_id;
  select coalesce(nullif(c.name, ''), 'A club') into club_name
  from public.clubs c where c.id = conversation.club_id;
  preview := case when new.message_kind = 'post_share' then 'Shared a post'
    else left(new.content, 440) end;

  if new.sender_profile_id = conversation.profile_id then
    select coalesce(nullif(p.full_name, ''), 'Someone') into actor_name
    from public.profiles p where p.id = conversation.profile_id;
    for recipient in
      select ca.auth_user_id as user_id from public.club_auth_accounts ca
      where ca.club_id = conversation.club_id
      union
      select cf.profile_id as user_id from public.club_followers cf
      where cf.club_id = conversation.club_id and cf.role = 'board_member'
    loop
      if recipient.user_id <> new.sender_auth_id then
        perform private.enqueue_localized_notification(
          recipient.user_id, new.sender_auth_id, 'club_inbox_message',
          coalesce(actor_name, 'Someone'),
          coalesce(actor_name, 'Someone') || ': ' || preview,
          'message', conversation.id,
          'club_inbox_message:' || new.id::text || ':' || recipient.user_id::text,
          jsonb_build_object(
            'actorName', coalesce(actor_name, 'Someone'),
            'clubName', club_name, 'content', preview
          )
        );
      end if;
    end loop;
  else
    perform private.enqueue_localized_notification(
      conversation.profile_id, new.sender_auth_id, 'club_inbox_message',
      club_name, club_name || ': ' || preview,
      'message', conversation.id,
      'club_inbox_message:' || new.id::text || ':' || conversation.profile_id::text,
      jsonb_build_object(
        'actorName', club_name, 'clubName', club_name, 'content', preview
      )
    );
  end if;
  return new;
end;
$$;

revoke all on function private.notify_direct_message()
  from public, anon, authenticated;
revoke all on function private.notify_group_message()
  from public, anon, authenticated;
revoke all on function private.notify_club_channel_message()
  from public, anon, authenticated;
revoke all on function private.notify_club_inbox_message()
  from public, anon, authenticated;

-- Preserve the old public keys and wrapped thread keys for audit/recovery, but
-- lock the client roles out and stop broadcasting key envelopes.
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'e2ee_thread_key_envelopes'
  ) then
    alter publication supabase_realtime
      drop table public.e2ee_thread_key_envelopes;
  end if;
end $$;

revoke all on public.e2ee_thread_key_envelopes
  from public, anon, authenticated;
revoke all on public.e2ee_threads
  from public, anon, authenticated;
revoke all on public.e2ee_devices
  from public, anon, authenticated;

-- Old app versions must not create more ciphertext. This trigger leaves all
-- existing encrypted rows untouched and still permits receipt updates.
create or replace function private.reject_e2ee_message_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.crypto_version is not null
    or new.key_version is not null
    or new.sender_device_id is not null
    or new.ciphertext is not null
    or new.nonce is not null
    or new.mac is not null
    or new.signature is not null
  then
    raise exception 'encrypted messaging has been retired';
  end if;
  return new;
end;
$$;

revoke all on function private.reject_e2ee_message_insert()
  from public, anon, authenticated;

drop trigger if exists direct_messages_reject_e2ee_insert
  on public.direct_messages;
create trigger direct_messages_reject_e2ee_insert
  before insert on public.direct_messages
  for each row execute function private.reject_e2ee_message_insert();

drop trigger if exists group_messages_reject_e2ee_insert
  on public.group_messages;
create trigger group_messages_reject_e2ee_insert
  before insert on public.group_messages
  for each row execute function private.reject_e2ee_message_insert();

drop trigger if exists club_channel_messages_reject_e2ee_insert
  on public.club_channel_messages;
create trigger club_channel_messages_reject_e2ee_insert
  before insert on public.club_channel_messages
  for each row execute function private.reject_e2ee_message_insert();

drop trigger if exists club_inbox_messages_reject_e2ee_insert
  on public.club_inbox_messages;
create trigger club_inbox_messages_reject_e2ee_insert
  before insert on public.club_inbox_messages
  for each row execute function private.reject_e2ee_message_insert();

-- Keep Data API exposure explicit and RLS-enforced.
grant select, insert, update on public.direct_messages to authenticated;
grant select, insert on public.group_messages to authenticated;
grant select, insert on public.club_channel_messages to authenticated;
grant select, insert, update on public.club_inbox_messages to authenticated;
