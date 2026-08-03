-- Persist a low-frequency last-seen heartbeat separately from profile edits.
-- Realtime Presence remains the source of truth while a user is online.

create table if not exists public.user_presence_status (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  last_seen_at timestamptz not null default now()
);

alter table public.user_presence_status enable row level security;

revoke all on table public.user_presence_status from anon;
grant select, insert, update on table public.user_presence_status
  to authenticated;

drop policy if exists "Authenticated users can read presence status"
  on public.user_presence_status;
create policy "Authenticated users can read presence status"
  on public.user_presence_status
  for select
  to authenticated
  using (true);

drop policy if exists "Users can insert own presence status"
  on public.user_presence_status;
create policy "Users can insert own presence status"
  on public.user_presence_status
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own presence status"
  on public.user_presence_status;
create policy "Users can update own presence status"
  on public.user_presence_status
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
