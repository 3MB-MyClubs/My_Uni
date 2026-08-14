# Feed v2 architecture and compatibility report

Date: 2026-08-12

Scope: Feed v2 architecture/request-volume optimization only. No remote
environment was changed while preparing this implementation.

## Released feed trace (before)

The released Home flow was:

`FeedScreen` -> `LazyContentLoader` -> `SupabaseContentService` -> Supabase
table/view reads -> shared in-memory registries and stores -> feed cards.

On a cold Home open, the legacy loader performed the following logical reads:

1. `app_admins` to determine whether the caller needs the unbounded moderation
   archive.
2. `clubs`, `events` (up to 500), and `club_posts` (up to 500) in parallel.
3. `club_followers` for board-member metadata.
4. `polls` in chunks of 200 post IDs, then `poll_votes` in chunks of 200 poll
   IDs. The vote response included every matching `profile_id`.
5. `club_member_counts`, `post_like_counts` in chunks of 200 post IDs, and
   `event_rsvps` with every matching attendee identity.
6. `post_views` and `post_comments` fact rows for all posts in the in-memory
   snapshot; Flutter counted both sets of rows.
7. The people directory (`profiles`, `majors`, `academic_years`), two
   `profile_follows` reads for the viewer's graph, and a further batched
   `profile_follows` read for mutual-follow suggestions.
8. Mounted liked cards could add one microtask-batched `post_likes`/profile
   preview request.

Depending on whether the 200-ID queries needed one, two, or three chunks, the
inferred cold cost was approximately 18-25 database requests before the liker
preview, or 19-26 including that first mounted-card preview. Pull-to-refresh
forced essentially the same snapshot and directory work. This is a static code
trace, not production telemetry.

The legacy Home feed had no next-page contract. It loaded a capped historical
snapshot and sorted/filtered/aggregated it in Flutter. Its transferred rows
could include 500 posts, 500 events, all clubs, and every matching RSVP, poll
vote, comment, and view fact row. Therefore request and row volume scaled with
the snapshot and historical engagement rather than the visible viewport.

### Existing behavior outside initial feed composition

- Opening comments: one targeted `post_comments` read and one Realtime channel
  for that open thread. Realtime events debounce into a targeted thread refetch.
- Opening an event: one targeted attendee/profile read. Feed startup does not
  download attendee identities.
- Like: the existing optimistic `post_likes` insert/delete, with item rollback
  on failure.
- Comment: the existing optimistic/targeted comment mutation, with item
  reconciliation and rollback behavior.
- RSVP: the existing optimistic `event_rsvps` insert/delete, with item rollback.
- Poll vote: the existing v2 poll-vote RPC and aggregate-only local update, with
  rollback. Released v1 writes continue to use the canonical tables.
- View tracking: cards retain the session-level `(content,user)` de-duplication
  and 1.2-second batched upsert. These intentional writes are excluded from the
  feed read count.
- Images: `AppNetworkImage` and the existing image cache remain unchanged;
  media GETs are not database requests.

There is no feed-wide Realtime subscription. Only an explicitly opened comment
thread subscribes. This implementation does not add another subscription.

### Existing caches retained

- `LazyContentLoader`: legacy two-minute content TTL, 30-second count TTL,
  in-flight joins, and auth-generation invalidation.
- `SupabaseReadCache`: typed TTL/in-flight request cache cleared at auth scope
  changes.
- Interaction preview, comment, view, people-directory, and image caches.
- Feed v2 adds a 60-second first-page cache through `SupabaseReadCache`; later
  pages are never cached as a substitute for pagination.

## Feed v2

The new application path is:

`FeedScreen` -> `FeedV2Controller` -> `SupabaseFeedV2Service` ->
`get_feed_page_v2(...)` -> typed `FeedPageV2`.

- RPC: `public.get_feed_page_v2`
- Page size: 25 by default; server-enforced range 1-50
- Ordering: `created_at DESC, id DESC`
- Cursor: `{ "created_at": "<timestamptz>", "id": "<uuid>" }`
- Predicate: `(created_at, id) < (cursor_created_at, cursor_id)`
- First page: one PostgREST RPC/database request
- Each next page: one PostgREST RPC/database request
- Scrolling already-loaded cards: zero database reads; intentional deduplicated
  view writes and media GETs are excluded
