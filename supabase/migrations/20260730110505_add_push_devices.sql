create table public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  fcm_token text not null unique,
  platform text not null check (platform in ('android', 'ios')),
  notifications_enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index push_devices_user_id_idx
  on public.push_devices (user_id);

alter table public.push_devices enable row level security;

revoke all on table public.push_devices from anon;
grant select, insert, update, delete
  on table public.push_devices to authenticated;
grant all on table public.push_devices to service_role;

create policy "Users can read their own push devices"
  on public.push_devices
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can register their own push devices"
  on public.push_devices
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own push devices"
  on public.push_devices
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can remove their own push devices"
  on public.push_devices
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
