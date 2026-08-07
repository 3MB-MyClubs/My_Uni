alter table public.user_preferences
  add column onboarding_version int;

-- Bugune kadar kayitli olan herkes turu zaten gormus sayilir; bu migration
-- sonrasinda mevcut kullanicilar onboarding turunu tekrar gormemeli.
insert into public.user_preferences (user_id, onboarding_version)
select id, 1 from auth.users
on conflict (user_id) do update
  set onboarding_version = 1,
      updated_at = now();