- Pull-to-refresh: invalidates only the short first-page cache and requests one
  replacement first page. It creates a new cursor generation, so an older
  next-page response cannot append afterward.

The first response also includes the bounded Home-only auxiliary data needed to
avoid falling back to the legacy global loader: at most 10 upcoming events, 8
people suggestions, and 3 club suggestions. Later pages do not repeat them.

PostgreSQL joins the card's club and author metadata and returns aggregate
likes, visible comments, views, RSVP totals, poll option totals, and at most one
visible liker preview. It returns only the authenticated viewer's like, RSVP,
and poll state. Viewer identity is always `auth.uid()`; the RPC has no profile
ID parameter.

The response does not contain email, liker/viewer/attendee/voter lists, or full
comment histories. Comment and attendee identity lists remain targeted detail
flows.

Wire volume is bounded by approximately 25 post DTOs plus the bounded first-page
auxiliary DTOs. No Feed v2 response row set grows with total historical
engagement. Database work for a very highly engaged visible post can still grow
with that post's fact rows while calculating exact counts; the existing join
indexes bound that work to the 25 page IDs. No denormalized counter was added.

## Security and privacy

`get_feed_page_v2` is `SECURITY INVOKER`, `STABLE`, and uses an empty fixed
`search_path`. Consequently the existing table RLS policies remain the
authorization boundary. The function additionally applies caller-side club
blocks, author blocks, active-club filtering, and followed-only filtering.

Execution is revoked from `public` and `anon` and granted only to
`authenticated`. A null `auth.uid()` is rejected. Existing table policies,
legacy F2/F3 grants, mutation RPCs, and Realtime publications are not changed.

## Database changes

Migration: `supabase/migrations/20260812123921_feed_v2_architecture.sql`

- Adds `club_posts.is_announcement` only if missing, matching the historical
  canonical schema in the isolated baseline.
- Adds `club_posts_feed_v2_order_idx` on
  `(created_at DESC, id DESC) INCLUDE (club_id)`.
- Adds `public.get_feed_page_v2(integer, timestamptz, uuid, boolean)`.
- Adds only the authenticated execute grant described above.
- Adds no view, trigger, denormalized counter, security-definer function, RLS
  policy, mutation boundary, or rate-limit change.

The fact-table join/current-user indexes already present in the production
schema were reused; no speculative duplicate indexes were added.

## Flutter changes

- Model: `lib/models/feed_v2.dart` contains explicit, typed page, cursor, card,
  poll, engagement, event, club, and person DTOs. Email is not part of the type.
- Service: `lib/services/feed_v2_service.dart` performs one RPC per page and
  owns the 60-second first-page cache.
- State: `lib/services/feed_v2_controller.dart` implements first/next loading,
  end state, initial/page errors, retry, duplicate-request suppression,
  generation-safe refresh, stable de-duplication, and targeted deletion.
- Screen: `lib/screens/feed_screen.dart` consumes Feed v2, triggers keyset
  paging near the viewport end, seeds only visible aggregate/current-user
  state, and preserves the existing cards and mutation paths.
- Existing stores accept server-composed counts/current-user state. Append
  seeding is limited to newly loaded cards so it cannot overwrite an
  interaction made on an earlier page.
- Event detail/list screens perform the attendee identity read only when the
  event is opened; RSVP totals remain aggregate-only in the feed.

## Backward compatibility

**Will the currently released app continue to work after deploying the Feed v2
changes? Yes.** The migration is additive. Released binaries do not call the
new RPC, and every legacy read, direct-write grant, F2/F3 function, table,
response shape, and Realtime payload remains in place.

| Contract | Released App | New App | Status |
| --- | --- | --- | --- |
| Existing feed reads | Existing | Legacy fallback only | Works |
| `get_feed_page_v2` | Not used | Used | Works |
| Like mutation | Existing | Existing targeted mutation | Works |
| Comment | Existing | Existing targeted flow | Works |
| RSVP | Existing | Existing targeted mutation | Works |
| Poll vote | v1 | v2 | Works |
| Check-in | v1 | v2 | Works |
| Feed Realtime | Existing | No feed-wide reload; targeted comment thread | Works |

