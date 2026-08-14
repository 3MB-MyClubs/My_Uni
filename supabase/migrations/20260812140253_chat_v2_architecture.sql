-- Additive Chat v2 protocol. Released clients keep using the canonical tables,
-- direct-write grants, RLS policies, and existing Realtime publication members
-- unchanged; v2 adds one participant-scoped journal member.

create schema if not exists private;

create table public.chat_v2_read_state (
  viewer_id uuid not null references auth.users(id) on delete cascade,
  thread_id text not null,
  read_scope text not null default 'all'
    check (read_scope in ('all', 'board', 'chat')),
  last_read_created_at timestamptz not null,
  last_read_message_id uuid not null,
  updated_at timestamptz not null default now(),
  primary key (viewer_id, thread_id, read_scope),
  constraint chat_v2_read_state_thread_format check (
    thread_id ~ '^(dm:[0-9a-f-]{36}\|[0-9a-f-]{36}|group:[0-9a-f-]{36}|club:[0-9a-f-]{36}|clubdm:[0-9a-f-]{36})$'
  )
);

create table public.chat_v2_change_log (
  change_id bigint generated always as identity primary key,
  thread_id text not null,
  message_id uuid not null,
  record_type text not null default 'message'
    check (record_type in ('message', 'receipt', 'poll_vote')),
  operation text not null check (operation in ('INSERT', 'UPDATE', 'DELETE')),
  record jsonb not null,
  direct_sender_id uuid,
  direct_receiver_id uuid,
  group_id uuid,
  club_id uuid,
  club_inbox_profile_id uuid,
  changed_at timestamptz not null default clock_timestamp(),
  constraint chat_v2_change_log_scope check (
    num_nonnulls(direct_sender_id, group_id, club_id) = 1
    and (direct_receiver_id is null) = (direct_sender_id is null)
  )
);

create index chat_v2_change_log_thread_change_idx
  on public.chat_v2_change_log (thread_id, change_id);
create index chat_v2_change_log_changed_at_idx
  on public.chat_v2_change_log (changed_at, change_id);

create sequence if not exists private.chat_v2_cleanup_clock;
create or replace function private.cleanup_chat_v2_change_log(
  p_retention interval default interval '30 days',
  p_batch_size integer default 10000
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_deleted bigint;
begin
  if p_retention < interval '7 days' then
    raise exception 'Chat journal retention must be at least seven days'
      using errcode = '22023';
  end if;
  delete from public.chat_v2_change_log
  where change_id in (
    select change_id
    from public.chat_v2_change_log
    where changed_at < clock_timestamp() - p_retention
    order by changed_at, change_id
    limit least(greatest(coalesce(p_batch_size, 10000), 1), 100000)
  );
  get diagnostics v_deleted = row_count;
  return v_deleted;
end
$function$;
revoke all on function private.cleanup_chat_v2_change_log(interval, integer)
  from public, anon, authenticated;
grant execute on function private.cleanup_chat_v2_change_log(interval, integer)
  to authenticated;
create index chat_v2_read_state_thread_idx
  on public.chat_v2_read_state (thread_id, viewer_id, read_scope);

-- The append-only participant journal replaces broad client subscriptions to
-- four message tables. Existing publication members are left untouched.
do $migration$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'chat_v2_change_log'
  ) then
    alter publication supabase_realtime add table public.chat_v2_change_log;
  end if;
end
$migration$;

-- Stable keyset access paths. Existing indexes and legacy query plans remain.
create index if not exists direct_messages_sender_receiver_v2_idx
  on public.direct_messages (sender_id, receiver_id, created_at desc, id desc);
create index if not exists direct_messages_receiver_sender_v2_idx
  on public.direct_messages (receiver_id, sender_id, created_at desc, id desc);
create index if not exists group_messages_group_order_v2_idx
  on public.group_messages (group_id, created_at desc, id desc);
create index if not exists club_channel_messages_club_order_v2_idx
  on public.club_channel_messages (club_id, created_at desc, id desc);
create index if not exists club_inbox_messages_thread_order_v2_idx
  on public.club_inbox_messages (thread_id, created_at desc, id desc);

alter table public.chat_v2_read_state enable row level security;
alter table public.chat_v2_change_log enable row level security;

revoke all on public.chat_v2_read_state from public, anon, authenticated;
revoke all on public.chat_v2_change_log from public, anon, authenticated;
grant select, insert, update on public.chat_v2_read_state to authenticated;
grant select on public.chat_v2_change_log to authenticated;

create policy chat_v2_read_state_own_select
  on public.chat_v2_read_state for select to authenticated
  using (viewer_id = (select auth.uid()));
create policy chat_v2_read_state_own_insert
  on public.chat_v2_read_state for insert to authenticated
  with check (viewer_id = (select auth.uid()));
create policy chat_v2_read_state_own_update
  on public.chat_v2_read_state for update to authenticated
  using (viewer_id = (select auth.uid()))
  with check (viewer_id = (select auth.uid()));

create policy chat_v2_change_log_visible_conversations
  on public.chat_v2_change_log for select to authenticated
  using (
    (
      direct_sender_id is not null
      and (select auth.uid()) in (direct_sender_id, direct_receiver_id)
    )
    or (
      group_id is not null
      and exists (
        select 1 from public.group_chat_members as member
        where member.group_id = chat_v2_change_log.group_id
          and member.user_id = (select auth.uid())
      )
    )
    or (
      club_id is not null
      and club_inbox_profile_id is null
      and (
        exists (
          select 1 from public.club_followers as follower
          where follower.club_id = chat_v2_change_log.club_id
            and follower.profile_id = (select auth.uid())
        )
        or exists (
          select 1 from public.club_auth_accounts as account
          where account.club_id = chat_v2_change_log.club_id
            and account.auth_user_id = (select auth.uid())
        )
      )
    )
    or (
      club_id is not null
      and club_inbox_profile_id is not null
      and (
        club_inbox_profile_id = (select auth.uid())
        or exists (
          select 1 from public.club_auth_accounts as account
          where account.club_id = chat_v2_change_log.club_id
            and account.auth_user_id = (select auth.uid())
        )
        or exists (
          select 1 from public.club_followers as follower
          where follower.club_id = chat_v2_change_log.club_id
            and follower.profile_id = (select auth.uid())
            and follower.role = 'board_member'
        )
      )
    )
  );

create or replace function private.chat_v2_direct_peer(
  p_thread_id text,
  p_viewer uuid
)
returns uuid
language plpgsql
immutable
set search_path = ''
as $function$
declare
  v_parts text[];
  v_first uuid;
  v_second uuid;
