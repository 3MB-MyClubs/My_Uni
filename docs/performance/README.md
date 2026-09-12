# ClubUp performance implementation and validation

## What changed

- Added opt-in bounded metrics for startup stages, API duration/body bytes/errors, read-cache reuse, page reads, chat reconciliation, and frame budget counters. Enable with `--dart-define=CLUBUP_PERFORMANCE=true` (profile mode enables these by default). `performanceMetrics.exportJson()` exports at most 256 recent samples and cumulative counters. No URLs, search terms, bodies, credentials, or account identifiers are retained. Image downloads use a separate client and are **not** included in API byte totals.
- Search now uses account-scoped backend pages with Turkish/English matching, deterministic cursors, a 250 ms debounce, stale-response rejection, club counts/recent activity, and complete category facets. Student search reaches beyond the previous 100-person snapshot.
- This Week, club post/event tabs, past club events, and admin content lists use focused pages. New content pages default to 25 and cap at 50. Partial pages merge by ID without replacing the campus registry. Notification targets resolve posts/events independently of the loaded pages.
- Profile/account-context preparation reads the user's clubs instead of loading 500 posts plus 500 events. Club header totals come from aggregate reads, independently of loaded pages. Board metadata is hydrated explicitly; confirmed role removals clear old board state.
- Club member search is paged. Existing board-management and recipient workflows still receive complete membership lists through bounded 50-record requests, preserving their existing behavior.
- Previously loaded feed/content pages can render from bounded session memory. Refresh failures retain visible content. Cache invalidation, account generations, mutation guards, and signed-URL request tokens prevent stale work from repopulating cleared state.
- Startup retains auth, preferences, update and terms gates while deferring Firebase/push and package metadata until usable navigation. Feature-specific Hive readiness replaces unrelated cache barriers. The artificial minimum splash wait falls from 2 seconds to 300 ms; its transition is retained.
- Chat applies only changed history/summary revisions, reconciles the active thread first, limits remaining reconnect work to three requests, and coalesces summary refreshes with a trailing pass. The outbox and feed/chat v2 contracts remain intact. A regression test covers teardown without a delayed save timer.
- Private signed URL memory is bounded; invalidated signing requests cannot restore cleared URLs. Video playback pauses in the background. Existing image renditions and camera processing remain in use, with original media retained.
- Notification history can load older pages. The existing initial 100-row window is retained because its unread/UI semantics depend on that window.
- CI adds deterministic cache/paging/concurrency regressions and Android/iOS release compilation. Android CI uses a disposable compilation key; it produces no publishable production-signed artifact.

## Recorded local benchmark

Run on 2026-09-12, macOS 26.6.2, Flutter 3.47.0 / Dart 3.13.0, local Docker Supabase. The fixture has 10,001 synthetic student profiles and 20,000 events for one club. Queries run as an authenticated student. This is a synthetic database comparison, **not** a device latency or production p95 benchmark.

Raw output: [local-query-baseline.txt](local-query-baseline.txt). Reproduce on a disposable/local stack with [the rollback-only SQL script](../../scripts/performance-query-benchmark.sql). Do not run the benchmark on production: it temporarily drops candidate indexes inside a transaction and inserts test data before rolling everything back.

| Authenticated operation | Before candidate indexes | After candidate indexes |
| --- | ---: | ---: |
| Upcoming event page | 216.494 ms | 1.388 ms |
| Default student directory page | 80.000 ms | 0.742 ms |
| Descending club history | 186.001 ms | 219.789 ms |

The event-order and partial student-name indexes showed benefit and are included. The club-specific candidate did not improve the measured history query and is omitted. These are individual runs, not a statistical distribution; cache warming and fixture distribution affect results. Function-level EXPLAIN records total time/buffers, not every nested plan. Production-sized history plans still need investigation before adding further indexes.

A 25-event JSON page was **27,909 bytes**, versus **431,892 bytes** for the previous 500-event projection: about **93.5% less serialized event data** for that fixture. This excludes media, wire compression, and the previous loader's additional posts/metadata. It is not an app-wide traffic reduction claim.

## Verification record

