-- End-to-end encrypted messaging foundation.
--
-- Private device keys and cleartext never leave a client. Postgres stores
-- public device keys, per-device encrypted thread keys, signed ciphertext,
-- delivery metadata, and authorization data only.

create table public.e2ee_devices (
  id uuid primary key,
  owner_auth_id uuid not null references auth.users(id) on delete cascade,
  encryption_public_key text not null check (char_length(encryption_public_key) between 40 and 64),
  signing_public_key text not null check (char_length(signing_public_key) between 40 and 64),
  algorithm text not null default 'x25519+ed25519+aes256gcm'
    check (algorithm = 'x25519+ed25519+aes256gcm'),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (id, owner_auth_id)
);

create index e2ee_devices_owner_active_idx
  on public.e2ee_devices (owner_auth_id, created_at)
  where revoked_at is null;

create table public.e2ee_threads (
  thread_id text primary key check (
    thread_id ~ '^(dm|group|club|clubdm):[0-9a-f-]+([|][0-9a-f-]+)?$'
  ),
  current_key_version integer not null default 1
    check (current_key_version > 0),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  rotated_at timestamptz not null default now()
);

create index e2ee_threads_created_by_idx
  on public.e2ee_threads (created_by);

create table public.e2ee_thread_key_envelopes (
  thread_id text not null references public.e2ee_threads(thread_id) on delete cascade,
  key_version integer not null check (key_version > 0),
  recipient_auth_id uuid not null references auth.users(id) on delete cascade,
  recipient_device_id uuid not null references public.e2ee_devices(id) on delete cascade,
  sender_device_id uuid not null references public.e2ee_devices(id) on delete restrict,
  ephemeral_public_key text not null check (char_length(ephemeral_public_key) between 40 and 64),
  wrapped_key text not null check (char_length(wrapped_key) between 40 and 64),
  nonce text not null check (char_length(nonce) between 12 and 32),
  mac text not null check (char_length(mac) between 20 and 32),
  signature text not null check (char_length(signature) between 80 and 100),
  created_at timestamptz not null default now(),
  primary key (thread_id, key_version, recipient_device_id)
);

create index e2ee_thread_key_recipient_idx
  on public.e2ee_thread_key_envelopes
  (recipient_auth_id, recipient_device_id, thread_id, key_version);
create index e2ee_thread_key_sender_device_idx
  on public.e2ee_thread_key_envelopes (sender_device_id);

-- A follower-visible club channel. Normal followers read; the club account or
-- a student whose club_followers.role is board_member may publish.
create table public.club_channel_messages (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  sender_auth_id uuid not null references auth.users(id) on delete restrict,
  sender_profile_id uuid references public.profiles(id) on delete set null,
  sender_club_id uuid references public.clubs(id) on delete set null,
  message_kind text not null default 'text' check (
    message_kind in ('text', 'announcement', 'poll', 'event', 'post_share', 'photo', 'file', 'system')
  ),
  content text not null default 'e2ee:v1' check (content = 'e2ee:v1'),
  crypto_version smallint not null default 1 check (crypto_version = 1),
  key_version integer not null check (key_version > 0),
  sender_device_id uuid not null references public.e2ee_devices(id) on delete restrict,
  ciphertext text not null,
  nonce text not null,
  mac text not null,
  signature text not null,
  created_at timestamptz not null default now(),
  check ((sender_profile_id is null) <> (sender_club_id is null)),
  check (sender_club_id is null or sender_club_id = club_id)
);

create index club_channel_messages_club_created_idx
  on public.club_channel_messages (club_id, created_at);
create index club_channel_messages_sender_auth_idx
  on public.club_channel_messages (sender_auth_id);
create index club_channel_messages_sender_device_idx
  on public.club_channel_messages (sender_device_id);

-- A private user-to-club inbox is separate from the board-only public channel.
create table public.club_inbox_threads (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (club_id, profile_id)
);

create index club_inbox_threads_profile_updated_idx
  on public.club_inbox_threads (profile_id, updated_at desc);
create index club_inbox_threads_club_updated_idx
  on public.club_inbox_threads (club_id, updated_at desc);

