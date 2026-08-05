-- Public read-only configuration used by mobile clients to enforce minimum
-- supported builds. The values are not secrets; only the service role/database
-- owner should be able to change them.
create table public.app_update_config (
  id text primary key check (id = 'global'),
  android_min_build integer not null default 1 check (android_min_build > 0),
  ios_min_build integer not null default 1 check (ios_min_build > 0),
  android_store_url text not null default
    'https://play.google.com/store/apps/details?id=com.threemb.clupup',
  ios_store_url text not null default
    'https://apps.apple.com/tr/app/clubup/id6791479131?l=tr',
  updated_at timestamptz not null default now()
);

alter table public.app_update_config enable row level security;

revoke all on table public.app_update_config from anon, authenticated;
grant select on table public.app_update_config to anon, authenticated;

create policy "Anyone can read app update config"
  on public.app_update_config
  for select
  to anon, authenticated
  using (true);

insert into public.app_update_config (id, android_min_build, ios_min_build)
values ('global', 2, 2);
