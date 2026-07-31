-- Persist club-channel poll votes independently from immutable message bodies.
-- One row per authenticated voter avoids lost updates when multiple members
-- vote concurrently and lets Realtime update every open community screen.

create table public.club_channel_poll_votes (
  message_id uuid not null
    references public.club_channel_messages(id) on delete cascade,
  voter_auth_id uuid not null
    references auth.users(id) on delete cascade,
  option_index smallint not null check (option_index between 0 and 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (message_id, voter_auth_id)
);

alter table public.club_channel_poll_votes enable row level security;

create policy club_channel_poll_votes_read_participants
  on public.club_channel_poll_votes for select to authenticated
  using (
    exists (
      select 1
      from public.club_channel_messages message
      where message.id = club_channel_poll_votes.message_id
        and (
          exists (
            select 1 from public.club_followers follower
            where follower.club_id = message.club_id
              and follower.profile_id = (select auth.uid())
          )
          or exists (
            select 1 from public.club_auth_accounts account
            where account.club_id = message.club_id
              and account.auth_user_id = (select auth.uid())
          )
        )
    )
  );

create policy club_channel_poll_votes_insert_own
  on public.club_channel_poll_votes for insert to authenticated
  with check (
    voter_auth_id = (select auth.uid())
    and exists (
      select 1
      from public.club_channel_messages message
      where message.id = club_channel_poll_votes.message_id
        and message.message_kind = 'poll'
        and jsonb_typeof(message.payload -> 'pollOptions') = 'array'
        and club_channel_poll_votes.option_index
          < jsonb_array_length(message.payload -> 'pollOptions')
        and (
          exists (
            select 1 from public.club_followers follower
            where follower.club_id = message.club_id
              and follower.profile_id = (select auth.uid())
          )
          or exists (
            select 1 from public.club_auth_accounts account
            where account.club_id = message.club_id
              and account.auth_user_id = (select auth.uid())
          )
        )
    )
  );

create policy club_channel_poll_votes_update_own
  on public.club_channel_poll_votes for update to authenticated
  using (voter_auth_id = (select auth.uid()))
  with check (
    voter_auth_id = (select auth.uid())
    and exists (
      select 1
      from public.club_channel_messages message
      where message.id = club_channel_poll_votes.message_id
        and message.message_kind = 'poll'
        and jsonb_typeof(message.payload -> 'pollOptions') = 'array'
        and club_channel_poll_votes.option_index
          < jsonb_array_length(message.payload -> 'pollOptions')
        and (
          exists (
            select 1 from public.club_followers follower
            where follower.club_id = message.club_id
              and follower.profile_id = (select auth.uid())
          )
          or exists (
            select 1 from public.club_auth_accounts account
            where account.club_id = message.club_id
              and account.auth_user_id = (select auth.uid())
          )
        )
    )
  );

create policy club_channel_poll_votes_delete_own
  on public.club_channel_poll_votes for delete to authenticated
  using (voter_auth_id = (select auth.uid()));

grant select, insert, update, delete
  on public.club_channel_poll_votes to authenticated;

alter table public.club_channel_poll_votes replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'club_channel_poll_votes'
  ) then
    alter publication supabase_realtime
      add table public.club_channel_poll_votes;
  end if;
end
$$;