create table public.club_inbox_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.club_inbox_threads(id) on delete cascade,
  sender_auth_id uuid not null references auth.users(id) on delete restrict,
  sender_profile_id uuid references public.profiles(id) on delete set null,
  sender_club_id uuid references public.clubs(id) on delete set null,
  message_kind text not null default 'text' check (
    message_kind in ('text', 'post_share', 'photo', 'file', 'system')
  ),
  content text not null default 'e2ee:v1' check (content = 'e2ee:v1'),
  crypto_version smallint not null default 1 check (crypto_version = 1),
  key_version integer not null check (key_version > 0),
  sender_device_id uuid not null references public.e2ee_devices(id) on delete restrict,
  ciphertext text not null,
  nonce text not null,
  mac text not null,
  signature text not null,
  created_at timestamptz not null default now(),
  delivered_at timestamptz not null default now(),
  seen_at timestamptz,
  check ((sender_profile_id is null) <> (sender_club_id is null))
);

create index club_inbox_messages_thread_created_idx
  on public.club_inbox_messages (thread_id, created_at);
create index club_inbox_messages_sender_auth_idx
  on public.club_inbox_messages (sender_auth_id);
create index club_inbox_messages_sender_device_idx
  on public.club_inbox_messages (sender_device_id);
create index club_inbox_messages_unseen_idx
  on public.club_inbox_messages (thread_id, created_at)
  where seen_at is null;

-- Existing DM and student-group tables keep their IDs, receipts, and Realtime
-- wiring. New rows carry ciphertext columns; old plaintext rows remain readable
-- during the client migration and can be removed after the rollout window.
alter table public.direct_messages
  add column if not exists crypto_version smallint,
  add column if not exists key_version integer,
  add column if not exists sender_device_id uuid references public.e2ee_devices(id) on delete restrict,
  add column if not exists ciphertext text,
  add column if not exists nonce text,
  add column if not exists mac text,
  add column if not exists signature text,
  add column if not exists message_kind text not null default 'text',
  add column if not exists legacy_plaintext boolean not null default false;

alter table public.group_messages
  add column if not exists crypto_version smallint,
  add column if not exists key_version integer,
  add column if not exists sender_device_id uuid references public.e2ee_devices(id) on delete restrict,
  add column if not exists ciphertext text,
  add column if not exists nonce text,
  add column if not exists mac text,
  add column if not exists signature text,
  add column if not exists message_kind text not null default 'text',
  add column if not exists legacy_plaintext boolean not null default false;

-- Mark only rows that predate this migration as legacy. The constraints below
-- reject every new plaintext insert while keeping existing chat history.
update public.direct_messages
set legacy_plaintext = true
where crypto_version is null;
update public.group_messages
set legacy_plaintext = true
where crypto_version is null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.direct_messages'::regclass
      and conname = 'direct_messages_crypto_shape_check'
  ) then
    alter table public.direct_messages
      add constraint direct_messages_crypto_shape_check check (
        (legacy_plaintext and crypto_version is null and key_version is null and sender_device_id is null
          and ciphertext is null and nonce is null and mac is null and signature is null)
        or
        (not legacy_plaintext and crypto_version = 1 and key_version > 0 and sender_device_id is not null
          and ciphertext is not null and nonce is not null and mac is not null
          and signature is not null and content = 'e2ee:v1')
      ) not valid;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.group_messages'::regclass
      and conname = 'group_messages_crypto_shape_check'
  ) then
    alter table public.group_messages
      add constraint group_messages_crypto_shape_check check (
        (legacy_plaintext and crypto_version is null and key_version is null and sender_device_id is null
          and ciphertext is null and nonce is null and mac is null and signature is null)
        or
        (not legacy_plaintext and crypto_version = 1 and key_version > 0 and sender_device_id is not null
          and ciphertext is not null and nonce is not null and mac is not null
          and signature is not null and content = 'e2ee:v1')
      ) not valid;
  end if;
end $$;

create index if not exists direct_messages_sender_device_idx
  on public.direct_messages (sender_device_id)
  where sender_device_id is not null;