begin
  if p_thread_id is null or p_viewer is null or left(p_thread_id, 3) <> 'dm:' then
    return null;
  end if;
  v_parts := string_to_array(substr(p_thread_id, 4), '|');
  if cardinality(v_parts) <> 2 then return null; end if;
  begin
    v_first := v_parts[1]::uuid;
    v_second := v_parts[2]::uuid;
  exception when invalid_text_representation then
    return null;
  end;
  if v_first = p_viewer then return v_second; end if;
  if v_second = p_viewer then return v_first; end if;
  return null;
end
$function$;

-- This deliberately exposes only a boolean. SECURITY DEFINER is needed so a
-- recipient's block is enforced even though user_blocks RLS only exposes the
-- caller's own rows. The auth.uid() equality prevents it becoming a general
-- relationship oracle.
create or replace function private.chat_v2_dm_blocked(
  p_actor uuid,
  p_peer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select case
    when auth.uid() is null or auth.uid() <> p_actor then true
    else exists (
      select 1 from public.user_blocks as block
      where (block.blocker_id = p_actor and block.blocked_id = p_peer)
         or (block.blocker_id = p_peer and block.blocked_id = p_actor)
    )
  end
$function$;

create or replace function public.get_conversation_summaries_v2(
  p_limit integer default 40,
  p_cursor_activity_at timestamptz default null,
  p_cursor_thread_id text default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 50);
  v_items jsonb;
  v_has_more boolean;
  v_next_activity timestamptz;
  v_next_thread text;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if (p_cursor_activity_at is null) <> (p_cursor_thread_id is null) then
    raise exception 'Both cursor fields must be provided together' using errcode = '22023';
  end if;

  with direct_peers as materialized (
    select distinct case
      when message.sender_id = v_uid then message.receiver_id
      else message.sender_id
    end as peer_id
    from public.direct_messages as message
    where message.sender_id = v_uid or message.receiver_id = v_uid
  ), conversations as materialized (
    select
      'dm:' || least(v_uid, peer.id)::text || '|' || greatest(v_uid, peer.id)::text as thread_id,
      'direct'::text as thread_type,
      latest.created_at as activity_at,
      jsonb_build_object(
        'id', peer.id, 'name', peer.full_name, 'avatar_url', peer.avatar_url
      ) as peer,
      null::jsonb as group_info,
      null::jsonb as club,
      null::jsonb as inbox_profile,
      latest.message as latest_message,
      (
        select count(*)::integer from public.direct_messages as unread
        where unread.sender_id = peer.id and unread.receiver_id = v_uid
          and unread.seen_at is null
      ) as unread_count,
      null::integer as unread_board_count,
      null::integer as unread_chat_count,
      null::jsonb as read_boundaries
    from direct_peers
    join public.profiles as peer on peer.id = direct_peers.peer_id
    cross join lateral (
      select
        message.created_at,
        jsonb_build_object(
          'id', message.id,
          'thread_id', 'dm:' || least(v_uid, peer.id)::text || '|' || greatest(v_uid, peer.id)::text,
          'sender_id', message.sender_id, 'receiver_id', message.receiver_id,
          'content', message.content, 'message_kind', message.message_kind,
          'payload', message.payload, 'crypto_version', message.crypto_version,
          'created_at', message.created_at, 'delivered_at', message.delivered_at,
          'seen_at', message.seen_at, 'read_at', message.read_at
        ) as message
      from public.direct_messages as message
      where (message.sender_id = v_uid and message.receiver_id = peer.id)
         or (message.sender_id = peer.id and message.receiver_id = v_uid)
      order by message.created_at desc, message.id desc limit 1
    ) as latest
    where not private.chat_v2_dm_blocked(v_uid, peer.id)

    union all

    select
      'group:' || chat.id::text,
      'group',
      coalesce(latest.created_at, chat.created_at),
      null,
      jsonb_build_object(
        'id', chat.id, 'creator_id', chat.creator_id,
        'admin_ids', coalesce(to_jsonb(chat.admin_ids), '[]'::jsonb),
        'custom_name', chat.custom_name, 'photo_url', chat.photo_url,
        'created_at', chat.created_at,
        'members', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', member.user_id, 'name', profile.full_name,
            'avatar_url', profile.avatar_url, 'position', member.position
          ) order by member.position, member.joined_at, member.user_id)
          from public.group_chat_members as member
          join public.profiles as profile on profile.id = member.user_id
          where member.group_id = chat.id
        ), '[]'::jsonb)
      ),
      null,
      null,
      latest.message,
      (
        select count(*)::integer
        from public.group_messages as unread
        where unread.group_id = chat.id and unread.sender_id <> v_uid
          and not exists (
            select 1 from public.group_message_receipts as receipt
            where receipt.message_id = unread.id and receipt.user_id = v_uid
              and receipt.seen_at is not null
          )
      ),
      null::integer,
      null::integer,
      null::jsonb
    from public.group_chat_members as own_membership
    join public.group_chats as chat on chat.id = own_membership.group_id
    left join lateral (
      select
        message.created_at,
        jsonb_build_object(
          'id', message.id, 'thread_id', 'group:' || chat.id::text,
          'group_id', chat.id, 'sender_id', message.sender_id,
          'content', message.content, 'message_kind', message.message_kind,
          'payload', message.payload, 'crypto_version', message.crypto_version,
          'created_at', message.created_at
        ) as message
      from public.group_messages as message
      where message.group_id = chat.id
      order by message.created_at desc, message.id desc limit 1
    ) as latest on true
    where own_membership.user_id = v_uid

    union all

    select
      'club:' || visible_club.id::text,
      'club',
      coalesce(latest.created_at, visible_club.created_at),
      null,
      null,
      jsonb_build_object(
        'id', visible_club.id, 'name', visible_club.name,
        'short_name', visible_club.short_name,
        'logo_url', visible_club.logo_url
      ),
      null,
      latest.message,
      (
        select count(*)::integer
        from public.club_channel_messages as unread
        where unread.club_id = visible_club.id
          and unread.sender_auth_id <> v_uid
          and not exists (
            select 1 from public.chat_v2_read_state as read_state
            where read_state.viewer_id = v_uid
              and read_state.thread_id = 'club:' || visible_club.id::text
              and read_state.read_scope in (
                'all',
                case when unread.message_kind = 'announcement'
                  then 'board' else 'chat' end
              )
              and (read_state.last_read_created_at, read_state.last_read_message_id)
                >= (unread.created_at, unread.id)
          )
      ),
      (
        select count(*)::integer
        from public.club_channel_messages as unread
        where unread.club_id = visible_club.id
          and unread.sender_auth_id <> v_uid
          and unread.message_kind = 'announcement'
          and not exists (
            select 1 from public.chat_v2_read_state as read_state
            where read_state.viewer_id = v_uid
              and read_state.thread_id = 'club:' || visible_club.id::text
              and read_state.read_scope in ('all', 'board')
              and (read_state.last_read_created_at, read_state.last_read_message_id)
                >= (unread.created_at, unread.id)
          )
      ),
      (
        select count(*)::integer
        from public.club_channel_messages as unread
        where unread.club_id = visible_club.id
          and unread.sender_auth_id <> v_uid
          and unread.message_kind <> 'announcement'
          and not exists (
            select 1 from public.chat_v2_read_state as read_state
            where read_state.viewer_id = v_uid
              and read_state.thread_id = 'club:' || visible_club.id::text
              and read_state.read_scope in ('all', 'chat')
              and (read_state.last_read_created_at, read_state.last_read_message_id)
                >= (unread.created_at, unread.id)
          )
      ),
      jsonb_build_object(
        'board', (
          select jsonb_build_object('id', boundary.id, 'created_at', boundary.created_at)
          from public.club_channel_messages as boundary
          where boundary.club_id = visible_club.id
            and boundary.message_kind = 'announcement'
          order by boundary.created_at desc, boundary.id desc limit 1
        ),
        'chat', (
          select jsonb_build_object('id', boundary.id, 'created_at', boundary.created_at)
          from public.club_channel_messages as boundary
          where boundary.club_id = visible_club.id
            and boundary.message_kind <> 'announcement'
          order by boundary.created_at desc, boundary.id desc limit 1
        )
      )
    from (
      select club.* from public.clubs as club
      join public.club_followers as follower on follower.club_id = club.id
      where follower.profile_id = v_uid and club.is_active is true
      union
      select club.* from public.clubs as club
      join public.club_auth_accounts as account on account.club_id = club.id
      where account.auth_user_id = v_uid and club.is_active is true
    ) as visible_club
    left join lateral (
      select
        message.created_at,
        jsonb_build_object(
          'id', message.id, 'thread_id', 'club:' || visible_club.id::text,
          'club_id', visible_club.id, 'sender_auth_id', message.sender_auth_id,
          'sender_profile_id', message.sender_profile_id,
          'sender_club_id', message.sender_club_id,
          'content', message.content, 'message_kind', message.message_kind,
          'payload', message.payload, 'crypto_version', message.crypto_version,
          'created_at', message.created_at
        ) as message
      from public.club_channel_messages as message
      where message.club_id = visible_club.id
      order by message.created_at desc, message.id desc limit 1
    ) as latest on true

    union all

    select
      'clubdm:' || inbox.id::text,
      'club_inbox',
      coalesce(latest.created_at, inbox.updated_at),
      null,
      null,
      jsonb_build_object(
        'id', club.id, 'name', club.name, 'short_name', club.short_name,
        'logo_url', club.logo_url
      ),
      jsonb_build_object(
        'id', profile.id, 'name', profile.full_name,
        'avatar_url', profile.avatar_url
      ),
      latest.message,
      (
        select count(*)::integer from public.club_inbox_messages as unread
        where unread.thread_id = inbox.id
          and unread.sender_auth_id <> v_uid and unread.seen_at is null
      ),
      null::integer,
      null::integer,
      null::jsonb
    from public.club_inbox_threads as inbox
    join public.clubs as club on club.id = inbox.club_id
    join public.profiles as profile on profile.id = inbox.profile_id
    left join lateral (
      select
        message.created_at,
        jsonb_build_object(
          'id', message.id, 'thread_id', 'clubdm:' || inbox.id::text,
          'inbox_id', inbox.id, 'club_id', inbox.club_id,
          'sender_auth_id', message.sender_auth_id,
          'sender_profile_id', message.sender_profile_id,
          'sender_club_id', message.sender_club_id,
          'content', message.content, 'message_kind', message.message_kind,
          'payload', message.payload, 'crypto_version', message.crypto_version,
          'created_at', message.created_at, 'delivered_at', message.delivered_at,
          'seen_at', message.seen_at
        ) as message
      from public.club_inbox_messages as message
      where message.thread_id = inbox.id
      order by message.created_at desc, message.id desc limit 1
    ) as latest on true
    where club.is_active is true
      and (
        inbox.profile_id = v_uid
        or exists (
          select 1 from public.club_auth_accounts as account
          where account.club_id = inbox.club_id and account.auth_user_id = v_uid
        )
        or exists (
          select 1 from public.club_followers as follower
          where follower.club_id = inbox.club_id
            and follower.profile_id = v_uid and follower.role = 'board_member'
        )
      )
  ), page as materialized (
    select * from conversations
    where p_cursor_activity_at is null
      or (activity_at, thread_id) < (p_cursor_activity_at, p_cursor_thread_id)
    order by activity_at desc, thread_id desc limit v_limit + 1
  ), bounded as (
    select * from page order by activity_at desc, thread_id desc limit v_limit
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'thread_id', thread_id, 'thread_type', thread_type,
      'activity_at', activity_at, 'peer', peer, 'group', group_info,
      'club', club, 'inbox_profile', inbox_profile,
      'latest_message', latest_message, 'unread_count', unread_count,
      'unread_board_count', unread_board_count,
      'unread_chat_count', unread_chat_count,
      'read_boundaries', read_boundaries,
      'sync_cursor', coalesce((
        select max(change.change_id) from public.chat_v2_change_log as change
        where change.thread_id = bounded.thread_id
      ), 0)
    ) order by activity_at desc, thread_id desc), '[]'::jsonb),
    (select count(*) > v_limit from page),
    (array_agg(activity_at order by activity_at asc, thread_id asc))[1],
    (array_agg(thread_id order by activity_at asc, thread_id asc))[1]
  into v_items, v_has_more, v_next_activity, v_next_thread from bounded;

  return jsonb_build_object(
    'version', 2, 'page_size', v_limit, 'items', v_items,
    'has_more', v_has_more,
    'next_cursor', case when v_has_more then jsonb_build_object(
      'activity_at', v_next_activity, 'thread_id', v_next_thread
    ) else null end
  );
