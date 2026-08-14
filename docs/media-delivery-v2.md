# Media Delivery v2 / Egress Optimization

This document is a code trace of the local implementation. Nothing in this
phase deploys or changes a remote Supabase project.

## Current behavior before this phase

| Surface | Upload and canonical reference | Delivery before v2 | Main issue |
|---|---|---|---|
| Feed post | Picker output is cropped/re-encoded once at JPEG quality 95, max 3840 px; bytes are uploaded to public `post-images/club_posts/<club>/<post>/cover.jpg`; DB retains both `image_path` and the compatible public `image_url`. | Feed v2 returns `coalesce(image_url,image_path)`. `AppNetworkImage` downloaded that public object and only downsampled the decode. | Each visible photo card transferred the canonical object, commonly up to 3840 px. |
| Event | Same 3840 px / quality 95 canonical-client-output contract; public `event-images/events/<club>/<event>/<revision>.jpg`; DB path + public URL. | Event cards and detail downloaded the same canonical object; decode width was bounded locally. | Card/detail transfer size was not responsive. |
| User avatar | Cropper output is JPEG quality 95, max 1024 px; public `avatars/<auth-user>/avatar.jpg`; versioned public URL in `profiles.avatar_url`. | A 40–92 logical-pixel avatar downloaded the canonical object, then `ResizeImage` reduced decode memory. | Transfer was much larger than the slot; stable object replacement required revision-aware identity. |
| Club/group avatar | JPEG quality 95, max 1024 px. Club objects are immutable `club-avatars/clubs/<club>/<uuid>.jpg`; group photo is `group-chat-photos/<group>/avatar.jpg` with a revision query. | Canonical public image downloaded for tiny list icons. | Transfer was not responsive. |
| Chat image | Picker currently selects at max 2048 px and quality 88, making that selected output the established canonical chat upload. The unchanged selected file is staged per account, then uploaded to private `chat-attachments/<auth-user>/<message>.<ext>`; DB payload stores `chat-attachment://<path>`. | Chat v2 eagerly generated a one-hour signed original URL for every image in a fetched 40-message page. The bubble downloaded it when built, decoded around 320 logical px, and fullscreen reused the same original URL. | Eager signing, original transfer for thumbnails, signed URL rotation, and full-resolution decode/download for normal fullscreen. |
| Chat video | Selected file was limited to 10 MB and staged unchanged. Picker, preview and player accepted video, but the bucket MIME list and outbox explicitly rejected it. Inline players initialized as soon as a row was built. | Contract was internally inconsistent; list rendering could start network video work. | Permanent failures for an advertised feature and avoidable preview traffic. |
| Notifications | Notification rows use `AppNetworkImage` at about 140 logical px when an image is present; push payload architecture is unchanged. | Canonical public object was downloaded and decode-sized. | Small notification artwork used the canonical transfer. |
| Fullscreen/detail | Profile viewer, post pinch zoom, event hero, and chat dialog reused canonical URLs. | Originals were generally fetched even when a screen-sized copy was enough. | Excess egress and decode cost. |

The public Feed v2 RPC page size is 25. It performs one feed RPC, not per-image
URL RPCs. A page with 25 image posts can therefore cause up to 25 post-image
downloads as rows enter Flutter's lazy `SliverList`, plus distinct visible club
logos/avatars and the separate upcoming-event content. Before this phase those
downloads were canonical objects. No byte total is asserted because the repo
has no source-dimension or network-byte telemetry.

## Original-quality guarantee

**Are original user photos still stored at their original uploaded quality and resolution? Yes.**

“Original” here means the canonical file produced by each already-established
client upload workflow. This phase does not alter picker/cropper settings,
re-encode an upload, replace a canonical object with a rendition, or rewrite a
historical object. Post/event/avatar workflows already intentionally create a
single product-canonical JPEG (95 quality, with the existing 3840/1024 bounds);
chat already creates its established 2048/88 selected output. The Storage
upload code still sends those bytes to the same canonical path and the DB still
stores the same old-client-compatible reference. Delivery transformations are
separate, on-demand responses only.

## Media Delivery v2