create index if not exists group_messages_sender_device_idx
  on public.group_messages (sender_device_id)
  where sender_device_id is not null;

-- Receipt updates must never be able to rewrite a signed message. Signature
-- verification would detect such a rewrite, but rejecting it in Postgres also
-- prevents a malicious recipient from causing a persistent denial of service.
create schema if not exists private;

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
    or new.created_at is distinct from old.created_at
    or new.delivered_at is distinct from old.delivered_at
    or new.crypto_version is distinct from old.crypto_version
    or new.key_version is distinct from old.key_version
    or new.sender_device_id is distinct from old.sender_device_id
    or new.ciphertext is distinct from old.ciphertext
    or new.nonce is distinct from old.nonce
    or new.mac is distinct from old.mac
    or new.signature is distinct from old.signature
    or new.message_kind is distinct from old.message_kind
    or new.legacy_plaintext is distinct from old.legacy_plaintext
  then
    raise exception 'signed direct message fields are immutable';
  end if;
  return new;
end;
$$;

create trigger protect_direct_message_body_before_update
before update on public.direct_messages
for each row execute function private.protect_direct_message_body();
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
    raise exception 'signed club inbox message fields are immutable';
  end if;
  return new;
end;
$$;

create trigger protect_club_inbox_message_body_before_update
before update on public.club_inbox_messages
for each row execute function private.protect_club_inbox_message_body();
revoke all on function private.protect_club_inbox_message_body()
  from public, anon, authenticated;

-- Centralized authorization is used by both thread-key tables. The function
-- lives outside exposed schemas, binds every decision to auth.uid(), and is not
-- callable through the Data API.
create or replace function private.can_access_e2ee_thread(
  target_thread_id text,
  require_write boolean default false
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  payload text;
  first_id uuid;
  second_id uuid;
begin
  if actor is null or target_thread_id is null then
    return false;
  end if;

  if target_thread_id like 'dm:%' then
    payload := substring(target_thread_id from 4);
    begin
      first_id := split_part(payload, '|', 1)::uuid;
      second_id := split_part(payload, '|', 2)::uuid;
    exception when invalid_text_representation then
      return false;
    end;
    return actor in (first_id, second_id)
      and exists (select 1 from public.profiles p where p.id = first_id)
      and exists (select 1 from public.profiles p where p.id = second_id);
  end if;

  if target_thread_id like 'group:%' then
    begin
      first_id := substring(target_thread_id from 7)::uuid;
    exception when invalid_text_representation then
      return false;
    end;
    return exists (
      select 1 from public.group_chat_members gm
      where gm.group_id = first_id and gm.user_id = actor
    );
  end if;

  if target_thread_id like 'club:%' then
    begin
      first_id := substring(target_thread_id from 6)::uuid;
    exception when invalid_text_representation then
      return false;
    end;
    if exists (
      select 1 from public.club_auth_accounts ca
      where ca.club_id = first_id and ca.auth_user_id = actor
    ) or exists (
      select 1 from public.club_followers cf
      where cf.club_id = first_id and cf.profile_id = actor
        and cf.role = 'board_member'
    ) then
      return true;
    end if;
    return not require_write and exists (
      select 1 from public.club_followers cf
      where cf.club_id = first_id and cf.profile_id = actor
    );
  end if;

  if target_thread_id like 'clubdm:%' then
    begin
      first_id := substring(target_thread_id from 8)::uuid;
    exception when invalid_text_representation then
      return false;
    end;
    return exists (
      select 1
      from public.club_inbox_threads cit
      where cit.id = first_id
        and (
          cit.profile_id = actor
          or exists (
            select 1 from public.club_auth_accounts ca
            where ca.club_id = cit.club_id and ca.auth_user_id = actor
          )
          or exists (
            select 1 from public.club_followers cf
            where cf.club_id = cit.club_id and cf.profile_id = actor
              and cf.role = 'board_member'
          )
        )
    );
  end if;

  return false;
end;
$$;

revoke all on function private.can_access_e2ee_thread(text, boolean)
  from public, anon;
grant execute on function private.can_access_e2ee_thread(text, boolean)
  to authenticated;

alter table public.e2ee_devices enable row level security;
alter table public.e2ee_threads enable row level security;
alter table public.e2ee_thread_key_envelopes enable row level security;
alter table public.club_channel_messages enable row level security;
alter table public.club_inbox_threads enable row level security;
alter table public.club_inbox_messages enable row level security;

-- Revocation blocks future envelopes and sends, but public verification keys
-- remain readable so historical signatures can still be authenticated.
create policy e2ee_devices_read_public_keys
  on public.e2ee_devices for select to authenticated
  using (true);
create policy e2ee_devices_insert_own
  on public.e2ee_devices for insert to authenticated
  with check (owner_auth_id = (select auth.uid()));
create policy e2ee_devices_update_own
  on public.e2ee_devices for update to authenticated
  using (owner_auth_id = (select auth.uid()))
  with check (owner_auth_id = (select auth.uid()));

create policy e2ee_threads_read_participants
  on public.e2ee_threads for select to authenticated
  using ((select private.can_access_e2ee_thread(thread_id, false)));
create policy e2ee_threads_insert_participants
  on public.e2ee_threads for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and (select private.can_access_e2ee_thread(thread_id, true))
  );
