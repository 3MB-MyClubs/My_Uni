# Design QA

- Source visual truth: user-provided Instagram mobile-feed screenshot in the conversation (600 x 1324 px).
- Implementation screenshot: `/tmp/clubup-feed-edge-to-edge.png` (1290 x 2796 px).
- Intended viewport: iPhone mobile feed, portrait.
- State: Home feed with a photo post.
- Density normalization: not possible; the implementation capture showed the iOS Home Screen rather than ClubUp's authenticated Home feed.

## Full-view comparison evidence

The source clearly establishes an edge-to-edge, square-corner post image with padded controls above and below. The implementation could not be visually compared in the same authenticated feed state because the running simulator was on the iOS Home Screen.

## Focused region comparison evidence

Blocked for the same reason. Code inspection confirms that the post media now expands from the card's padded width to `MediaQuery.sizeOf(context).width`, is centered in an `OverflowBox`, and no longer has the previous 16 px clipping radius.

## Findings

- [P2] Rendered authenticated feed evidence is unavailable.
  - Location: Home feed photo post.
  - Evidence: source shows viewport-flush media; simulator capture did not show the app.
  - Impact: exact safe-area/device rendering cannot be visually signed off.
  - Fix: cold-launch ClubUp, enter the Home feed, capture a photo post at the same viewport, and compare it with the reference.

## Fidelity surfaces

- Fonts and typography: intentionally unchanged; the request concerns media alignment only.
- Spacing and layout rhythm: code now uses full viewport width for post media and retains padded header/actions/caption.
- Colors and visual tokens: intentionally unchanged.
- Image quality and asset fidelity: existing uploaded media and `BoxFit.cover` behavior are preserved.
- Copy and content: intentionally unchanged.

## Comparison history

- Initial finding: post media had 14 px horizontal card insets and 16 px rounded corners.
- Fix made: media now overflows the padded card to the full viewport width with square corners.
- Post-fix visual evidence: blocked because the simulator was not displaying the authenticated feed.

## Implementation checklist

- [x] Remove horizontal media inset.
- [x] Remove rounded media corners.
- [x] Preserve padded surrounding controls and caption.
- [x] Pass static analysis.
- [ ] Capture the authenticated feed for final visual comparison.

final result: blocked