The new screen can still render an already-hydrated legacy snapshot while its
first v2 request is unavailable, but normal new-client operation uses Feed v2.
This fallback does not change or replace the released-client contract.

## Interoperability

- Legacy-created posts and polls live in `club_posts`/`polls` and render through
  Feed v2.
- V2-created polls and votes use the same `polls`/`poll_votes` records and remain
  visible to legacy reads.
- Released and v2 post/event creation paths continue writing the same
  `club_posts` and `events` tables.
- RSVP and F2 check-in v1/v2 paths retain their existing canonical
  `event_rsvps` and `event_checkins` data and grants. Feed v2 reads RSVP counts
  but does not need or alter check-in data.

## Verification

Database contract coverage is in `supabase/tests/07_feed_v2.test.sql` and uses
the repository migration baseline. The former disposable production-shaped
fixture is retained only under `supabase/legacy_migrations/test_fixtures/` for
historical review; current pgTAP suites create test data only.

The 35-assertion pgTAP test covers the RPC/grants, first/second/final/empty pages, equal
timestamps, insert/delete during paging, no duplicates/skips, followed-only and
block visibility, all requested aggregates and viewer state, privacy, poll
v1/v2 interoperability, and preservation of poll/check-in compatibility
grants. Flutter tests cover the DTO plus paging, duplicate request suppression,
refresh generation reset, stale response rejection, targeted deletion, and
page retry.

## Before -> after (inferred from code paths)

| Measure | Released feed | Feed v2 |
| --- | --- | --- |
| Cold first-page DB requests | ~18-25; ~19-26 with first liker-preview batch | 1 |
| Pull-to-refresh DB requests | Comparable to cold legacy snapshot | 1 |
| Next page | No page contract | 1 |
| Already-loaded scroll reads | Possible mounted-card preview batch | 0 |
| Post page size | Up to 500 | 25 (1-50 enforced) |
| Engagement transfer | Matching RSVP/vote/comment/view fact rows | Aggregate scalars and current viewer only |
| Growth characteristic | Snapshot/history-sized | `O(page size)` on the wire |

This implies a substantial egress reduction for a populated installation, but
no byte or latency percentage is claimed without production telemetry.

## Production plan verification

Status: **Needs verification**. No production `EXPLAIN (ANALYZE, BUFFERS)` was
run because this change was not deployed. Run both the first-page and cursor
cases against staging with a representative authenticated viewer:

```sql
begin;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '<VISIBLE_AUTH_USER_UUID>',
  true
);

explain (analyze, buffers, verbose, settings)
select public.get_feed_page_v2(25, null, null, false);

explain (analyze, buffers, verbose, settings)
select public.get_feed_page_v2(
  25,
  '<FIRST_PAGE_NEXT_CURSOR_TIMESTAMP>'::timestamptz,
  '<FIRST_PAGE_NEXT_CURSOR_UUID>'::uuid,
  false
);
rollback;
```

Because PostgreSQL reports a PL/pgSQL call as a top-level `Result`, also inspect
the nested statements through staging `auto_explain`/query telemetry. At a
minimum, verify that the ordered post candidate path uses
`club_posts_feed_v2_order_idx`, that page-local aggregate joins use their
existing `post_id`/`poll_id`/`event_id` indexes, and that neither page performs
a sequential scan of the complete historical fact tables.

## Remaining risks

- Apply to staging and run the production-shaped query plans above with realistic
  high-engagement posts.
- Smoke-test the currently released binary against staging after applying the
  additive migration, particularly feed, poll v1, RSVP, and check-in v1.
- Smoke-test the new binary's offline/error/refresh behavior and event detail
  attendee loading on a physical device.
- Capture production request, payload-byte, RPC-latency, cache-hit, and rows-read
  telemetry before claiming a measured egress or latency percentage.
- Repair the pre-existing migration baseline ordering separately; it was not
  broadened into this Feed v2 phase.
