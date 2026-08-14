# Database reproducibility and release gate

## Strategy

Production behavior is authoritative. The repository now uses an additive core
bootstrap (`00000000000000_core_schema_bootstrap.sql`) before the historical
chain and a forward repair migration after the v2 phases. Applied timestamped
production migrations were not reordered or replayed.

The legacy numeric history contained duplicate versions 005, 006, 007, 008,
and 010. Supabase records only the numeric prefix, so those pairs could never
be replayed deterministically. Each pair is consolidated under its existing
version; the byte-for-byte originals remain under
`supabase/legacy_migrations/duplicates/`. Existing projects that already record
those numeric versions do not rerun them.

The new `00000000000000` bootstrap is for empty databases. On an existing
production project, do **not** execute it over the live schema. Before the first
remote push from this repository:

1. Capture `supabase migration list --linked`, review a schema diff, and take a
   restorable backup.
2. Verify that the production core objects represented by the bootstrap already
   exist, then mark version `00000000000000` applied with `supabase migration
   repair --status applied 00000000000000`.
3. Confirm that versions 005, 006, 007, 008, and 010 are already recorded. Repair
   one of those versions only when the linked history proves it is missing and
   the corresponding production objects have been verified manually.
4. Apply and validate the forward `20260813121253` repair in staging before
   production.

Never run a blind migration repair or push against production. This repository
does not perform any linked or production mutation in CI.

## Source inventory

The clean schema contains 52 public tables and all 52 have RLS enabled. It has
160 deliberate policies across public, Storage, and Realtime, 42 public
triggers, and three security-invoker aggregate views.

Canonical/reference tables: `academic_years`, `club_categories`, `interests`,
`majors`, `profiles`, `clubs`, `club_auth_accounts`, `club_account_contexts`,
`club_followers`, `club_posts`, `events`, `event_rsvps`, `post_comments`,
`post_likes`, `post_views`, `profile_follows`, `profile_double_majors`,
`profile_minors`, `student_interests`, `moderation_reports`, `user_blocks`,
`club_blocks`, `terms_acceptances`, `app_admins`, `app_update_config`,
`user_preferences`, and `user_presence_status`.

Auth/security tables: `pending_signups`, `pending_password_resets`; private v2
challenge and rate-limit tables are intentionally absent from generated Data
API types.

Chat/notification/worker tables: `direct_messages`, `group_chats`,
`group_chat_members`, `group_messages`, `group_message_receipts`,
`club_channel_messages`, `club_channel_poll_votes`, `club_inbox_threads`,
`club_inbox_messages`, `e2ee_devices`, `e2ee_threads`,
`e2ee_thread_key_envelopes`, `push_devices`, `notifications`,
`chat_v2_read_state`, `chat_v2_change_log`, `notification_outbox_v2`,
`notification_recipients_v2`, `notification_deliveries_v2`, and
`storage_cleanup_queue_v2`.

Poll/check-in tables: `event_checkins`, `polls`, and `poll_votes`.

Views: `club_member_counts`, `event_rsvp_counts`, and `post_like_counts`.
The generated [database types](../supabase/live_database.types.ts) are the
reviewable column/nullability/FK/RPC inventory. Constraints, indexes, grants,
functions, triggers, and policies are defined in migrations and verified from
zero by CI rather than inferred from live types.

Extensions used by application migrations are `pgcrypto` and `pg_net`;
Supabase's local stack supplies its service extensions. pgTAP is created only
inside transactional test suites. No application cron jobs or materialized
views are currently defined. Vault is referenced only by the legacy push
dispatcher.

Storage buckets are reproducible: public `avatars`, `club-avatars`,
`post-images`, `event-images`, and `group-chat-photos`, plus private
`chat-attachments`. Bucket limits/MIME rules and object policies live in the
migrations; no production objects are copied.

Realtime publication members are `chat_v2_change_log`,
`club_channel_messages`, `club_channel_poll_votes`, `club_followers`,
`club_inbox_messages`, `club_inbox_threads`, `direct_messages`,
`group_chat_members`, `group_chats`, `group_message_receipts`, `group_messages`,
`notifications`, and `post_comments`. Membership additions are guarded.

## Reset, tests, lint and types

```sh
supabase start
supabase db reset --local
supabase test db supabase/tests/*.test.sql --local
bash scripts/check-database-lint.sh
supabase gen types typescript --local | perl -0pe 's/\n\n\z/\n/' > /tmp/database.types.ts
diff -u supabase/live_database.types.ts /tmp/database.types.ts
```

The current pgTAP gate is 10 files / 286 assertions and includes positive and
negative authorization checks for F1-F4, profile email visibility, check-ins,
poll identity, Feed v2, Chat v2, notification internals, Storage cleanup, and
service-role worker boundaries. Fixtures create data only. Former schema-shaped
fixtures are archived outside test discovery.

The lint wrapper fails every finding except one exact `plpgsql_check` false
positive: it cannot resolve `pg_temp.notification_v2_batch`, which is created
earlier in the same `expand_notification_outbox_v2` transaction. Notification
suite 09 executes that function and covers the path instead.

## Edge Functions and secrets

Client-required v1 and v2 signup/password-reset functions are all present.
`send-push` preserves the released notification path;
`notification-worker-v2` and `storage-cleanup-worker-v2` are worker-only.
JWT behavior is explicit in `supabase/config.toml`.

Required secret names (never values): `SUPABASE_URL`,
`SUPABASE_SERVICE_ROLE_KEY` or `SUPABASE_SECRET_KEYS`, `RESEND_API_KEY`,
`SIGNUP_CODE_PEPPER`, `FIREBASE_SERVICE_ACCOUNT`,
`NOTIFICATION_WORKER_SECRET`, and `STORAGE_CLEANUP_WORKER_SECRET`.

For legacy push delivery, create Vault secrets named `notification_push_url`
(the full `send-push` function URL) and `notification_push_anon_key`. Local
resets deliberately work without them and skip outbound delivery.

## Flutter gate and quarantine

CI gates the 12 stable protocol/controller/media contract files listed in the
workflow and compiles a release web build. The rest of the historical Flutter
suite is explicitly quarantined from the release gate because it includes
fixture-dependent integration tests, removed golden baselines, and harness
drift. It is not treated as passing or deleted; owners should move tests into
the gate individually after repairing their fixtures/goldens. Analyzer info
diagnostics remain visible, while generated `build/**` and `.dart_tool/**`
sources are excluded.
