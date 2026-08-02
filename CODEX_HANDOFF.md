# Handoff: "Campus Tour" Onboarding Rebuild (replaces the old app tutorial)

You are taking over a mostly-finished rebuild of this Flutter app's first-run
tutorial. The old spotlight tutorial has been fully ripped out and replaced
with a new three-act onboarding flow. **All production code and the unit test
file are written and `flutter analyze` passes with zero issues.** What remains:
run and fix the new unit tests, write the new integration drive test, sweep
~19 old integration drivers onto the new service, delete the compat shim, and
verify end-to-end. Everything you need is below — do not reintroduce anything
from the old system.

Repo: `/Users/hakantuncay/development/Koç_University_App_Prototype`
Branch: `Hakan_Diffs`. Flutter binary: `~/flutter/bin/flutter` (not on PATH).

---

## 1. The design that was approved and implemented

A three-act "campus tour with a friendly upperclassman" replacing a terse,
forced-tap coach-mark tour. One warm first-person voice, full sentences,
bilingual EN/TR via the existing `S._t(en, tr)` pattern.

- **Act 1 — Welcome**: full-screen greeting over the app (dark base
  `#0C0608` + burgundy `#8C1D40` radial wash + white "KU" seal — visual
  language borrowed from the dead `lib/screens/signup_steps/step_done.dart`,
  which still exists and is untouched). Greets by first name
  ("Hey Ayşe! 👋"). Buttons: primary "Show me around", quiet
  "I'll explore on my own" (skip is first-class, no shame).
- **Act 2 — Tour**: soft spotlight (dimmed scrim, rounded hole, pulsing
  glow) over real UI + a bottom-docked conversational **guide card** (1–2
  sentence why-you'd-care copy, progress dots, Back/Next buttons, always-
  visible "Skip tour" pill top-right). **Both** advancement paths work:
  the Next button AND tapping the spotlit real control. Steps auto-switch
  bottom-nav tabs. Student tour: 6 stops (home feed → feed toggle → events
  RSVP → explore search → chats compose → profile). Club-admin tour: 5
  stops (quick composer → center "+" create event → chats → club profile
  tabs → club settings gear).
- **Act 3 — Finish**: "That's the tour! 🎉" + (students only) a **Starter
  Checklist** — follow a club / RSVP to an event / say hi to someone — with
  deep-link rows jumping to tabs 2/1/3. The checklist then lives as a
  dismissible card at the top of the Home feed, auto-checking items by
  observing real stores, until dismissed. Club admins get a short send-off
  instead. Replay from Settings restarts at Act 1.

Key interaction rules implemented:
- Taps outside the spotlight are swallowed with a light haptic (no punish
  shake — friendlier than the old system).
- Steps whose target opens a route/sheet/keyboard (`tapThrough: false`:
  student searchField + chatsCompose; club composer, "+" button, settings
  gear) advance on tap WITHOUT passing the tap through, so a pushed route
  never covers the tour.
- If a step's anchor never mounts (e.g. zero events → no RSVP button),
  after ~12×70ms retries the step degrades to a hole-less guide card with
  Next-only advancement (`_spotlightMissing`), never hangs.
- Calendar permission is requested after first-run finish/skip only, NOT
  after replays (`_isOnboardingReplay` in MainNavScreen).

## 2. New files (all written, analyze-clean)

All under `lib/onboarding/`:

| File | What it is |
|---|---|
| `onboarding_service.dart` | `OnboardingService` + global `onboardingService`. Prefs key `onboarding_version_<userId>` (int, `onboardingVersion = 1`). API mirrors the old TutorialService on purpose: `initialize/isComplete/complete/reset/requestReplay` + `ValueNotifier<int> replayRequests`, plus new `ValueNotifier<int?> tabRequests` and `requestTab(int)` (sets null then the value so the same tab re-fires). Empty userId or uninitialized prefs ⇒ `isComplete == true` (suppresses onboarding). |
| `onboarding_anchors.dart` | `OnboardingAnchors` GlobalKey registry + global `onboardingAnchors`, `keyFor(id)`. Ids: navHome/navEvents/navSearch/navChats/navProfile, homeFeedToggle, eventsRsvp, searchField, chatsCompose, clubCreateButton, clubQuickComposer, clubProfileTabs, clubProfileSettings. (Old ids navBar/alertsMarkAllRead/profileHeader/profileSettings/clubInsights were dropped and their key attachments removed from screens.) |
| `onboarding_steps.dart` | `OnboardingStep{String Function() guideLine, IconData icon, GlobalKey targetKey, int tabIndex, bool tapThrough}` (guideLine lazy for live locale switch; `text` getter) + `studentOnboardingSteps()` / `clubAdminOnboardingSteps()`. NOTE: `tabIndex` = the tab the step's content lives on (NOT the old system's "tab visible before tapping next"). |
| `onboarding_flow.dart` | `OnboardingFlow` — the whole state machine (`_Phase {welcome, tour, finish}`, `AnimatedSwitcher` between phases), rendered `Positioned.fill` over MainNavScreen's Scaffold. Props: steps, firstName, showChecklist, onStepChanged, onComplete, onSkip, onDeepLink. Spotlight measurement ported from the old overlay (post-frame → `targetKey.currentContext`, 12×70ms retries, `Scrollable.ensureVisible` in try/catch, RenderBox global→local, `Rect.lerp` animated hole, hit rect = raw.inflate(3), visual = raw.inflate(9)). **Tap-through**: four opaque GestureDetector blockers around the hole; over the hole a `Listener` with `HitTestBehavior.translucent` (tapThrough) or `.opaque` (not) whose `onPointerUp` calls `_advanceFromTap` (haptic, 160ms beat if tapThrough, then `_next`). No global pointerRouter. Guide card docks above the floating nav (`mediaPadding.bottom + 96`), or above the hole when the spotlight is in the bottom 260px. Card fades + `IgnorePointer` during transitions. Listens to `localeService` for live rebuild. |
| `widgets/onboarding_spotlight.dart` | `SpotlightMaskPainter` (even-odd rect + rounded hole, scrim `Colors.black.withValues(alpha: 0.62)`) and `TargetGlowPainter` (pulsing blurred ring, `AppColors.primaryRed`). |
| `widgets/onboarding_welcome_view.dart` | Act 1 view. Theme-independent (always dark+burgundy). Opaque GestureDetector root so nothing leaks through. |
| `widgets/onboarding_guide_card.dart` | The guide card: icon chip, scrollable text (max height 132, `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)`), optional tap-hint row (`S.onboardingTapHint`, only when tapThrough && spotlight found), progress dots, Back (hidden on step 0) / Next (label becomes `S.onboardingFinish` on last step). Semantics liveRegion with step label. |
| `widgets/onboarding_finish_view.dart` | Act 3 view; `showChecklist` toggles the three `_ChecklistRow`s (deep links: follow→tab 2, rsvp→tab 1, sayHi→tab 3) vs club body; primary button `S.onboardingLetsGo` → onDone. |
| `starter_checklist_service.dart` | `StarterChecklistService extends ChangeNotifier` + global `starterChecklistService`. Persists JSON at `onboarding_checklist_<userId>`: started/dismissed/followDone/rsvpDone/chatDone/baselineFollowCount/baselineRsvpCount/startedAtMillis. `startFor(userId)` loads existing record or snapshots baselines (`userState.followedClubIds.length` — **'c1' is pre-seeded**, so detection is baseline-relative; attending count over global `events` via `rsvpStore.isAttending`). Attaches listeners to `userState`, `rsvpStore`, `chatStore`; `_recheck` marks sticky done-flags (chat = any message in `chatStore.threadsFor(userId)`/`messagesFor(threadId, viewerId:)` with `senderId == userId` and `createdAt.isAfter(startedAt)`). `isActiveFor(userId)`, `dismiss()`, `allDone`. |
| `widgets/starter_checklist_card.dart` | `StarterChecklistCard` — self-hiding (`SizedBox.shrink()` when `!isActiveFor(authService.currentUser?.id)`), wraps `ListenableBuilder` on the service. Header (title/subtitle or `S.checklistAllDone`), Hide button → `dismiss()`, three items with check-circle animation, strikethrough when done, action label → `onboardingService.requestTab(2/1/3)`. |