- Renditions: thumbnail (768 physical-pixel cap, sufficient for 200–256 dp chat/grid previews on 3× displays), feed/card (1600), screen/detail (2500), and untouched original.
- Selection: measured logical width/height × device pixel ratio, with DPR bounded to 1–3 and each surface cap applied. When source metadata is available, dimensions are clamped to it to prevent upscaling. Historical records without metadata use the safe existing reference/fallback.
- Quality: Supabase transform quality 92, original format, aspect-ratio-preserving `contain`. Canonical originals are never transformed in place.
- Public URL strategy: transformed public URLs are derived locally with the installed Supabase Dart API; there is no DB/Edge signing request. Existing `v=` replacement revisions are retained.
- Private strategy: chat signs per account + bucket/path + rendition + dimensions for one hour, refreshes two minutes before expiry, and deduplicates concurrent resolutions.
- Cache identity: stable object/rendition identity excludes rotating tokens, includes the authenticated account for private objects, and includes replacement revision for mutable public paths.
- Lazy loading: Flutter `SliverList` remains responsible for bounded row construction. Chat v2 now keeps canonical private references and signs only when an image row is built. Videos remain uninitialized until tapped in conversation rows.
- Decode: `AppNetworkImage`, avatar `ResizeImage`, and local-file `cacheWidth` continue decoding near physical display dimensions.
- Cache bounds: the existing `DefaultCacheManager` remains the only disk cache; its installed configuration expires unused objects after 30 days and bounds the cache to 200 objects. Flutter's memory image cache remains shared rather than duplicated.
- Failure: a failed public transform renders the authorized canonical public URL once; private signing failure renders the existing placeholder, without a retry loop. Normal chat fullscreen asks for a screen rendition and falls back to its already-authorized thumbnail.
- Instrumentation: in-memory counters expose public rendition resolutions, signing requests, signing cache hits, in-flight hits, and explicit original requests. Staging should export equivalent counters plus HTTP latency/bytes to the production telemetry system.

Supabase's current documentation says image transformations require Pro or
above and must be enabled under Storage settings. The installed Dart client
supports `TransformOptions` for public and signed URLs. This must be verified in
staging; the implementation's public fallback prevents a broken image if a
transform request is unavailable. No plan or dashboard setting was changed.

## Before → after

- Feed: 25 image posts previously meant up to 25 canonical-image downloads as all cards were built. It now means up to 25 feed-sized transform downloads; originals are not requested by initial feed rendering. Pagination is unchanged.
- Avatars: 40–92 px logical slots previously transferred the canonical 1024 px object. They now request measured thumbnail renditions; tapping requests a screen rendition.
- Post/event detail: previously transferred canonical objects. They now request screen renditions (up to 2500 physical px), while cards request feed renditions.
- Chat: a 40-message page previously signed every image original. It now performs no image signing during hydration; a visible image bubble signs/downloads a thumbnail, normal fullscreen signs/downloads a screen rendition, and simultaneous identical requests coalesce. Video rows do not initialize until tapped.

**Can the application still retrieve the untouched original image when required? Yes.**

`MediaRendition.original` returns/signs the canonical object with no transform.
The canonical DB values and Storage objects are unchanged. No current UI offers
a separate “download original” control, but the delivery API supports it.

## Backward compatibility

**Will currently released clients continue rendering existing and newly uploaded media after Media Delivery v2 is deployed? Yes.**

Existing columns, public URLs, private `chat-attachment://` references, buckets,
paths, and authorization policies remain intact. New clients derive delivery
URLs at render time; old clients continue using the canonical references.

## Storage and database impact

- Originals remain unchanged; historical media works through URL parsing and canonical fallback.
- Image renditions are on-demand Supabase responses. No persisted derivative objects or additional application Storage objects are created.
- No tables, columns, policies, RPCs, or functions are added.
- One migration expands the existing private chat bucket's allowed MIME list to match its already-present 10 MB video picker/uploader/player contract. Authorization policies are unchanged.
- The Transactional/Storage v2 cleanup queue still owns post/event canonical deletion; on-demand renditions never become authoritative references.

## Expected egress impact and measurement

Egress should fall because small/card surfaces transfer bounded renditions,
signed URL rotation no longer changes disk identity, chat does not hydrate
original URLs eagerly, and video rows do no network initialization before tap.
Storage usage should not materially fall because originals are deliberately
preserved. No percentage is claimed.

In staging, record Storage/CDN response bytes and source/decoded dimensions by
bucket + rendition; signing and transform request counts/latency; stable-cache
hits/misses; first-image latency; and original-request frequency. Compare the
same scripted 25-image feed, profile, event/post detail, and 40-message chat run
before and after, then inspect Supabase cached/origin egress dashboards.

## Verification and remaining risks

Automated coverage proves physical-pixel sizing/caps, known-source no-upscale,
canonical-original URL preservation, historical reference parsing, token-stable
and rendition-distinct keys, concurrent signing deduplication, expiry refresh,
account isolation/clear, Chat v2 auth-boundary persistence, staged-file account
cleanup, and permanent-vs-retryable upload classification. Targeted analyzer is
clean. The repository-wide analyzer currently includes generated Firebase
SourcePackages under `build/` and reports unrelated third-party example/test
errors; targeted project analysis is the meaningful result.

Still required before deployment: confirm image transformations are enabled on
the project's paid plan; run real-device Retina/high-DPI visual comparisons;
smoke-test released binaries against the migration; verify private transformed
chat authorization; measure transform latency/cache behavior/egress; and decide
whether server-generated video posters are worth a later phase. Historical
records do not carry source dimensions, so strict no-upscale selection is
provable only where dimensions are known; the original fallback remains safe.

**MEDIA DELIVERY V2 CODE APPROVED — DEPLOYMENT REQUIRES STAGING VERIFICATION**