create policy e2ee_threads_update_writers
  on public.e2ee_threads for update to authenticated
  using ((select private.can_access_e2ee_thread(thread_id, true)))
  with check ((select private.can_access_e2ee_thread(thread_id, true)));

create policy e2ee_key_envelopes_read_participants
  on public.e2ee_thread_key_envelopes for select to authenticated
  using ((select private.can_access_e2ee_thread(thread_id, false)));
create policy e2ee_key_envelopes_insert_writers
  on public.e2ee_thread_key_envelopes for insert to authenticated
  with check (
    (select private.can_access_e2ee_thread(thread_id, true))
    and exists (
      select 1 from public.e2ee_devices own_device
      where own_device.id = sender_device_id
        and own_device.owner_auth_id = (select auth.uid())
        and own_device.revoked_at is null
    )
    and exists (
      select 1 from public.e2ee_devices recipient_device
      where recipient_device.id = recipient_device_id
        and recipient_device.owner_auth_id = recipient_auth_id
        and recipient_device.revoked_at is null
    )
  );

create policy club_channel_read_followers_and_staff
  on public.club_channel_messages for select to authenticated
  using (
    exists (
      select 1 from public.club_followers cf
      where cf.club_id = club_channel_messages.club_id
        and cf.profile_id = (select auth.uid())
    )
    or exists (
      select 1 from public.club_auth_accounts ca
      where ca.club_id = club_channel_messages.club_id
        and ca.auth_user_id = (select auth.uid())
    )
  );
