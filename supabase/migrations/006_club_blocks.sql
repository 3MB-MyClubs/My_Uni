-- Let users block clubs and later manage/unblock both club and user blocks.

alter table moderation_reports
  drop constraint if exists moderation_reports_target_type_check;
alter table moderation_reports
  add constraint moderation_reports_target_type_check
  check (target_type in (
    'post', 'comment', 'profile', 'message', 'event', 'club'
  ));

create table if not exists club_blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  club_id uuid not null references clubs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, club_id)
);

create index if not exists club_blocks_club_idx on club_blocks (club_id);

alter table club_blocks enable row level security;

create policy "club_blocks_select_own" on club_blocks
  for select to authenticated
  using ((select auth.uid()) = blocker_id);

create policy "club_blocks_insert_own" on club_blocks
  for insert to authenticated
  with check ((select auth.uid()) = blocker_id);

create policy "club_blocks_delete_own" on club_blocks
  for delete to authenticated
  using ((select auth.uid()) = blocker_id);

grant select, insert, delete on table club_blocks to authenticated;
