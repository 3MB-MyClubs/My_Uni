create table public.app_admins (
  singleton boolean primary key default true
    constraint app_admins_singleton_check check (singleton),
  auth_user_id uuid not null unique
    references auth.users (id) on delete cascade,
  email text not null unique
    constraint app_admins_email_normalized_check
      check (email = lower(btrim(email)) and position('@' in email) > 1),
  created_at timestamptz not null default now()
);

comment on table public.app_admins is
  'Singleton platform-admin identity. Club owners remain in club_auth_accounts.';

alter table public.app_admins enable row level security;

revoke all on table public.app_admins from anon, authenticated;
grant select on table public.app_admins to authenticated;

create policy "App admin can read own assignment"
  on public.app_admins
  for select
  to authenticated
  using ((select auth.uid()) = auth_user_id);
