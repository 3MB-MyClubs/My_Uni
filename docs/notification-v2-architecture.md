# Notification v2 / outbox architecture

## Confirmed pre-v2 flow

The canonical inbox is `public.notifications`; released clients select that
table, update only `read_at`, and subscribe to it through Supabase Realtime.
Navigation continues to use `type`, `target_type`, `target_id`,
`actor_user_id`, `notification_group_key`, and `message_count`.

| Source | Canonical write and legacy trigger | Recipient work before v2 | Push/retry behavior |
| --- | --- | --- | --- |
| Club post | `club_posts` → `private.notify_club_post` | loops every `club_followers` row and inserts one notification each | every insert fires one `pg_net` call |
| Club event | `events` → `private.notify_club_event` | loops every follower | one `pg_net` call per recipient |
| Direct message | `direct_messages` → `private.notify_direct_message` | one notification insert | one Edge call, then sequential devices |
| Group message | `group_messages` → `private.notify_group_message` | loops members except sender | one Edge call per recipient |
| Club Board message | `club_channel_messages` → `private.notify_club_channel_message` | loops all followers | one Edge call per recipient |
| Club Chat mention | `club_channel_messages` → `private.notify_club_channel_mention` | scans every follower, then tests the mention JSON | one Edge call per matched recipient |
| Club inbox | `club_inbox_messages` → `private.notify_club_inbox_message` | loops club accounts/board members, or inserts for the student | one Edge call per recipient |
| Follow | `profile_follows` → `private.notify_profile_follow` | one recipient | legacy delivery |
| Like/comment/RSVP | respective table → `private.notify_club_activity` | loops club auth accounts | legacy delivery |
| Moderation/admin | no durable remote notification generator was found; current UI/local state remains unchanged | none in this pipeline | none in this pipeline |

`send-push` claims with `push_started_at`, requests a Google OAuth token on each
invocation, then sends devices sequentially. If every FCM send fails without an
exception, `push_started_at` remains populated while `push_sent_at` remains
null, making the row unclaimable. There is no durable retry scheduler or
per-device state. The server-side preference available to this pipeline is
`push_devices.notifications_enabled`; the existing club-room mute preference
is local UI state, and no server-side quiet-hours preference exists.

## V2 boundary and duplicate protection

New Flutter post/event creation uses `create_club_post_v2` and
`create_club_event_v2`. Chat already uses `send_message_v2`; that RPC now marks
the transaction and enqueues the message event. Each RPC performs one action
rate-limit charge, the canonical business insert, and one logical outbox insert
in one transaction. It never falls back to a direct v1 insert.

The transaction-local `app.notification_pipeline = v2` marker makes legacy
fan-out triggers disjoint for that mutation. Released clients do not set the
marker, so their existing direct writes and synchronous legacy behavior remain.
V2 canonical notification rows have `pipeline_version = 2`, which also excludes
them from the legacy per-row `pg_net` push triggers.

Post mentions create an explicit-recipient event and exclude those IDs from the
general follower event. Club Chat mentions join explicit IDs back to
`club_followers`; they no longer scan all followers merely to find named users.

## Durable pipeline

- `notification_outbox_v2`: logical event, audience, stable `event_key`, cursor,
  attempts, next attempt, lease, terminal error, recipient/batch counters.
- `notification_recipients_v2`: unique `(outbox_id, recipient_id)` mapping to the
  existing canonical notification row.
- `notification_deliveries_v2`: unique `(outbox_id, device_id)` state with
  independent attempts, lease, provider result, and terminal state.
- Default batch: 250; RPCs clamp it to 1–500. At 250, SQL/HTTP payloads stay
  bounded while a one-minute worker cadence can drain ordinary audiences
  promptly. Production telemetry should decide whether to tune it.
- Claims use `FOR UPDATE SKIP LOCKED`, atomic status transitions, 90-second
  leases, and random lease tokens. Expired leases are reclaimable; exhausted
  crash leases become terminal rather than getting stuck.
- Retry delay is exponential from 15 seconds, capped at 6 hours, with 0–15
  seconds of deterministic jitter. Eight attempts is the worker default.
- FCM `UNREGISTERED`/not-found and malformed payloads are terminal; network,
  408, 429, 5xx, and provider auth failures are retryable. Invalid devices are
  removed. A successful device is never reclaimed when another device fails.
- The worker reuses a module-level OAuth token until five minutes before expiry.
  FCM HTTP v1's single-message endpoint is used with bounded concurrency 20;
  no unsupported multicast endpoint is invented.
- Completed deliveries/events are retained 30 days; terminal failures are kept
  90 days. `private.cleanup_notification_v2` deletes bounded batches.
- `notification_v2_metrics()` reports queue depth, oldest pending event,
  recipients, batches, retries, terminal work, and invalid-token counts. Worker
  logs contain structured counts only, never tokens, credentials, or message
  bodies.

## Scheduling and rollout

Deploying is deliberately not part of this change. In staging:

1. Apply the migration.
2. Deploy `notification-worker-v2` with `FIREBASE_SERVICE_ACCOUNT` and a random
   `NOTIFICATION_WORKER_SECRET`.
3. Store the project URL, service-role authorization value, and worker secret in
   Vault. Configure Supabase Cron to POST to
   `/functions/v1/notification-worker-v2` every minute with Authorization and
   `x-worker-secret` headers. One minute is the supported standard cron cadence;
   it avoids an uncontrolled loop while keeping normal push delay bounded.
4. Schedule `select private.cleanup_notification_v2(5000)` daily.
5. Release the new app paths only after queue, FCM, Realtime, and released-binary
   smoke tests pass. Do not remove legacy triggers until v1 retirement.

This follows Supabase's documented Cron + `pg_net` scheduled Edge Function
model. Secrets belong in Vault, not migration text.

## Compatibility and complexity

| Contract | Released app | New app | Status |
| --- | --- | --- | --- |
| Notification inbox/read state | existing `notifications` | same table | preserved |
| Realtime inbox payload | existing publication/table | same table | preserved |
| Post/event generation | legacy direct triggers | v2 RPC/outbox | disjoint |
| Chat generation | legacy direct triggers | `send_message_v2`/outbox | disjoint |
| Mention generation | legacy trigger | explicit v2 audience | disjoint |
| Push-token registration | `push_devices` | same table | preserved |

For 100,000 followers, the initiating request changes from 100,000 synchronous
notification inserts plus 100,000 `pg_net` jobs to one durable enqueue. At the
default size, expansion is approximately 400 bounded recipient batches; push is
then independently bounded by claimed device batches. No runtime estimate is
asserted.

Legacy direct writes still have O(audience) synchronous fan-out for post, event,
group/club messages, and affected club activity. That debt is intentionally
retained for released-client compatibility.
