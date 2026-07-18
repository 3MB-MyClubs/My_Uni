# ClubUp App Review resubmission

This checklist covers the Guideline 1.2 user-generated-content rejection for submission `3eb28414-2e35-4bf7-ac51-b3d8f062b43a`.

## Before building

1. Apply `supabase/migrations/005_content_moderation.sql` to the production Supabase project.
2. Publish the updated `docs/` site so `https://3mb-myclubs.github.io/My_Uni/terms/` is public.
3. Make a fresh iOS build with a higher build number than `2`.
4. Test reporting while signed in to a real student account. Confirm a row appears in `moderation_reports`.
5. Test blocking a real second account. Confirm rows appear in both `user_blocks` and `moderation_reports`.

## Required moderation operation

Check the production moderation queue often enough to act within 24 hours:

```sql
select
  id,
  created_at,
  created_at + interval '24 hours' as response_due_at,
  target_type,
  target_id,
  reported_user_id,
  reason,
  source,
  content_snapshot
from moderation_reports
where status = 'open'
order by created_at;
```

For a confirmed violation, remove the content, suspend or delete the offending account when appropriate, then set the report to `actioned` with `reviewed_at` and `action_notes`. Keep this process staffed; the UI and policy promise review within 24 hours.

## Physical-device screen recording

Record one continuous video on a physical iPhone or iPad:

1. Delete and reinstall ClubUp so the current Terms acceptance is not already stored.
2. Launch the app and show the pre-authentication **Community Safety Terms** screen.
3. Scroll the terms, open the full Terms of Use if helpful, select the agreement checkbox, and tap **Agree and continue**.
4. Sign in with the App Review student account.
5. On Home, open a post's `…` menu, tap **Report post**, select a reason, and show that the post disappears immediately.
6. Open Explore, select another student's profile, tap `…`, then **Block and report user**.
7. Select a reason, confirm **Block and report**, and show that the profile closes and the success message appears.

Upload the recording somewhere App Review can open without authentication and place its direct URL in **App Review Information → Notes**.

## Suggested App Review notes

> Guideline 1.2 safeguards are now implemented in both English and Turkish. On a fresh install, ClubUp presents its Terms of Use and Community Safety Terms before any registration or login path and requires affirmative acceptance. The terms state zero tolerance for objectionable content and abusive users and commit us to reviewing reports within 24 hours, removing violating content, and ejecting offending users.
>
> To report content: sign in as the supplied student review account, open Home, tap the `…` button on any post, choose “Report post,” and select a reason. The report is sent to our moderation queue and the post is removed from that user's feed immediately.
>
> To block an abusive user: open Explore, select a student profile, tap `…`, choose “Block and report user,” select a reason, and confirm. Blocking immediately removes the user/content from the user's feed and also creates a developer moderation report.
>
> Full Terms of Use: https://3mb-myclubs.github.io/My_Uni/terms/
>
> Physical-device demonstration: [INSERT DIRECT VIDEO URL]

## Suggested reply to the rejection

> Hello App Review,
>
> We implemented the requested Guideline 1.2 protections in the new build: a mandatory Terms of Use agreement before registration or login, functional content reporting, and a “Block and report user” mechanism that immediately removes the user/content from the user's feed while notifying our moderation queue. Our published terms clearly prohibit objectionable content and abusive users, and we review reports within 24 hours to remove violating content and eject offending accounts.
>
> A physical-device recording demonstrating all three flows is included in App Review Information → Notes. Thank you.