## 3. Modified files

- `lib/main.dart` — import swap; bootstrap now has `onboardingService.initialize()` and `starterChecklistService.initialize()` in `appBootstrap.ready`'s `Future.wait`.
- `lib/screens/main_nav_screen.dart` — the big one:
  - imports: old three replaced by `onboarding_anchors/onboarding_flow/onboarding_service/onboarding_steps/starter_checklist_service`.
  - state: `_showTutorial`→`_showOnboarding`, new `_isOnboardingReplay`, `_tutorialPageController`→`_tabTransitionController` (same dim/scale tab cross-fade, kept).
  - initState: listeners on `onboardingService.replayRequests` (`_onOnboardingReplayRequested` → `_startOnboarding(isReplay: true)`) and `onboardingService.tabRequests` (`_onTabRequested` → `_selectNavIndex`). Both removed in dispose.
  - `_startInitialExperience` unchanged in logic, now checks `onboardingService.isComplete`; gate is still `(authService.isStudentSession || _isClubAdmin)`; super admin never sees it; falls through to `_requestCalendarIfNeeded()`.
  - `_finishOnboarding()`: hides overlay, `await onboardingService.complete(_currentUserId)`, `if (authService.isStudentSession) await starterChecklistService.startFor(_currentUserId)`, then `_requestCalendarIfNeeded()` only when `!_isOnboardingReplay`. Used for BOTH onComplete and onSkip.
  - `_onOnboardingStepChanged(OnboardingStep step)`: switches `_selectedIndex` to `step.tabIndex`, fires `_tabTransitionController.forward(from: 0)`, `_chatsController.showStudents()` for tab 3.
  - `_onboardingFirstName` getter: first word of `authService.currentUser?.name ?? authService.currentAdmin?.name ?? ''`.
  - The ~90-line `_tutorialSteps`/`_clubTutorialSteps` getters are GONE; build passes `_isClubAdmin ? clubAdminOnboardingSteps() : studentOnboardingSteps()`.
  - overlay slot in build(): `if (_showOnboarding) Positioned.fill(child: OnboardingFlow(... showChecklist: authService.isStudentSession, onDeepLink: _selectNavIndex))`.
  - nav-bar: `navBar` key on the ClipRRect removed; per-slot keys + center "+" key now use `onboardingAnchors`. The super-admin slot (index 5) intentionally has key `null`.
- `lib/screens/settings_screen.dart` — import swap; `_replayTutorial()` now `onboardingService.reset(_userId)` → popUntil first → `onboardingService.requestReplay()`. The two "Replay the tour" tiles kept; strings reworded.
- `lib/services/app_strings.dart` — old `tutorial*` block deleted; `replayTutorial`/`replayTutorialSubtitle` reworded ("Replay the tour" / "Take the campus tour again"); ~37 new getters added (all `onboarding*` + `checklist*`), full EN/TR. See the file, block starts right after `replayTutorialSubtitle`.
- `lib/screens/feed_screen.dart` — anchor import/keys swapped; new import of `starter_checklist_card.dart`; `const SliverToBoxAdapter(child: StarterChecklistCard())` inserted in the sliver list right after `_buildComposer()`.
- Anchor swaps (mechanical, `tutorialAnchors`→`onboardingAnchors`): `chats_screen.dart` (chatsCompose; `isTutorialHost` param KEPT), `this_week_screen.dart` (eventsRsvp; `isTutorialHost` KEPT), `explore_screen.dart` (searchField), `club_profile_screen.dart` (clubProfileTabs, clubProfileSettings; the `clubInsights` key was removed from the insights IconButton — the "singleton root" comment moved to the settings gear).
- Anchor removals: `student_profile_screen.dart` (profileSettings KeyedSubtree unwrapped), `notifications_screen.dart` (**`isTutorialHost` param deleted entirely from the widget** — no external caller passed it; verified).
- `lib/services/tutorial_service.dart` — now a **temporary 3-line shim**: exports `../onboarding/onboarding_service.dart` and defines `@Deprecated final OnboardingService tutorialService = onboardingService;`. ~19 integration drivers still compile through it. **This file must be deleted in the final sweep (step B below).**