create policy club_channel_insert_board
  on public.club_channel_messages for insert to authenticated
  with check (
    sender_auth_id = (select auth.uid())
    and exists (
      select 1 from public.e2ee_devices own_device
      where own_device.id = sender_device_id
        and own_device.owner_auth_id = (select auth.uid())
        and own_device.revoked_at is null
    )
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

create policy club_inbox_threads_read_participants
  on public.club_inbox_threads for select to authenticated
  using (
    profile_id = (select auth.uid())
    or exists (
      select 1 from public.club_auth_accounts ca
      where ca.club_id = club_inbox_threads.club_id
        and ca.auth_user_id = (select auth.uid())
    )
    or exists (
      select 1 from public.club_followers cf
      where cf.club_id = club_inbox_threads.club_id
        and cf.profile_id = (select auth.uid())
        and cf.role = 'board_member'
    )
  );
create policy club_inbox_threads_create_student
  on public.club_inbox_threads for insert to authenticated
  with check (
    profile_id = (select auth.uid())
    and exists (
      select 1 from public.club_followers cf
      where cf.club_id = club_inbox_threads.club_id
        and cf.profile_id = (select auth.uid())
    )
  );
create policy club_inbox_threads_update_participants
  on public.club_inbox_threads for update to authenticated
  using (
    profile_id = (select auth.uid())
    or exists (
      select 1 from public.club_auth_accounts ca
      where ca.club_id = club_inbox_threads.club_id
        and ca.auth_user_id = (select auth.uid())
    )
    or exists (
      select 1 from public.club_followers cf
      where cf.club_id = club_inbox_threads.club_id
        and cf.profile_id = (select auth.uid())
        and cf.role = 'board_member'
    )
  )
  with check (
    profile_id = (select auth.uid())
    or exists (
      select 1 from public.club_auth_accounts ca
      where ca.club_id = club_inbox_threads.club_id
        and ca.auth_user_id = (select auth.uid())
    )
    or exists (
      select 1 from public.club_followers cf
      where cf.club_id = club_inbox_threads.club_id
        and cf.profile_id = (select auth.uid())
        and cf.role = 'board_member'
    )
  );

create policy club_inbox_messages_read_participants
  on public.club_inbox_messages for select to authenticated
  using (
    exists (
      select 1 from public.club_inbox_threads cit
      where cit.id = club_inbox_messages.thread_id
        and (
          cit.profile_id = (select auth.uid())
          or exists (
            select 1 from public.club_auth_accounts ca
            where ca.club_id = cit.club_id
              and ca.auth_user_id = (select auth.uid())
          )
          or exists (
            select 1 from public.club_followers cf
            where cf.club_id = cit.club_id
              and cf.profile_id = (select auth.uid())
              and cf.role = 'board_member'
          )
        )
    )
  );
create policy club_inbox_messages_insert_participants
  on public.club_inbox_messages for insert to authenticated
  with check (
    sender_auth_id = (select auth.uid())
    and exists (
      select 1 from public.e2ee_devices own_device
      where own_device.id = sender_device_id
        and own_device.owner_auth_id = (select auth.uid())
        and own_device.revoked_at is null
    )
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
create policy club_inbox_messages_update_recipient
  on public.club_inbox_messages for update to authenticated
  using (
    sender_auth_id <> (select auth.uid())
    and exists (
      select 1 from public.club_inbox_threads cit
      where cit.id = club_inbox_messages.thread_id
        and (
          cit.profile_id = (select auth.uid())
          or exists (
            select 1 from public.club_auth_accounts ca
            where ca.club_id = cit.club_id
              and ca.auth_user_id = (select auth.uid())
          )
          or exists (
            select 1 from public.club_followers cf
            where cf.club_id = cit.club_id
              and cf.profile_id = (select auth.uid())
              and cf.role = 'board_member'
          )
        )
    )
  )
  with check (sender_auth_id <> (select auth.uid()));

-- New public tables are opt-in to Data API exposure as of Supabase's 2026
-- change. These grants are intentionally narrower than ALL.
grant select, insert, update on public.e2ee_devices to authenticated;
grant select, insert, update on public.e2ee_threads to authenticated;
grant select, insert on public.e2ee_thread_key_envelopes to authenticated;
grant select, insert on public.club_channel_messages to authenticated;
grant select, insert, update on public.club_inbox_threads to authenticated;
grant select, insert, update on public.club_inbox_messages to authenticated;

-- Push notifications deliberately contain no decrypted preview. The target
-- IDs are enough for the client to open and decrypt the right conversation.
alter table public.notifications
  drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check check (type in (
    'direct_message', 'group_message', 'club_channel_message',
    'club_inbox_message', 'club_post', 'club_event', 'post_like',
    'post_comment', 'event_rsvp', 'profile_follow'
  ));

create or replace function private.notify_direct_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare sender_name text; preview text; encrypted boolean;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone') into sender_name
  from public.profiles p where p.id = new.sender_id;
  encrypted := new.crypto_version = 1;
  preview := case when encrypted then 'New encrypted message'
    else left(new.content, 440) end;
  perform private.enqueue_localized_notification(
    new.receiver_id, new.sender_id, 'direct_message',
    coalesce(sender_name, 'New message'),
    coalesce(sender_name, 'Someone') || ': ' || preview,
    'message', new.sender_id, 'direct_message:' || new.id::text,
    jsonb_build_object(
      'actorName', coalesce(sender_name, 'Someone'),
      'content', case when encrypted then '' else preview end,
      'encrypted', encrypted
    )
  );
  return new;
end;
$$;

create or replace function private.notify_group_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare sender_name text; group_name text; preview text; encrypted boolean; member record;
begin
  select coalesce(nullif(p.full_name, ''), 'Someone') into sender_name
  from public.profiles p where p.id = new.sender_id;
  select coalesce(nullif(g.custom_name, ''), 'Group chat') into group_name
  from public.group_chats g where g.id = new.group_id;
  encrypted := new.crypto_version = 1;
  preview := case when encrypted then 'New encrypted message'
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
        'groupName', coalesce(group_name, 'Group chat'),
        'content', case when encrypted then '' else preview end,
        'encrypted', encrypted
      )
    );
  end loop;
  return new;