end
$function$;

create or replace function public.send_message_v2(
  p_thread_id text,
  p_message_id uuid,
  p_content text,
  p_message_kind text default 'text',
  p_payload jsonb default '{}'::jsonb,
  p_created_at timestamptz default null,
  p_send_as_club boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_peer uuid;
  v_created_at timestamptz := coalesce(p_created_at, now());
  v_inserted boolean := false;
  v_sender_profile uuid;
  v_sender_club uuid;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_message_id is null then raise exception 'Message id is required' using errcode = '22004'; end if;
  if p_message_kind not in ('text', 'announcement', 'poll', 'event', 'post_share', 'photo', 'file', 'system') then
    raise exception 'Unsupported message kind' using errcode = '22023';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or pg_column_size(p_payload) > 65536 then
    raise exception 'Invalid message payload' using errcode = '22023';
  end if;
  if char_length(coalesce(p_content, '')) > 4000
      or (char_length(coalesce(p_content, '')) = 0 and (p_message_kind = 'text' or p_payload = '{}'::jsonb)) then
    raise exception 'Invalid message content' using errcode = '22023';
  end if;
  if not private.chat_v2_can_access(p_thread_id, v_uid) then
    raise exception 'Conversation is not writable' using errcode = '42501';
  end if;

  -- A durable outbox may retry an already-acknowledged UUID. Return before
  -- consuming rate-limit tokens when the canonical row is an exact replay.
  if left(p_thread_id, 3) = 'dm:' then
    v_peer := private.chat_v2_direct_peer(p_thread_id, v_uid);
    if private.chat_v2_dm_blocked(v_uid, v_peer) then
      raise exception 'Conversation is blocked' using errcode = '42501';
    end if;
    if exists (
      select 1 from public.direct_messages as message
      where message.id = p_message_id and message.sender_id = v_uid
        and message.receiver_id = v_peer
        and message.content = coalesce(p_content, '')
        and message.message_kind = p_message_kind and message.payload = p_payload
    ) then
      return jsonb_build_object(
        'version', 2, 'thread_id', p_thread_id, 'message_id', p_message_id,
        'created_at', v_created_at, 'inserted', false
      );
    end if;
  elsif left(p_thread_id, 6) = 'group:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'group:');
    if exists (
      select 1 from public.group_messages as message
      where message.id = p_message_id and message.group_id = v_id
        and message.sender_id = v_uid
        and message.content = coalesce(p_content, '')
        and message.message_kind = p_message_kind and message.payload = p_payload
    ) then
      return jsonb_build_object(
        'version', 2, 'thread_id', p_thread_id, 'message_id', p_message_id,
        'created_at', v_created_at, 'inserted', false
      );
    end if;
  elsif left(p_thread_id, 5) = 'club:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'club:');
    if exists (
      select 1 from public.club_channel_messages as message
      where message.id = p_message_id and message.club_id = v_id
        and message.sender_auth_id = v_uid
        and message.content = coalesce(p_content, '')
        and message.message_kind = p_message_kind and message.payload = p_payload
    ) then
      return jsonb_build_object(
        'version', 2, 'thread_id', p_thread_id, 'message_id', p_message_id,
        'created_at', v_created_at, 'inserted', false
      );
    end if;
  elsif left(p_thread_id, 7) = 'clubdm:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'clubdm:');
    if exists (
      select 1 from public.club_inbox_messages as message
      where message.id = p_message_id and message.thread_id = v_id
        and message.sender_auth_id = v_uid
        and message.content = coalesce(p_content, '')
        and message.message_kind = p_message_kind and message.payload = p_payload
    ) then
      return jsonb_build_object(
        'version', 2, 'thread_id', p_thread_id, 'message_id', p_message_id,
        'created_at', v_created_at, 'inserted', false
      );
    end if;
  end if;

  perform private.enforce_authenticated_rate_limit('message_send:actor', null);
  perform private.enforce_authenticated_rate_limit('message_send:resource', p_thread_id);
  -- Notification v2 replaces legacy synchronous fan-out for this RPC only.
  -- Released direct inserts do not set this transaction-local marker.
  perform set_config('app.notification_pipeline', 'v2', true);

  if left(p_thread_id, 3) = 'dm:' then
    v_peer := private.chat_v2_direct_peer(p_thread_id, v_uid);
    insert into public.direct_messages (
      id, sender_id, receiver_id, content, message_kind, payload,
      created_at, delivered_at
    ) values (
      p_message_id, v_uid, v_peer, coalesce(p_content, ''), p_message_kind,
      p_payload, v_created_at, v_created_at
    ) on conflict (id) do nothing;
    v_inserted := found;
    if not v_inserted and not exists (
      select 1 from public.direct_messages as message
      where message.id = p_message_id and message.sender_id = v_uid
        and message.receiver_id = v_peer and message.content = coalesce(p_content, '')
        and message.message_kind = p_message_kind and message.payload = p_payload
    ) then raise exception 'Message id is already used' using errcode = '23505'; end if;
  elsif left(p_thread_id, 6) = 'group:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'group:');
    insert into public.group_messages (
      id, group_id, sender_id, content, message_kind, payload, created_at
    ) values (
      p_message_id, v_id, v_uid, coalesce(p_content, ''), p_message_kind,
      p_payload, v_created_at
    ) on conflict (id) do nothing;
    v_inserted := found;
    if not v_inserted and not exists (
      select 1 from public.group_messages as message
      where message.id = p_message_id and message.group_id = v_id
        and message.sender_id = v_uid and message.content = coalesce(p_content, '')
        and message.message_kind = p_message_kind and message.payload = p_payload
    ) then raise exception 'Message id is already used' using errcode = '23505'; end if;
  elsif left(p_thread_id, 5) = 'club:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'club:');
    if p_send_as_club then
      if not (
        exists (select 1 from public.club_auth_accounts as account
          where account.club_id = v_id and account.auth_user_id = v_uid)
        or exists (select 1 from public.club_followers as follower
          where follower.club_id = v_id and follower.profile_id = v_uid
            and follower.role = 'board_member')
      ) then raise exception 'Club sender identity is not authorized' using errcode = '42501'; end if;
      v_sender_club := v_id;
    else
      v_sender_profile := v_uid;
    end if;
    insert into public.club_channel_messages (
      id, club_id, sender_auth_id, sender_profile_id, sender_club_id,
      content, message_kind, payload, created_at
    ) values (
      p_message_id, v_id, v_uid, v_sender_profile, v_sender_club,
      coalesce(p_content, ''), p_message_kind, p_payload, v_created_at
    ) on conflict (id) do nothing;
    v_inserted := found;
    if not v_inserted and not exists (
      select 1 from public.club_channel_messages as message
      where message.id = p_message_id and message.club_id = v_id
        and message.sender_auth_id = v_uid
        and message.content = coalesce(p_content, '')
        and message.message_kind = p_message_kind and message.payload = p_payload
    ) then raise exception 'Message id is already used' using errcode = '23505'; end if;
  else
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'clubdm:');
    if p_send_as_club then
      select inbox.club_id into v_sender_club
      from public.club_inbox_threads as inbox where inbox.id = v_id;
      if not (
        exists (select 1 from public.club_auth_accounts as account
          where account.club_id = v_sender_club and account.auth_user_id = v_uid)
        or exists (select 1 from public.club_followers as follower
          where follower.club_id = v_sender_club and follower.profile_id = v_uid
            and follower.role = 'board_member')
      ) then raise exception 'Club sender identity is not authorized' using errcode = '42501'; end if;
    else
      v_sender_profile := v_uid;
    end if;
    insert into public.club_inbox_messages (
      id, thread_id, sender_auth_id, sender_profile_id, sender_club_id,
      content, message_kind, payload, created_at, delivered_at
    ) values (
      p_message_id, v_id, v_uid, v_sender_profile, v_sender_club,
      coalesce(p_content, ''), p_message_kind, p_payload, v_created_at, v_created_at
    ) on conflict (id) do nothing;
    v_inserted := found;
    if not v_inserted and not exists (
      select 1 from public.club_inbox_messages as message
      where message.id = p_message_id and message.thread_id = v_id
        and message.sender_auth_id = v_uid
        and message.content = coalesce(p_content, '')
        and message.message_kind = p_message_kind and message.payload = p_payload
    ) then raise exception 'Message id is already used' using errcode = '23505'; end if;
    update public.club_inbox_threads set updated_at = greatest(updated_at, v_created_at)
    where id = v_id;
  end if;

  if v_inserted then
    perform private.enqueue_chat_notification_outbox_v2(p_thread_id, p_message_id);
  end if;

  return jsonb_build_object(
    'version', 2, 'thread_id', p_thread_id, 'message_id', p_message_id,
    'created_at', v_created_at, 'inserted', v_inserted
  );
