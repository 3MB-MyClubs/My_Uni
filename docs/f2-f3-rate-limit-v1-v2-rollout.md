# F2/F3 and rate-limit v1/v2 rollout

Status: implementation prepared locally on 2026-08-12. Nothing in this change
set has been deployed.

## Protocol boundary

```text
Released app -> existing direct PostgREST / legacy auth Edge Functions -> v1
New app      -> F2/F3 v2 RPCs / v2 auth Edge Functions                -> v2
Both F2/F3 generations -> the same event_checkins, polls, poll_votes rows
```

The deployed F2/F3 hardening already accepts the released request shapes. Its
`bind_event_checkin_actor` and `bind_and_validate_poll_vote` triggers replace
legacy identity fields with `auth.uid()`, and RLS still authorizes the actor.
Consequently, no corrective F2/F3 rollback or compatibility migration is
required. The v2 migration is additive.

## Released contracts (v1)

### Event check-ins

| Operation | Transport | Exact released request |
| --- | --- | --- |
| Check in | Direct `POST /rest/v1/event_checkins` | `{event_id, profile_id, checked_in_by, method}`; `method` is `manual` or `qr` |
| Remove/correct | Direct `DELETE /rest/v1/event_checkins` | filters `event_id=eq.<uuid>&profile_id=eq.<uuid>` |
| Lookup | Direct PostgREST select | `event_checkins.select(profile_id).eq(event_id, ...)` |
| Batched counts | Direct PostgREST select | `event_checkins.select(event_id).in(event_id, ...)` |
| QR/scanner | Same check-in mutation | scanner passes `method: qr`; there is no separate QR backend endpoint |

The released insert includes `checked_in_by`. It remains accepted for protocol
compatibility but is untrusted: the database trigger overwrites it with
`auth.uid()` before constraints/RLS are checked. Manager and platform-admin
authorization remains server-side. Direct legacy deletion remains restricted
by the event-manager RLS policy.

### Feed polls

| Operation | Transport | Exact released request |
| --- | --- | --- |
| Create parent post | Direct `POST /rest/v1/club_posts` | existing post payload |
| Create poll | Direct `POST /rest/v1/polls` | `{post_id, question, options}` |
| Vote | Direct PostgREST upsert to `poll_votes` | `{poll_id, profile_id, option_index}`, conflict target `poll_id,profile_id` |
| Change vote | Same upsert | same payload with a new `option_index` |
| Delete vote | Not exposed by the released feed-poll product | no released request contract |
| Poll read | Direct PostgREST select | `polls` by `post_id` |
| Vote/results read | Direct PostgREST select | `poll_votes(profile_id, option_index)` by `poll_id` |

The legacy `profile_id` remains accepted but is untrusted: the vote trigger
sets it to `auth.uid()` and checks the option index against the canonical poll.
The unique key `(poll_id, profile_id)` continues to make the legacy upsert work.
Channel/chat polls use `club_channel_poll_votes` and are a separate feature;
they were not folded into F3 or refactored here.

## Rate-limit contract inventory

The repository currently uses these transports. "Existing" means no v2
mutation was introduced in this focused rollout; the pending limiter migration
does not attach a global/table-wide trigger to it.

| Logical area | Existing transport and contract | This rollout |
| --- | --- | --- |
| Posts | direct writes to `club_posts` | unchanged; only attached poll creation moves to `create_poll_v2` |
| Comments | direct writes to `post_comments` | unchanged |
| Likes | direct writes to `post_likes` | unchanged |
| Profile/club follows | direct writes to `profile_follows`, `club_followers` | unchanged |
| Events/RSVP | direct writes to `events`, `event_rsvps` | unchanged |
| Event check-ins | direct `event_checkins` v1; v2 RPCs below | v2 rate-limited |
| Feed polls | direct `polls`/`poll_votes` v1; v2 RPCs below | v2 rate-limited |
| Messages | direct writes to `direct_messages`, `group_messages`, `club_channel_messages`, `club_inbox_messages` | unchanged; no chat refactor |
| Group membership | direct writes to `group_chats`, `group_chat_members` | unchanged |
| Moderation/blocking | direct writes to `moderation_reports`, `user_blocks`, `club_blocks` | unchanged |
| Uploads | Storage requests to `avatars`, `club-avatars`, `post-images`, `event-images`, `group-chat-photos`, `chat-attachments` | existing MIME/size controls retained; no upload broker added |
| Search | ordinary PostgREST reads plus client-side filtering | unchanged; no generic read/request limit |
| Notifications | notifications are downstream of initiating writes; `send-push` is an Edge Function used by the delivery path | initiating F2/F3 action counts once; fan-out is not charged per recipient |
| Authentication | `send/verify/complete-signup` and password-reset Edge Functions; parallel `*-v2` Edge Functions | v1 and v2 use the same per-action IP and IP+normalized-email buckets; v1 preserves legacy response shapes, v2 returns structured 429 metadata |

