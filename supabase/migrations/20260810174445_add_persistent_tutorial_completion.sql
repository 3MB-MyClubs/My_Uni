alter table public.user_preferences
  add column has_completed_tutorial boolean not null default false;

-- Treat every account that exists at rollout as complete. This preserves the
-- previous onboarding migration's strategy and repairs accounts whose old
-- version field was cleared by an interrupted manual replay. Profiles created
-- after this migration keep the false default and receive the first-time tour.
insert into public.user_preferences (user_id, has_completed_tutorial)
select id, true from auth.users
on conflict (user_id) do update
  set has_completed_tutorial = true,
      updated_at = now();
