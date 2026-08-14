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
`create_club_event_v2`. Chat uses `send_message_v2`. Each RPC performs its
rate-limit charge and canonical business insert in one transaction; the insert
then fires the same database notification trigger used by released clients.
The transaction-local `app.notification_pipeline = v2` marker is retained only
for compatibility. It no longer suppresses notification triggers, and the
legacy outbox helper is a no-op inside marked v2 transactions.

Post, event, direct-message, group-message, club-channel, club-inbox,
follow, like, comment, and RSVP notifications are written synchronously by
`AFTER INSERT` triggers. Each canonical row keeps the default
`pipeline_version = 1`, so the existing per-row `pg_net` push trigger dispatches
it immediately. The outbox tables remain as dormant rollback infrastructure;
new v2 writes do not depend on them.

## Durable pipeline

- `notification_outbox_v2`: logical event, audience, stable `event_key`, cursor,
  attempts, next attempt, lease, terminal error, recipient/batch counters.
- `notification_recipients_v2`: unique `(outbox_id, recipient_id)` mapping to the
  existing canonical notification row.
- `notification_deliveries_v2`: unique `(outbox_id, device_id)` state with
  independent attempts, lease, provider result, and terminal state.
- The schema and worker RPCs are retained for rollback and historical data, but
  marked v2 transactions do not enqueue new rows.
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
- `notification_v2_metrics()` remains available for inspecting historical outbox
  rows. New notification delivery does not require a worker or cron job.

## Scheduling and rollout

Deploying is deliberately not part of this change. In staging:

1. Apply the migration.
2. Store `notification_push_url` and `notification_push_anon_key` in Vault so
   the notification insert trigger can enqueue the `send-push` request.
3. Do not schedule `notification-worker-v2`; the migration removes the known
   worker job because notification delivery is trigger-based.
4. Release the new app paths only after notification, FCM, Realtime, and released-binary
   smoke tests pass. Do not remove legacy triggers until v1 retirement.

Secrets belong in Vault, not migration text. The database trigger remains
asynchronous at the network boundary because `pg_net` queues the Edge Function
request after the notification row is inserted.

## Compatibility and complexity

| Contract | Released app | New app | Status |
| --- | --- | --- | --- |
| Notification inbox/read state | existing `notifications` | same table | preserved |
| Realtime inbox payload | existing publication/table | same table | preserved |
| Post/event generation | database triggers | v2 RPC/database triggers | same path |
| Chat generation | database triggers | `send_message_v2`/database triggers | same path |
| Mention generation | database trigger | database trigger | same path |
| Push-token registration | `push_devices` | same table | preserved |

For 100,000 followers, the initiating request still performs O(audience)
notification inserts and queues one `pg_net` request per notification. This is
the intentional trade-off for immediate, trigger-based delivery and avoids a
per-second or per-minute scheduler.