end;
$$;

create or replace function private.notify_club_channel_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare club_name text; follower record;
begin
  select coalesce(nullif(c.name, ''), 'A club') into club_name
  from public.clubs c where c.id = new.club_id;
  for follower in
    select cf.profile_id from public.club_followers cf
    where cf.club_id = new.club_id
      and cf.profile_id <> new.sender_auth_id
  loop
    perform private.enqueue_localized_notification(
      follower.profile_id, new.sender_auth_id, 'club_channel_message',
      club_name, club_name || ': New encrypted message',
      'message', new.club_id,
      'club_channel_message:' || new.id::text || ':' || follower.profile_id::text,
      jsonb_build_object(
        'actorName', club_name, 'clubName', club_name, 'encrypted', true
      )
    );
  end loop;
  return new;
end;
$$;

create or replace function private.notify_club_inbox_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare conversation record; club_name text; actor_name text; recipient record;
begin
  select cit.id, cit.club_id, cit.profile_id
    into conversation
  from public.club_inbox_threads cit where cit.id = new.thread_id;
  select coalesce(nullif(c.name, ''), 'A club') into club_name
  from public.clubs c where c.id = conversation.club_id;

  if new.sender_profile_id = conversation.profile_id then
    select coalesce(nullif(p.full_name, ''), 'Someone') into actor_name
    from public.profiles p where p.id = conversation.profile_id;
    for recipient in
      select ca.auth_user_id as user_id
      from public.club_auth_accounts ca
      where ca.club_id = conversation.club_id
      union
      select cf.profile_id as user_id
      from public.club_followers cf
      where cf.club_id = conversation.club_id and cf.role = 'board_member'
    loop
      if recipient.user_id <> new.sender_auth_id then
        perform private.enqueue_localized_notification(
          recipient.user_id, new.sender_auth_id, 'club_inbox_message',
          coalesce(actor_name, 'Someone'),
          coalesce(actor_name, 'Someone') || ': New encrypted message',
          'message', conversation.id,
          'club_inbox_message:' || new.id::text || ':' || recipient.user_id::text,
          jsonb_build_object(
            'actorName', coalesce(actor_name, 'Someone'),
            'clubName', club_name, 'encrypted', true
          )
        );
      end if;
    end loop;
  else
    perform private.enqueue_localized_notification(
      conversation.profile_id, new.sender_auth_id, 'club_inbox_message',
      club_name, club_name || ': New encrypted message',
      'message', conversation.id,
      'club_inbox_message:' || new.id::text || ':' || conversation.profile_id::text,
      jsonb_build_object(
        'actorName', club_name, 'clubName', club_name, 'encrypted', true
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

create trigger club_channel_message_notification
after insert on public.club_channel_messages
for each row execute function private.notify_club_channel_message();
create trigger club_inbox_message_notification
after insert on public.club_inbox_messages
for each row execute function private.notify_club_inbox_message();

alter table public.club_channel_messages replica identity full;
alter table public.club_inbox_threads replica identity full;
alter table public.club_inbox_messages replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'club_channel_messages'
  ) then
    alter publication supabase_realtime add table public.club_channel_messages;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'club_inbox_threads'
  ) then
    alter publication supabase_realtime add table public.club_inbox_threads;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'club_inbox_messages'
  ) then
    alter publication supabase_realtime add table public.club_inbox_messages;
  end if;
end $$;