end
$function$;

create or replace function public.mark_conversation_read_v2(
  p_thread_id text,
  p_through_created_at timestamptz,
  p_through_message_id uuid,
  p_scope text default 'all'
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_peer uuid;
  v_marked integer := 0;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_through_created_at is null or p_through_message_id is null then
    raise exception 'A complete read boundary is required' using errcode = '22004';
  end if;
  if not private.chat_v2_can_access(p_thread_id, v_uid) then
    raise exception 'Conversation is not visible' using errcode = '42501';
  end if;
  if p_scope not in ('all', 'board', 'chat')
      or (left(p_thread_id, 5) <> 'club:' and p_scope <> 'all') then
    raise exception 'Invalid read scope' using errcode = '22023';
  end if;

  if left(p_thread_id, 3) = 'dm:' then
    v_peer := private.chat_v2_direct_peer(p_thread_id, v_uid);
    if not exists (select 1 from public.direct_messages as message
      where message.id = p_through_message_id and message.created_at = p_through_created_at
        and ((message.sender_id = v_uid and message.receiver_id = v_peer)
          or (message.sender_id = v_peer and message.receiver_id = v_uid))) then
      raise exception 'Read boundary is not in the conversation' using errcode = '22023';
    end if;
    update public.direct_messages as message
    set seen_at = coalesce(message.seen_at, now()),
        read_at = coalesce(message.read_at, now())
    where message.sender_id = v_peer and message.receiver_id = v_uid
      and message.seen_at is null
      and (message.created_at, message.id) <= (p_through_created_at, p_through_message_id);
    get diagnostics v_marked = row_count;
  elsif left(p_thread_id, 6) = 'group:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'group:');
    if not exists (select 1 from public.group_messages as message
      where message.id = p_through_message_id and message.group_id = v_id
        and message.created_at = p_through_created_at) then
      raise exception 'Read boundary is not in the conversation' using errcode = '22023';
    end if;
    insert into public.group_message_receipts (
      message_id, user_id, delivered_at, seen_at
    )
    select message.id, v_uid, now(), now()
    from public.group_messages as message
    where message.group_id = v_id and message.sender_id <> v_uid
      and (message.created_at, message.id) <= (p_through_created_at, p_through_message_id)
    on conflict (message_id, user_id) do update set
      delivered_at = coalesce(public.group_message_receipts.delivered_at, excluded.delivered_at),
      seen_at = coalesce(public.group_message_receipts.seen_at, excluded.seen_at);
    get diagnostics v_marked = row_count;
  elsif left(p_thread_id, 5) = 'club:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'club:');
    if not exists (select 1 from public.club_channel_messages as message
      where message.id = p_through_message_id and message.club_id = v_id
        and message.created_at = p_through_created_at
        and (p_scope = 'all'
          or (p_scope = 'board' and message.message_kind = 'announcement')
          or (p_scope = 'chat' and message.message_kind <> 'announcement'))) then
      raise exception 'Read boundary is not in the conversation' using errcode = '22023';
    end if;
  else
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'clubdm:');
    if not exists (select 1 from public.club_inbox_messages as message
      where message.id = p_through_message_id and message.thread_id = v_id
        and message.created_at = p_through_created_at) then
      raise exception 'Read boundary is not in the conversation' using errcode = '22023';
    end if;
    update public.club_inbox_messages as message set seen_at = coalesce(message.seen_at, now())
    where message.thread_id = v_id and message.sender_auth_id <> v_uid
      and message.seen_at is null
      and (message.created_at, message.id) <= (p_through_created_at, p_through_message_id);
    get diagnostics v_marked = row_count;
  end if;

  insert into public.chat_v2_read_state (
    viewer_id, thread_id, read_scope,
    last_read_created_at, last_read_message_id, updated_at
  ) values (
    v_uid, p_thread_id, p_scope,
    p_through_created_at, p_through_message_id, now()
  ) on conflict (viewer_id, thread_id, read_scope) do update set
    last_read_created_at = case
      when (excluded.last_read_created_at, excluded.last_read_message_id) >
        (public.chat_v2_read_state.last_read_created_at, public.chat_v2_read_state.last_read_message_id)
      then excluded.last_read_created_at else public.chat_v2_read_state.last_read_created_at end,
    last_read_message_id = case
      when (excluded.last_read_created_at, excluded.last_read_message_id) >
        (public.chat_v2_read_state.last_read_created_at, public.chat_v2_read_state.last_read_message_id)
      then excluded.last_read_message_id else public.chat_v2_read_state.last_read_message_id end,
    updated_at = now();

  return jsonb_build_object(
    'version', 2, 'thread_id', p_thread_id,
    'through_message_id', p_through_message_id, 'rows_marked', v_marked
  );
