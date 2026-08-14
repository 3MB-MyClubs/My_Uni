# Transactional Writes + Storage Lifecycle

This phase is additive. Released clients retain their direct table writes,
legacy RPCs, canonical tables, and historical Storage paths. New clients use
the transactional v2 RPCs in migration
`20260813104017_transactional_writes_storage_lifecycle.sql`.

## Confirmed pre-change write flows

- Profile save issued one `profiles` update, then three independent collection
  replacements. Each replacement was a delete followed by an optional insert.
  A normal full save therefore used 7 mutation requests, followed by a profile
  reread that expanded to 7 reads (core, three lookup tables, three joins).
  Any failure after a delete could persist only part of the intended profile.
- Post creation generated a random Storage UUID, uploaded first, called
  `create_club_post_v2`, and then called `create_poll_v2`. A failed post RPC
  orphaned the upload; a failed poll required fallible client compensation and
  could leave the post alive. Notification v2 enqueue was already atomic with
  the post insert.
- Event creation generated a random Storage UUID, uploaded first, and called
  `create_club_event_v2`. A DB failure orphaned the upload. Event replacement
  uploaded before the update (correct ordering), but failed old-object deletion
  was forgotten. Deletes removed the DB row first (correct authority) but also
  forgot failed Storage deletion.
- Chat copied picker output into a shared `chat_attachments` directory, uploaded
  it during outbox drain, and retained the local staged copy forever. All upload
  and message-row failures entered the same fixed five-second retry path.
  Logout cleared Hive references but not staged files.

## New path

- `update_profile_v2` derives the profile from `auth.uid()`, validates and
  deduplicates all relationships, locks the profile row, updates all canonical
  tables atomically, and returns the fully resolved state in one logical call.
  Concurrent saves serialize on the row; a revision column is unnecessary for
  the current single-device, explicit-save UI. Last complete save wins.
- Post/event creation reserves a UUID before upload and uses entity-bound paths.
  Creation, poll insertion, and notification-outbox enqueue share one database
  transaction and one logical action rate limit. A failed DB operation registers
  the uploaded object for delayed compensating cleanup.
- Event replacement uploads a unique entity-bound revision, atomically changes
  the canonical reference, then attempts old-object deletion. Post/event deletes
  delete canonical DB state and enqueue cleanup in the same transaction.
- `storage_cleanup_queue_v2` has bounded exponential retries and leases. The
  service-role-only worker always calls `storage_cleanup_is_referenced_v2`
  before using the Storage API, so age alone never authorizes deletion. Creation
  compensation starts with a 15-minute grace period.
- Chat staging is account-scoped. Successful durable sends and cancellations
  delete the staged file; logout removes the departing account directory; the
  seven-day sweeper preserves every path still referenced by an outbox item.
  MIME/size/auth/validation failures become terminal and are not scheduled on
  the fixed retry loop. The current 10 MiB image-only bucket contract is enforced
  client-side; broader video support remains outside this phase.

## Remaining legacy risk

Released clients can still partially save profiles, create post and poll in
separate requests, and forget Storage cleanup failures. Those paths remain open
to preserve compatibility. New canonical rows are visible to both generations;
legacy paths should be retired only after the supported-version window closes.

The cleanup worker is included but is not deployed or scheduled by this change.
