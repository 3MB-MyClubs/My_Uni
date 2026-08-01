# Design QA

- Source visual truth: user-provided notification-center reference image in the conversation (displayed at 720 x 1436 px; no local source path was exposed).
- Implementation screenshot: unavailable.
- Intended viewport: mobile portrait; responsive widget behavior exercised at Flutter's default widget-test viewport.
- Density normalization: unavailable because neither the conversation attachment nor a rendered implementation capture could be opened as a local image pair.
- State: populated notification center in light and dark themes.

## Full-view comparison evidence

The implementation follows the reference hierarchy in code: title and unread pill, mark-all-read action, collapsible follow-request strip, unread `NEW` section, chronological groups, avatar/type badges, follow buttons, content previews, and read/unread row treatment. A same-state screenshot comparison could not be completed.

## Focused region comparison evidence

Blocked. No Flutter simulator or physical device was available. The Flutter web build compiled and served locally, but the in-app browser reported no available browser backend, so it could not be opened or captured.

## Automated interaction evidence

- Home bell exists, exposes a notification semantic label and unread badge, and opens `NotificationsScreen`.
- Mark-all-read and individual-row read state pass.
- Follow-request collapse, expand, confirm, and delete pass.
- Follow, Following, and Requested accessory states pass.
- Pull-to-refresh confirmation passes.
- Light and dark theme surface assertions pass.
- Thirty-day retention behavior passes.
- `flutter analyze` passes with no issues.

## Fidelity surfaces

- Fonts and typography: source hierarchy is represented with matching heavy title/name weights, compact timestamps, and uppercase group labels; screenshot-level comparison is blocked.
- Spacing and layout rhythm: responsive row, section, header, and action spacing is implemented; screenshot-level comparison is blocked.
- Colors and visual tokens: KU burgundy, warm light surfaces, and warm near-black dark surfaces use the app's theme tokens; both theme states pass widget assertions.
- Image quality and asset fidelity: real user/club avatars and real post/event thumbnails are used when available; standard Material icons are used for notification types. Screenshot-level comparison is blocked.
- Copy and content: English and Turkish notification-center copy is generated from ARB localization files.

## Findings

- [P2] Rendered visual comparison is unavailable.
  - Location: complete notification center, light and dark states.
  - Evidence: no Flutter device was available and the in-app browser backend list was empty.
  - Impact: exact pixel fidelity, text wrapping, and device-specific safe-area rendering cannot be signed off from a rendered artifact.
  - Fix: launch the app on an iOS or Android simulator, open the Home bell, capture populated light and dark states, and compare them beside the supplied reference.

## Comparison history

- Initial implementation QA found that expanded request actions could overlap the sticky notification list in a constrained viewport.
- Fix made: expanded request rows now participate directly in sliver layout rather than animating their size under a pinned header.
- Post-fix evidence: confirm/delete hit testing and all notification widget tests pass; rendered visual evidence remains unavailable.

## Implementation checklist

- [x] Implement reference hierarchy and notification-row variants.
- [x] Connect Home bell, unread badge, realtime inbox, and read state.
- [x] Implement light and dark themes.
- [x] Test core interactions and theme states.
- [x] Pass static analysis.
- [ ] Capture and compare light and dark simulator screenshots.

final result: blocked
