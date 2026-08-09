# Club Insights Design QA

**Comparison target**

- Source visual truth: user-provided conversation attachment (`622 × 1337` px), showing the dark Club Insights screen with KUADK sample data.
- Implementation screenshot: `design-qa-club-insights-simulator.png` (`1206 × 2622` px).
- Widget-test capture: `design-qa-club-insights-implementation.png` (`393 × 852` px; Ahem test font, used only for layout regression coverage).
- Viewport: iPhone 17 simulator, `402 × 874` logical px at device pixel ratio `3.0`; focused responsive coverage also ran at `393 × 852` logical px.
- Normalization: the source is an approximately `393 × 845` mobile viewport at roughly `1.58×` density. The `393 × 852` widget capture verifies the source-width layout, while the native simulator capture verifies real fonts and icons. Native status-bar and home-indicator differences are device-owned and excluded from app-content findings.
- State: dark theme, KUADK club identity, four populated all-time metrics, five ranked posts, first row highlighted.

**Findings**

- No actionable P0, P1, or P2 differences remain.
- Fonts and typography: native system sans-serif, weights, sizes, uppercase tracking, hierarchy, truncation, and two-line metric labels match the reference closely. Text remains readable at the target viewport.
- Spacing and layout rhythm: header, 24 px content margins, two-column metric grid, 10 px gutters, rounded cards, section dividers, compact ranked rows, and progress-bar alignment match the source composition. No viewport overflow remains.
- Colors and visual tokens: warm near-black background, raised red-tinted surfaces, muted gray supporting copy, crimson semantic emphasis, subtle borders, and blue back-button outline match the reference while using the app's existing theme tokens.
- Image quality and asset fidelity: the screen contains no raster imagery. All visible symbols use Flutter's Material icon library; no custom drawn or placeholder assets are present.
- Copy and content: title, club handle, since label, all-time helpers, event/post counts, top-post qualifier, dates, ranks, views, and likes reproduce the supplied content structure. English and Turkish copy use the existing localization system.
- Interaction and accessibility: back navigation, ranked-post drill-in, return navigation, pull-to-refresh, semantic metric summaries, ellipsis behavior, and always-scrollable empty states are implemented. Native debug run produced no console errors.

**Comparison history**

- Pass 1 found a P2 narrow-screen overflow in the `TOP POSTS / all time, by views` heading at `393 × 852`.
- Fix: made the trailing qualifier flexible with one-line ellipsis behavior while retaining the central divider.
- Post-fix evidence: `design-qa-club-insights-simulator.png` shows the full header at the target width without clipping or overflow; the focused widget test and native simulator run both pass.

**Focused region comparison evidence**

- Header: centered title/identity, 44 px outlined back affordance, divider, and device-owned safe area were checked against the reference.
- Metric grid: icon tiles, numerical hierarchy, label wrapping, card radii/borders, and 2 × 2 rhythm were checked at full native density.
- Ranked posts: leader treatment, rank chips, single-line titles, dates, chevrons, proportional view bars, and view/like pairs were checked for all five sample rows.

**Implementation checklist**

- [x] Reference-matched responsive layout.
- [x] Live totals and all-time context.
- [x] Ranking by views with like/recency tie-breakers.
- [x] Post-detail navigation and return behavior.
- [x] Pull-to-refresh and empty state.
- [x] English/Turkish localization.
- [x] Focused widget test, golden layout regression, analyzer, and native simulator verification.

**Follow-up polish**

- Device-owned status time and system indicators naturally differ from the static reference and require no app change.

final result: passed