end
$function$;

create or replace function private.chat_v2_thread_uuid(
  p_thread_id text,
  p_prefix text
)
returns uuid
language plpgsql
immutable
set search_path = ''
as $function$
begin
  if p_thread_id is null or left(p_thread_id, char_length(p_prefix)) <> p_prefix then
    return null;
  end if;
  return substr(p_thread_id, char_length(p_prefix) + 1)::uuid;
exception when invalid_text_representation then
  return null;
end
$function$;

create or replace function private.chat_v2_can_access(
  p_thread_id text,
  p_viewer uuid
)
returns boolean
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  v_id uuid;
begin
  if p_viewer is null or p_thread_id is null then return false; end if;
  if left(p_thread_id, 3) = 'dm:' then
    return private.chat_v2_direct_peer(p_thread_id, p_viewer) is not null;
  elsif left(p_thread_id, 6) = 'group:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'group:');
    return v_id is not null and exists (
      select 1 from public.group_chat_members as member
      where member.group_id = v_id and member.user_id = p_viewer
    );
  elsif left(p_thread_id, 5) = 'club:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'club:');
    return v_id is not null and (
      exists (
        select 1 from public.club_followers as follower
        join public.clubs as club on club.id = follower.club_id
        where follower.club_id = v_id and follower.profile_id = p_viewer
          and club.is_active is true
      )
      or exists (
        select 1 from public.club_auth_accounts as account
        join public.clubs as club on club.id = account.club_id
        where account.club_id = v_id and account.auth_user_id = p_viewer
          and club.is_active is true
      )
    );
  elsif left(p_thread_id, 7) = 'clubdm:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'clubdm:');
    return v_id is not null and exists (
      select 1 from public.club_inbox_threads as inbox
      where inbox.id = v_id and (
        inbox.profile_id = p_viewer
        or exists (
          select 1 from public.club_auth_accounts as account
          where account.club_id = inbox.club_id
            and account.auth_user_id = p_viewer
        )
        or exists (
          select 1 from public.club_followers as follower
          where follower.club_id = inbox.club_id
            and follower.profile_id = p_viewer
            and follower.role = 'board_member'
        )
      )
    );
  end if;
  return false;