- Release-gate plus startup/navigation/search/guest suite: 100 tests passed.
- Member/profile/board/RSVP regression suite: 63 tests passed; final focused follow-up: 57 passed, including preservation of known memberships during directory merges. These suites overlap; do not add their counts.
- Local database/RLS: 354 tests passed across 14 files, including 28 new paging/search tests. Coverage includes >100 students, >500 events, cursor ties and inserts/deletes, member paging, page-independent counts, blocks in both directions, and anonymous/admin restrictions.
- Migration ordering and database lint passed (the repository's existing allowlisted temporary-table lint finding remains).
- Frozen Edge Function check passed; all 6 Edge Function unit tests passed using Deno 2.5.6.
- Android release compiled in an isolated copy with a disposable key. Final web and unsigned iOS release builds compiled successfully. A transient Xcode error 74 on one repeat cleared on the diagnostic rerun.
- Final Dart analysis: no issues. All 12 performance-foundation behavior tests passed, including bounded metrics export and preservation of directory membership data.
- The full Flutter suite is **not green**: the committed baseline (`209b0c1`) itself produced 55 failing cases and stalled during teardown. A separate temporary baseline copy established the comparison. The initial working run added chat reset timer failures; those were fixed and the affected navigation/event/admin tests now pass. Full-suite runs were stopped after stalled teardown; they are not counted as successful full-suite runs.
- No physical Android or iPhone was connected. A simulator cannot establish the requested mobile targets. The additive hosted migration has since been deployed and verified; see [deployment evidence](deployment-preflight.md). No client publication, physical-device p95 test, or 20-minute device soak has been performed.

## Release validation still required

Use physical Android and iPhone devices, profile mode for diagnosis and release builds for user-facing timings, following [Flutter profiling](https://docs.flutter.dev/perf/ui-performance). Record build SHA, device/model, OS, refresh rate, dataset size, account role, battery/thermal state, and measured network latency/bandwidth/loss. Use identical conditions for the pre-change build and candidate. Report normal and slower networks separately.

For each workflow, run a cold visit and at least 30 revisits: launch/login; every main tab; student/club search and filters; profiles; old post/event links; RSVP; comments; notifications; DMs, group and club chat; capture/upload; club board/admin moderation. Capture tap/pending latency, first visible content, usable navigation, request count, response bytes, cache hits and frame misses. Reset/export metrics between workflows so the bounded sample ring does not obscure a long run. Use DevTools Network for image bytes/decode dimensions and Memory for retained controllers; API counters do not measure those.

| Engineering target | Acceptance |
| --- | --- |
| Tap feedback/pending | <=100 ms |
| Previously loaded tab usable | <=200 ms without waiting for network |
| Cold launch to usable navigation | p95 <=2.5 s |
| First feed/chat content after opening | p95 <=1.5 s |
| Frames over display budget | <1% |
| Targeted broad-loading traffic | >=30% reduction vs comparable baseline |

For the 20-minute soak, repeat navigation, searches, long chat scrolling, reconnect/offline recovery, video playback and camera capture/upload. Background/resume every few minutes. Compare memory after garbage collection at minutes 0/5/10/15/20; record active controllers, signed URL/cache sizes, subscriptions and background request counts. Verify original files retain their dimensions/quality, private media remains restricted, blocked/deleted content stays hidden, and account switches never flash protected prior-account data.

Some legacy attendee, picker, analytics and moderation flows still need complete collections for current UI semantics. Their full conversion to visible-only loading and narrower widget subscriptions should be driven by the device traces and covered with feature-specific regressions. The changes above do not constitute a completed profile of every app workflow.

## Deployment and rollback

**Status:** the single additive migration is deployed to MyClubs. Existing API/security fingerprints are unchanged and live read-only smoke checks passed. See [the verification record](deployment-verification.json). Client publication and physical-device validation remain separate.

1. Run the clean-reset database and generated-type checks in CI; local tests above used the existing local stack without resetting its data.
2. Apply `20260911154857_app_performance_pages_v1.sql` to staging, then production **before** shipping dependent clients. Verify directory, facets, content, member and count RPCs using authenticated student/club/admin roles. Existing feed/chat v2 functions are unchanged.
3. Complete device/release validation, compare phase results, then release the client gradually. These pages require the additive migration; a client released first will show loading errors.
4. Roll back the client if needed. Keep the additive RPCs and existing v2 contracts for installed clients; do not drop them as a client rollback step. Original storage objects are unchanged.