The limiter supports burst and sustained token buckets, atomic row locking,
per-actor and actor+resource scopes, hashed scope storage, bounded cleanup, and
separate privileged ceilings. It intentionally has no "all Supabase requests"
bucket and no table-wide mutation triggers.

## V2 F2/F3 APIs

All functions are `SECURITY INVOKER`, have an empty `search_path`, are executable
only by `authenticated`, and continue through canonical table grants, RLS,
constraints, foreign keys, and identity-binding triggers.

| RPC | Client parameters | Server identity and authorization | Rate scopes |
| --- | --- | --- | --- |
| `check_in_event_v2(uuid, uuid, text)` | event, target profile, method | actor is `auth.uid()`; event manager/linked board member/platform admin only | actor + actor/event |
| `remove_event_checkin_v2(uuid, uuid)` | event, target profile | actor is `auth.uid()`; same manager/admin rule | actor + actor/event |
| `create_poll_v2(uuid, text, jsonb)` | post, question, options | actor is `auth.uid()`; must manage the post's club or be platform admin | actor + actor/post |
| `vote_poll_v2(uuid, integer)` | poll, option index | voter is `auth.uid()`; validates visible poll and index; upserts only caller's unique vote | actor + actor/poll |
| `remove_poll_vote_v2(uuid)` | poll | voter is `auth.uid()`; deletes only caller's vote | actor + actor/poll |

Poll v2 also validates 2–10 non-empty string options, a 200-character option
limit, case-insensitive uniqueness, and a 1–500-character question. Check-in
duplicates are idempotent and retain one canonical `(event_id, profile_id)` row.

The Flutter services call these RPCs directly and never retry through v1 after
an authorization or rate-limit failure. Poll publication deletes its just-made
parent post as compensation if `create_poll_v2` fails, then propagates the v2
error; it does not create a local-only poll that other clients cannot see.

## Compatibility and security assessment

| Feature | Old App | New App | Status |
| --- | --- | --- | --- |
| Event check-in | v1 direct insert | `check_in_event_v2` | Works (old contract + isolated v2 DB test) |
| Check-in removal | v1 filtered delete | `remove_event_checkin_v2` | Works (old contract + isolated v2 DB test) |
| Poll creation | v1 direct insert | `create_poll_v2` | Works (old contract + isolated v2 DB test) |
| Poll vote/change | v1 direct upsert | `vote_poll_v2` | Works (old contract + isolated v2 DB test) |
| Vote delete | not supported in released UI | `remove_poll_vote_v2` API available | Old: Works as designed; New API: Works in isolated DB test |
| Post creation | existing direct write | existing direct write; poll child uses v2 | Works; post itself was not migrated |
| Comment | existing direct write | existing direct write | Works; not migrated |
| Message | existing direct write | existing direct write | Works; not migrated |
| Upload | existing Storage request | existing Storage request and bucket constraints | Works; no v2 broker in this task |
| Search | existing reads/local filter | existing reads/local filter | Works; no v2 endpoint needed yet |

"Works" above means the old code/request contract is unchanged and the live RLS
shape was inspected, or that the v2 path passed the isolated local database
suite. The repository still cannot clean-reset as-is because its migrations
assume a pre-existing baseline (`001_post_comments.sql` references `profiles`).
For verification only, a disposable Supabase instance used a minimal
production-shaped baseline and applied the exact F2/F3, limiter, and v2 migration
files unchanged. All 68 pgTAP assertions passed. No production or staging
deployment was performed, so post-deployment smoke testing remains required.