end
$function$;

revoke all on function private.chat_v2_direct_peer(text, uuid)
  from public, anon, authenticated;
revoke all on function private.chat_v2_dm_blocked(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.chat_v2_thread_uuid(text, text)
  from public, anon, authenticated;
revoke all on function private.chat_v2_can_access(text, uuid)
  from public, anon;
grant execute on function private.chat_v2_direct_peer(text, uuid) to authenticated;
grant execute on function private.chat_v2_dm_blocked(uuid, uuid) to authenticated;
grant execute on function private.chat_v2_thread_uuid(text, text) to authenticated;
grant execute on function private.chat_v2_can_access(text, uuid) to authenticated;

-- Trigger-only journal writer. SECURITY DEFINER is required because clients
-- have no INSERT privilege on the journal; authorization remains on the
-- canonical mutation and this function is not directly executable.
create or replace function private.record_chat_v2_message_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_row record;
  v_thread_id text;
  v_record jsonb;
  v_group_id uuid;
  v_club_id uuid;
  v_profile_id uuid;
begin
  if tg_op = 'DELETE' then v_row := old; else v_row := new; end if;

  if tg_table_name = 'direct_messages' then
    v_thread_id := 'dm:' || least(v_row.sender_id, v_row.receiver_id)::text
      || '|' || greatest(v_row.sender_id, v_row.receiver_id)::text;
    v_record := jsonb_build_object(
      'id', v_row.id, 'thread_id', v_thread_id,
      'sender_id', v_row.sender_id, 'receiver_id', v_row.receiver_id,
      'content', v_row.content, 'message_kind', v_row.message_kind,
      'payload', v_row.payload, 'crypto_version', v_row.crypto_version,
      'created_at', v_row.created_at, 'delivered_at', v_row.delivered_at,
      'seen_at', v_row.seen_at, 'read_at', v_row.read_at
    );
    insert into public.chat_v2_change_log (
      thread_id, message_id, operation, record,
      direct_sender_id, direct_receiver_id
    ) values (
      v_thread_id, v_row.id, tg_op, v_record,
      v_row.sender_id, v_row.receiver_id
    );
  elsif tg_table_name = 'group_messages' then
    v_group_id := v_row.group_id;
    v_thread_id := 'group:' || v_group_id::text;
    v_record := jsonb_build_object(
      'id', v_row.id, 'thread_id', v_thread_id,
      'sender_id', v_row.sender_id, 'group_id', v_group_id,
      'content', v_row.content, 'message_kind', v_row.message_kind,
      'payload', v_row.payload, 'crypto_version', v_row.crypto_version,
      'created_at', v_row.created_at
    );
    insert into public.chat_v2_change_log (
      thread_id, message_id, operation, record, group_id
    ) values (v_thread_id, v_row.id, tg_op, v_record, v_group_id);
  elsif tg_table_name = 'club_channel_messages' then
    v_club_id := v_row.club_id;
    v_thread_id := 'club:' || v_club_id::text;
    v_record := jsonb_build_object(
      'id', v_row.id, 'thread_id', v_thread_id,
      'club_id', v_club_id, 'sender_auth_id', v_row.sender_auth_id,
      'sender_profile_id', v_row.sender_profile_id,
      'sender_club_id', v_row.sender_club_id,
      'content', v_row.content, 'message_kind', v_row.message_kind,
      'payload', v_row.payload, 'crypto_version', v_row.crypto_version,
      'created_at', v_row.created_at
    );
    insert into public.chat_v2_change_log (
      thread_id, message_id, operation, record, club_id
    ) values (v_thread_id, v_row.id, tg_op, v_record, v_club_id);
  elsif tg_table_name = 'club_inbox_messages' then
    select inbox.club_id, inbox.profile_id into v_club_id, v_profile_id
    from public.club_inbox_threads as inbox where inbox.id = v_row.thread_id;
    v_thread_id := 'clubdm:' || v_row.thread_id::text;
    v_record := jsonb_build_object(
      'id', v_row.id, 'thread_id', v_thread_id,
      'inbox_id', v_row.thread_id, 'club_id', v_club_id,
      'sender_auth_id', v_row.sender_auth_id,
      'sender_profile_id', v_row.sender_profile_id,
      'sender_club_id', v_row.sender_club_id,
      'content', v_row.content, 'message_kind', v_row.message_kind,
      'payload', v_row.payload, 'crypto_version', v_row.crypto_version,
      'created_at', v_row.created_at, 'delivered_at', v_row.delivered_at,
      'seen_at', v_row.seen_at
    );
    insert into public.chat_v2_change_log (
      thread_id, message_id, operation, record, club_id,
      club_inbox_profile_id
    ) values (
      v_thread_id, v_row.id, tg_op, v_record, v_club_id, v_profile_id
    );
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end
$function$;

create or replace function private.record_chat_v2_receipt_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_row record;
  v_group_id uuid;
  v_thread_id text;
begin
  if tg_op = 'DELETE' then v_row := old; else v_row := new; end if;
  select message.group_id into v_group_id
  from public.group_messages as message where message.id = v_row.message_id;
  if v_group_id is null then return case when tg_op = 'DELETE' then old else new end; end if;
  v_thread_id := 'group:' || v_group_id::text;
  insert into public.chat_v2_change_log (
    thread_id, message_id, record_type, operation, record, group_id
  ) values (
    v_thread_id,
    v_row.message_id,
    'receipt',
    tg_op,
    jsonb_build_object(
      'message_id', v_row.message_id,
      'user_id', v_row.user_id,
      'delivered_at', v_row.delivered_at,
      'seen_at', v_row.seen_at
    ),
    v_group_id
  );
  return case when tg_op = 'DELETE' then old else new end;
end
$function$;

create or replace function private.record_chat_v2_poll_vote_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_row record;
  v_club_id uuid;
  v_thread_id text;
begin
  if tg_op = 'DELETE' then v_row := old; else v_row := new; end if;
  select message.club_id into v_club_id
  from public.club_channel_messages as message
  where message.id = v_row.message_id;
  if v_club_id is null then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  v_thread_id := 'club:' || v_club_id::text;
  insert into public.chat_v2_change_log (
    thread_id, message_id, record_type, operation, record, club_id
  ) values (
    v_thread_id,
    v_row.message_id,
    'poll_vote',
    tg_op,
    jsonb_build_object(
      'message_id', v_row.message_id,
      'option_index', case when tg_op = 'DELETE' then null else v_row.option_index end,
      'previous_option_index', case
        when tg_op in ('UPDATE', 'DELETE') then old.option_index
        else null
      end
    ),
    v_club_id
  );
  return case when tg_op = 'DELETE' then old else new end;
end
$function$;

revoke all on function private.record_chat_v2_message_change()
  from public, anon, authenticated;
revoke all on function private.record_chat_v2_receipt_change()
  from public, anon, authenticated;
revoke all on function private.record_chat_v2_poll_vote_change()
  from public, anon, authenticated;

create trigger direct_messages_chat_v2_change
after insert or update or delete on public.direct_messages
for each row execute function private.record_chat_v2_message_change();
create trigger group_messages_chat_v2_change
after insert or update or delete on public.group_messages
for each row execute function private.record_chat_v2_message_change();
create trigger club_channel_messages_chat_v2_change
after insert or update or delete on public.club_channel_messages
for each row execute function private.record_chat_v2_message_change();
create trigger club_inbox_messages_chat_v2_change
after insert or update or delete on public.club_inbox_messages
for each row execute function private.record_chat_v2_message_change();
create trigger group_message_receipts_chat_v2_change
after insert or update or delete on public.group_message_receipts
for each row execute function private.record_chat_v2_receipt_change();
create trigger club_channel_poll_votes_chat_v2_change
after insert or update or delete on public.club_channel_poll_votes
for each row execute function private.record_chat_v2_poll_vote_change();

create or replace function public.get_messages_page_v2(
  p_thread_id text,
  p_limit integer default 40,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 50);
  v_id uuid;
  v_peer uuid;
  v_items jsonb := '[]'::jsonb;
  v_has_more boolean := false;
  v_next_created_at timestamptz;
  v_next_id uuid;
  v_sync_cursor bigint := 0;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    raise exception 'Both cursor fields must be provided together' using errcode = '22023';
  end if;
  if not private.chat_v2_can_access(p_thread_id, v_uid) then
    raise exception 'Conversation is not visible' using errcode = '42501';
  end if;

  if left(p_thread_id, 3) = 'dm:' then
    v_peer := private.chat_v2_direct_peer(p_thread_id, v_uid);
    with page as materialized (
      select message.*
      from public.direct_messages as message
      where ((message.sender_id = v_uid and message.receiver_id = v_peer)
          or (message.sender_id = v_peer and message.receiver_id = v_uid))
        and (p_cursor_created_at is null
          or (message.created_at, message.id) < (p_cursor_created_at, p_cursor_id))
      order by message.created_at desc, message.id desc limit v_limit + 1
    ), bounded as (select * from page order by created_at desc, id desc limit v_limit)
    select
      coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'thread_id', p_thread_id, 'sender_id', sender_id,
        'receiver_id', receiver_id, 'content', content,
        'message_kind', message_kind, 'payload', payload,
        'crypto_version', crypto_version, 'created_at', created_at,
        'delivered_at', delivered_at, 'seen_at', seen_at, 'read_at', read_at
      ) order by created_at desc, id desc), '[]'::jsonb),
      (select count(*) > v_limit from page),
      (array_agg(created_at order by created_at asc, id asc))[1],
      (array_agg(id order by created_at asc, id asc))[1]
    into v_items, v_has_more, v_next_created_at, v_next_id from bounded;
  elsif left(p_thread_id, 6) = 'group:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'group:');
    with page as materialized (
      select message.*
      from public.group_messages as message
      where message.group_id = v_id
        and (p_cursor_created_at is null
          or (message.created_at, message.id) < (p_cursor_created_at, p_cursor_id))
      order by message.created_at desc, message.id desc limit v_limit + 1
    ), bounded as (select * from page order by created_at desc, id desc limit v_limit)
    select
      coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'thread_id', p_thread_id, 'group_id', group_id,
        'sender_id', sender_id, 'content', content,
        'message_kind', message_kind, 'payload', payload,
        'crypto_version', crypto_version, 'created_at', created_at,
        'receipts', coalesce((
          select jsonb_agg(jsonb_build_object(
            'user_id', receipt.user_id,
            'delivered_at', receipt.delivered_at,
            'seen_at', receipt.seen_at
          ) order by receipt.user_id)
          from public.group_message_receipts as receipt
          where receipt.message_id = bounded.id
        ), '[]'::jsonb)
      ) order by created_at desc, id desc), '[]'::jsonb),
      (select count(*) > v_limit from page),
      (array_agg(created_at order by created_at asc, id asc))[1],
      (array_agg(id order by created_at asc, id asc))[1]
    into v_items, v_has_more, v_next_created_at, v_next_id from bounded;
  elsif left(p_thread_id, 5) = 'club:' then
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'club:');
    with page as materialized (
      select message.*
      from public.club_channel_messages as message
      where message.club_id = v_id
        and (p_cursor_created_at is null
          or (message.created_at, message.id) < (p_cursor_created_at, p_cursor_id))
      order by message.created_at desc, message.id desc limit v_limit + 1
    ), bounded as (select * from page order by created_at desc, id desc limit v_limit)
    select
      coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'thread_id', p_thread_id, 'club_id', club_id,
        'sender_auth_id', sender_auth_id, 'sender_profile_id', sender_profile_id,
        'sender_club_id', sender_club_id, 'content', content,
        'message_kind', message_kind, 'payload', payload,
        'crypto_version', crypto_version, 'created_at', created_at,
        'poll_totals', coalesce((
          select jsonb_agg(coalesce(vote_counts.vote_count, 0)
                           order by options.option_index)
          from generate_series(
            0,
            greatest(jsonb_array_length(coalesce(bounded.payload->'pollOptions', '[]'::jsonb)) - 1, 0)
          ) as options(option_index)
          left join (
            select vote.option_index, count(*)::integer as vote_count
            from public.club_channel_poll_votes as vote
            where vote.message_id = bounded.id
            group by vote.option_index
          ) as vote_counts using (option_index)
        ), '[]'::jsonb),
        'viewer_option_index', (
          select vote.option_index
          from public.club_channel_poll_votes as vote
          where vote.message_id = bounded.id and vote.voter_auth_id = v_uid
        )
      ) order by created_at desc, id desc), '[]'::jsonb),
      (select count(*) > v_limit from page),
      (array_agg(created_at order by created_at asc, id asc))[1],
      (array_agg(id order by created_at asc, id asc))[1]
    into v_items, v_has_more, v_next_created_at, v_next_id from bounded;
  else
    v_id := private.chat_v2_thread_uuid(p_thread_id, 'clubdm:');
    with page as materialized (
      select message.*
      from public.club_inbox_messages as message
      where message.thread_id = v_id
        and (p_cursor_created_at is null
          or (message.created_at, message.id) < (p_cursor_created_at, p_cursor_id))
      order by message.created_at desc, message.id desc limit v_limit + 1
    ), bounded as (select * from page order by created_at desc, id desc limit v_limit)
    select
      coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'thread_id', p_thread_id, 'inbox_id', thread_id,
        'sender_auth_id', sender_auth_id, 'sender_profile_id', sender_profile_id,
        'sender_club_id', sender_club_id, 'content', content,
        'message_kind', message_kind, 'payload', payload,
        'crypto_version', crypto_version, 'created_at', created_at,
        'delivered_at', delivered_at, 'seen_at', seen_at
      ) order by created_at desc, id desc), '[]'::jsonb),
      (select count(*) > v_limit from page),
      (array_agg(created_at order by created_at asc, id asc))[1],
      (array_agg(id order by created_at asc, id asc))[1]
    into v_items, v_has_more, v_next_created_at, v_next_id from bounded;
  end if;

  select coalesce(max(change.change_id), 0) into v_sync_cursor
  from public.chat_v2_change_log as change where change.thread_id = p_thread_id;

  return jsonb_build_object(
    'version', 2, 'thread_id', p_thread_id, 'page_size', v_limit,
    'items', v_items, 'has_more', v_has_more,
    'next_cursor', case when v_has_more then jsonb_build_object(
      'created_at', v_next_created_at, 'id', v_next_id
    ) else null end,
    'sync_cursor', v_sync_cursor
  );
