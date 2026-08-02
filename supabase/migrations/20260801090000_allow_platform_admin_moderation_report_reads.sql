-- Allow the singleton platform administrator to review the server-side
-- moderation queue through the publishable client.

grant select on table public.moderation_reports to authenticated;

drop policy if exists "Platform admin can read moderation reports"
  on public.moderation_reports;
create policy "Platform admin can read moderation reports"
  on public.moderation_reports
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.app_admins as app_admin
      where app_admin.auth_user_id = (select auth.uid())
    )
  );