## 4. Deleted files

`lib/widgets/app_tutorial_overlay.dart`, `lib/services/tutorial_anchors.dart`,
`test/app_tutorial_test.dart`, `integration_test/app_tutorial_drive_test.dart`.
Do not recreate them.

## 5. New unit tests (written, NOT YET RUN)

`test/onboarding_test.dart` — groups:
- `OnboardingService`: per-user complete/reset, empty-id suppression, and
  `{'app_tutorial_version_u1': 2}` must NOT satisfy the new key.
- `Onboarding copy`: `_allOnboardingCopy()` map of ~37 getters; EN vs TR must
  be non-empty and distinct for every key (switch via `localeService.setLanguage`,
  which works in-memory without Hive).
- `OnboardingFlow` widget tests via `_TourHarness` (MaterialApp > Stack of two
  IconButtons + `Positioned.fill(OnboardingFlow)` with 2 steps: step 1
  tapThrough, step 2 not): welcome greets "Ayşe" + skip fires onSkip;
  Next/Back navigation; tapAt(center of target) advances AND increments the
  real button's counter on step 1 but NOT on step 2 (opaque) which lands on
  finish; finish view checklist rows and deep link `[2]` + onComplete;
  club variant (`showChecklist: false`) hides checklist; live EN→TR swap
  mid-tour. Uses bounded pumps (`_settleFlow` = 16×150ms) because the pulse
  animation repeats forever — **never `pumpAndSettle` the tour phase**.