end
$function$;

create or replace function public.get_messages_since_v2(
  p_thread_id text,
  p_after_change_id bigint,
  p_limit integer default 200
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 200), 1), 500);
  v_changes jsonb;
  v_has_more boolean;
  v_next bigint;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_after_change_id is null or p_after_change_id < 0 then
    raise exception 'A non-negative change cursor is required' using errcode = '22023';
  end if;
  if not private.chat_v2_can_access(p_thread_id, v_uid) then
    raise exception 'Conversation is not visible' using errcode = '42501';
  end if;
  if nextval('private.chat_v2_cleanup_clock') % 1024 = 0 then
    perform private.cleanup_chat_v2_change_log();
  end if;
  if p_after_change_id > 0
     and exists (
       select 1 from public.chat_v2_change_log as newer
       where newer.thread_id = p_thread_id
         and newer.change_id > p_after_change_id
     )
     and not exists (
       select 1 from public.chat_v2_change_log as cursor_row
       where cursor_row.thread_id = p_thread_id
         and cursor_row.change_id = p_after_change_id
     ) then
    select coalesce(max(change.change_id), p_after_change_id)
      into v_next
      from public.chat_v2_change_log as change
      where change.thread_id = p_thread_id;
    return jsonb_build_object(
      'version', 2, 'thread_id', p_thread_id, 'changes', '[]'::jsonb,
      'has_more', false, 'next_change_id', v_next, 'cursor_expired', true
    );
  end if;
  with page as materialized (
    select change.* from public.chat_v2_change_log as change
    where change.thread_id = p_thread_id
      and change.change_id > p_after_change_id
    order by change.change_id limit v_limit + 1
  ), bounded as (select * from page order by change_id limit v_limit)
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'change_id', bounded.change_id, 'record_type', bounded.record_type,
      'operation', bounded.operation, 'message_id', bounded.message_id,
      'changed_at', bounded.changed_at,
      'record', case when bounded.record_type = 'poll_vote' then
        jsonb_build_object(
          'message_id', bounded.message_id,
          'option_index', bounded.record->'option_index',
          'previous_option_index', bounded.record->'previous_option_index',
          'is_viewer', case when bounded.operation <> 'DELETE' then exists (
            select 1 from public.club_channel_poll_votes as vote
            where vote.message_id = bounded.message_id
              and vote.voter_auth_id = v_uid
          ) else false end
        )
      else bounded.record end
    ) order by bounded.change_id), '[]'::jsonb),
    (select count(*) > v_limit from page),
    coalesce(max(bounded.change_id), p_after_change_id)
  into v_changes, v_has_more, v_next from bounded;
  return jsonb_build_object(
    'version', 2, 'thread_id', p_thread_id, 'changes', v_changes,
    'has_more', v_has_more, 'next_change_id', v_next,
    'cursor_expired', false
  );