### Legacy risk temporarily retained

- Direct authenticated table mutation remains available for v1 F2/F3.
- Equivalent v1 check-in and poll mutations have no new action rate limit.
- A malicious caller can bypass v2 F2/F3 rate limits and stricter v2 poll-text
  validation by calling the still-supported direct v1 tables.
- Caller-supplied `checked_in_by` and feed-poll `profile_id` are **not** trusted:
  the live triggers derive them from `auth.uid()`. Existing RLS still prevents
  cross-user vote mutation and unauthorized check-in/poll creation.
- No spoofable app-version header is used. With the same authenticated role and
  direct grants serving both app generations, the server cannot distinguish a
  released binary from a custom caller. Complete bypass prevention is therefore
  impossible during this compatibility window.
- Authentication is different: v1/v2 auth endpoints share the same action
  buckets, so alternating endpoint versions does not obtain a fresh auth quota.
  Legacy endpoints suppress a limited send or return their established
  invalid/unverified shape instead of introducing an HTTP 429 contract.

This means the v2 limiter is meaningful for conforming new clients and protects
the v2 transaction boundary, but it is not complete application-wide abuse
protection while equivalent v1 direct mutations remain callable.

## Tests

- `test/f2_f3_protocol_contract_test.dart` generates and asserts the exact
  released PostgREST payloads/filters and confirms new Flutter source uses only
  the five F2/F3 v2 RPCs.
- `test/auth_protocol_contract_test.dart` confirms legacy auth functions do not
  introduce 429 responses and new auth uses only versioned Edge Functions.
- `supabase/tests/02_checkins_and_polls_rls.test.sql` covers canonical legacy
  identity rebinding and RLS.
- `supabase/tests/04_rate_limits.test.sql` covers normal/burst/sustained usage,
  user isolation, authenticated server-derived identity, privileged ceilings,
  scope hashing, cleanup, and RPC grants.
- `supabase/tests/06_f2_f3_v2_rollout.test.sql` covers exact v1 contracts, v2
  manager/unrelated/admin cases, identity forgery resistance, duplicates,
  valid/invalid poll mutations, own-vote deletion, interoperability, limiter
  consumption, grants, and the absence of v1 rate triggers.
- `supabase/tests/rate_limits_concurrency.test.ts` sends 40 parallel requests
  and verifies only the configured capacity succeeds.

## Deployment sequence (not performed)

1. Reconcile the local/remote migration history and repair the clean-reset
   ordering problem before treating local pgTAP as a release gate.
2. Confirm no F2/F3 corrective migration is needed by replaying the released
   contract probes against staging.
3. Apply `20260812105930_application_rate_limits.sql`; it installs shared
   infrastructure and bucket/storage constraints but no table-wide triggers.
4. Apply `20260812121348_create_v2_checkins_and_polls.sql`.
5. Deploy both legacy and v2 auth Edge Functions together so they share action
   buckets while retaining their separate response contracts.
6. Smoke-test the released check-in/removal/poll create/vote payloads.
7. Run pgTAP plus concurrent limiter tests and smoke-test every v2 RPC/429.
8. Release the Flutter build that uses v2, then observe errors, 429 rates, and
   adoption. Do not add v1 fallback.
9. Retire v1 in a later explicit security migration only after the minimum
   supported app version advances.

## Future retirement

`TEMPORARY V1 COMPATIBILITY` code/comments mark legacy Edge behavior. The later
retirement migration must remove legacy auth Edge Functions/state, revoke direct
`INSERT/UPDATE/DELETE` grants for `event_checkins`, `polls`, and `poll_votes`,
and remove policies needed only by direct v1 mutations. Because current v2 RPCs
are security-invoker functions, that retirement must first give v2 a narrowly
audited server-side execution boundary (or equivalent unspoofable gateway) so
revoking direct table writes does not also break v2. It must then close the
legacy rate-limit exemptions. None of those retirement actions belong in this
rollout.