- `StarterChecklistService`: Hive.init(tempDir) + global `chatStore` with
  `autoRepliesEnabled = false` + `chatStore.initialize()` in setUpAll.
  Baseline-relative follow ('c1' pre-seeded ⇒ not done; `toggleFollow('c2')`
  ⇒ done; sticky on unfollow), RSVP via `rsvpStore.seed(events.first.id, true)`
  + a `userState.toggleFollowUser` nudge to trigger `_recheck` (avoids
  `rsvpStore.toggle`'s student-session requirement and notification plugins),
  chat via `chatStore.ensureDirectThread('u1','u2')!` + `sendMessage` (5ms
  delay first so `createdAt.isAfter(startedAt)` holds), dismissal + fresh-
  instance prefs round-trip.

**YOUR FIRST TASK:** `~/flutter/bin/flutter test test/onboarding_test.dart`
and fix whatever surfaces (likely candidates: pump timings around the
AnimatedSwitcher/measure retries; text finders matching both card and
semantics; the checklist test's reliance on global singleton state ordering).
Then run the FULL suite `~/flutter/bin/flutter test`. Known pre-existing
baseline failures that are NOT yours to fix: 2 tests in
`test/club_profile_smoke_test.dart` fail at baseline HEAD.

## 6. Remaining work, in order

**A. Integration drive test** — write `integration_test/onboarding_drive_test.dart`
replacing the deleted `app_tutorial_drive_test.dart`. Copy the boot pattern from
`integration_test/liquid_glass_nav_drive_test.dart` (service initializes, login
as `alice@ku.edu.tr` / student `u1`, mark theme+language chosen) but call
`onboardingService.reset('u1')` instead of complete, so the flow fires. Walk:
welcome (assert `S.onboardingWelcomeTitle` content + both buttons) → "Show me
around" → each of the 6 student stops (assert each guide line text, use a
settle helper of repeated `pump`s — pumpAndSettle will hang on the pulse
animation) advancing via Next (and at least one via tapping the spotlit
control, e.g. the first nav-home stop) → Finish → finish view + checklist rows
→ "Let's go" → assert `onboardingService.isComplete('u1')` and the
`StarterChecklistCard` visible on the feed → tap a deep-link action → assert
tab switched. Optionally a second scenario: club admin (`nav_center_add_drive_test.dart`
shows the club-admin login: admin `cadmin5`) sees the 5 club stops and no
checklist. Take screenshots at each stop if the existing harness convention
supports it (see other `*_drive_test.dart` files and the memory note about the
simulator drive/screenshot harness).

**B. Driver sweep + shim deletion** — in these 19 files, replace
`import '...services/tutorial_service.dart'` (relative paths vary) with the
equivalent path to `onboarding/onboarding_service.dart`, and `tutorialService.`
→ `onboardingService.`:
poll, event_datetime, nav_center_add, club_self_profile, user_profile_clubs,
board_role, edit_profile_gate, liquid_glass_nav, user_profile_overflow,
phase0_quick_wins, insights, chats_feature, event_screens, comments,
login_screen, edit_profile, club_description, club_admin_manage, feed
(all `integration_test/*_drive_test.dart`). They only call `initialize()` and
sometimes `complete('<id>')` — semantics are identical (completion under the
new key suppresses the new flow). Then **delete `lib/services/tutorial_service.dart`**
and grep to confirm zero remaining references to `tutorialService`,
`TutorialService`, `tutorial_service`, `tutorialAnchors`, `TutorialAnchors`,
`AppTutorialOverlay`, `AppTutorialStep`.

**C. Verification gate (all must pass):**
1. `~/flutter/bin/flutter analyze` → zero issues.
2. `~/flutter/bin/flutter test` → only the 2 known club_profile_smoke_test
   baseline failures.
3. Run `integration_test/onboarding_drive_test.dart` on the iOS simulator
   (see repo memory: manual tap-through doesn't work in this sandbox; use the
   established drive/screenshot harness).
4. Re-run 2–3 representative old drivers (liquid_glass_nav, chats_feature,
   nav_center_add) to confirm the new service still suppresses onboarding.

## 7. Gotchas / invariants — read before touching anything

- **Never `pumpAndSettle` while the tour phase is visible** — the glow pulse
  controller repeats forever.
- The tap-through trick relies on hit-test mechanics: the flow's root Stack
  must return FALSE from hitTest at the hole (translucent Listener + IgnorePointer
  mask) so MainNavScreen's outer Stack falls through to the Scaffold. Don't
  wrap the flow in anything opaque (no Material/ColoredBox at the root).
- `OnboardingStep.tabIndex` for club steps may only be 0, 1, 3, 4 (club nav
  has no tab 2/Search).
- `eventsRsvp` anchor only mounts when ThisWeekScreen has ≥1 event AND
  `isTutorialHost: true` (only the MainNav-hosted instance); `clubQuickComposer`
  only for club admins on the feed. The degrade-to-card path covers absence.
- `onboardingService.requestTab` intentionally double-sets (null → value) so
  requesting the same tab twice still notifies.
- Old prefs keys `app_tutorial_version_*` are left in storage on purpose;
  every existing user sees the new flow once (new key, version 1).
- The `isTutorialHost` param name on ChatsScreen/ThisWeekScreen was kept to
  minimize churn — do not rename it.
- Strings: TR copy uses "LCV" for RSVP; keep the friendly emoji-tolerant tone
  of the file (e.g. "That's it for today 😀").
- `starterChecklistService` listeners are global and attach once
  (`_listening`); done-flags are sticky by design.
- Do not commit unless the user asks. Current repo already has many unrelated
  modified files on this branch — do not revert or touch them.