end
$function$;

revoke all on function public.get_conversation_summaries_v2(integer, timestamptz, text)
  from public, anon, authenticated;
revoke all on function public.get_messages_page_v2(text, integer, timestamptz, uuid)
  from public, anon, authenticated;
revoke all on function public.get_messages_since_v2(text, bigint, integer)
  from public, anon, authenticated;
revoke all on function public.send_message_v2(text, uuid, text, text, jsonb, timestamptz, boolean)
  from public, anon, authenticated;
revoke all on function public.mark_conversation_read_v2(text, timestamptz, uuid, text)
  from public, anon, authenticated;

grant execute on function public.get_conversation_summaries_v2(integer, timestamptz, text)
  to authenticated;
grant execute on function public.get_messages_page_v2(text, integer, timestamptz, uuid)
  to authenticated;
grant execute on function public.get_messages_since_v2(text, bigint, integer)
  to authenticated;
grant execute on function public.send_message_v2(text, uuid, text, text, jsonb, timestamptz, boolean)
  to authenticated;
grant execute on function public.mark_conversation_read_v2(text, timestamptz, uuid, text)
  to authenticated;

comment on function public.get_conversation_summaries_v2(integer, timestamptz, text) is
  'Chat v2 keyset-paginated conversation summaries; viewer identity is auth.uid().';
comment on function public.get_messages_page_v2(text, integer, timestamptz, uuid) is
  'Chat v2 stable newest-first message page over canonical chat tables.';
comment on function public.get_messages_since_v2(text, bigint, integer) is
  'Chat v2 bounded change reconciliation including message deletes and group receipts.';
comment on function public.send_message_v2(text, uuid, text, text, jsonb, timestamptz, boolean) is
  'Chat v2 idempotent, action-rate-limited canonical send; sender is auth.uid().';
comment on function public.mark_conversation_read_v2(text, timestamptz, uuid, text) is
  'Chat v2 set-based read boundary update; viewer is auth.uid().';
