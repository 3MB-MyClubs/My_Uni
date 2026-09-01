import 'package:flutter/widgets.dart';

import '../services/app_strings.dart';
import '../widgets/tutorial_design.dart';
import 'onboarding_anchors.dart';

/// One coach mark in the student tour.
///
/// Copy is resolved lazily so a live language switch mid-tour picks up the new
/// strings. Every field maps to a part of `panel-coach-mark` `391:10`:
/// [pageLabel] + the step counter make the eyebrow, [title] is the one idea,
/// and [body] is the two-sentence explanation.
class OnboardingStep {
  /// The page name in the eyebrow — "HOME FEED", "THIS WEEK", "PROFILE".
  final String Function() pageLabel;

  /// Groups consecutive steps into one page so the eyebrow can count them and
  /// the progress dots can size themselves. Stable across locales, which the
  /// localized [pageLabel] is not.
  final String pageId;

  /// Figtree Bold 17/22 — one idea, six words or fewer. Null on the club-admin
  /// tour, which the design board puts out of scope and which therefore has no
  /// title copy to draw on.
  final String Function()? title;

  /// Figtree Regular 13/19 — two sentences maximum, plain language.
  final String Function() body;

  final GlobalKey targetKey;

  /// The bottom-nav tab that must be selected for the target to be on screen.
  final int tabIndex;

  /// The cut-out's corner radius, which "matches the element being taught".
  final double spotlightRadius;

  /// Whether a tap on the spotlit target is passed through to the real
  /// control. False for targets that push a route or open a sheet/keyboard —
  /// the tap still advances the tour, but the route must not cover it.
  final bool tapThrough;

  OnboardingStep({
    required this.pageLabel,
    required this.pageId,
    required this.body,
    required this.targetKey,
    required this.tabIndex,
    this.title,
    this.spotlightRadius = TutorialMetrics.radiusCard,
    this.tapThrough = true,
  });
}

/// A step with its position inside its page worked out — what the eyebrow, the
/// dots and the footer each need to render.
class ResolvedOnboardingStep {
  final OnboardingStep step;

  /// 0-based position within the page.
  final int indexInPage;

  /// How many steps this page has.
  final int stepsInPage;

  /// Position in the whole tour, for [OnboardingFlow]'s own bookkeeping.
  final int indexInTour;

  const ResolvedOnboardingStep({
    required this.step,
    required this.indexInPage,
    required this.stepsInPage,
    required this.indexInTour,
  });

  /// "HOME FEED · STEP 1 OF 2", or just "ANNOUNCEMENTS" when the page has a
  /// single step.
  String get eyebrow => stepsInPage > 1
      ? S.tutorialEyebrow(step.pageLabel(), indexInPage + 1, stepsInPage)
      : step.pageLabel();

  /// Dots are hidden on single-step pages.
  bool get showProgress => stepsInPage > 1;

  /// "Back appears from step two" — of the page, not of the tour. Verified
  /// against every drawn frame: `tut-chats-tabs` is the sixth step of the tour
  /// and still shows Next alone.
  bool get showBack => indexInPage > 0;

  /// "The primary pill reads Next mid-tour and Got it on the last step of a
  /// page."
  bool get isPageEnd => indexInPage == stepsInPage - 1;
}

/// Works out each step's position within its page from runs of equal
/// [OnboardingStep.pageId].
List<ResolvedOnboardingStep> resolveOnboardingSteps(
  List<OnboardingStep> steps,
) {
  final counts = <String, int>{};
  for (final step in steps) {
    counts[step.pageId] = (counts[step.pageId] ?? 0) + 1;
  }
  final seen = <String, int>{};
  return <ResolvedOnboardingStep>[
    for (var i = 0; i < steps.length; i++)
      () {
        final step = steps[i];
        final indexInPage = seen[step.pageId] ?? 0;
        seen[step.pageId] = indexInPage + 1;
        return ResolvedOnboardingStep(
          step: step,
          indexInPage: indexInPage,
          stepsInPage: counts[step.pageId]!,
          indexInTour: i,
        );
      }(),
  ];
}

/// The student tour — the nine coach marks drawn as `tut-*` frames, in the
/// order the tabs sit in the nav bar.
///
/// The kit board's `panel-tour-map` (`392:49`) maps 32 steps across fifteen
/// surfaces, but only these were drawn. The rest have copy on the board and no
/// layout, and would need the tour to open sheets and push routes mid-flow.
List<OnboardingStep> studentOnboardingSteps() => <OnboardingStep>[
  // `tut-home-nav` 387:3 / 387:195
  OnboardingStep(
    pageLabel: () => S.tutorialPageHomeFeed,
    pageId: 'home',
    title: () => S.tutorialHomeNavTitle,
    body: () => S.tutorialHomeNavBody,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.navBar),
    tabIndex: 0,
    spotlightRadius: TutorialMetrics.radiusNav,
    // The bar's own tap targets switch tabs, which would take the next step's
    // anchor off screen before it is measured.
    tapThrough: false,
  ),
  // `tut-home-following` 387:394 / 387:588
  OnboardingStep(
    pageLabel: () => S.tutorialPageHomeFeed,
    pageId: 'home',
    title: () => S.tutorialHomeFollowingTitle,
    body: () => S.tutorialHomeFollowingBody,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.homeFeedToggle),
    tabIndex: 0,
    spotlightRadius: TutorialMetrics.radiusChip,
    // Opens the Following / For You menu, which would cover the card.
    tapThrough: false,
  ),
  // `tut-events-filters` 388:1123 / 388:1279
  OnboardingStep(
    pageLabel: () => S.tutorialPageThisWeek,
    pageId: 'events',
    title: () => S.tutorialEventsSearchTitle,
    body: () => S.tutorialEventsSearchBody,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.eventsSearch),
    tabIndex: 1,
    spotlightRadius: TutorialMetrics.radiusCard,
    // Passing the tap through would just pop the keyboard open mid-tour.
    tapThrough: false,
  ),
  // `tut-events-card` 388:1434 / 388:1592
  OnboardingStep(
    pageLabel: () => S.tutorialPageThisWeek,
    pageId: 'events',
    title: () => S.tutorialEventsCardTitle,
    body: () => S.tutorialEventsCardBody,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.eventsRsvp),
    tabIndex: 1,
    // Opens the event detail route.
    tapThrough: false,
  ),
  // `tut-search-bar` 389:204 / 389:348
  OnboardingStep(
    pageLabel: () => S.tutorialPageSearch,
    pageId: 'search',
    title: () => S.tutorialSearchTitle,
    body: () => S.tutorialSearchBody,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.searchField),
    tabIndex: 2,
    tapThrough: false,
  ),
  // `tut-chats-tabs` 389:985 / 389:1105
  OnboardingStep(
    pageLabel: () => S.tutorialPageChats,
    pageId: 'chats',
    title: () => S.tutorialChatsTitle,
    body: () => S.tutorialChatsBody,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.chatsLaneDropdown),
    tabIndex: 3,
    spotlightRadius: TutorialMetrics.radiusPill,
    // Opens the Clubs / Friends menu over the card.
    tapThrough: false,
  ),
  // `tut-profile-hero` 390:3 / 390:126
  OnboardingStep(
    pageLabel: () => S.tutorialPageProfile,
    pageId: 'profile',
    title: () => S.tutorialProfileHeroTitle,
    body: () => S.tutorialProfileHeroBody,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.profileHero),
    tabIndex: 4,
  ),
  // `tut-profile-clubs` 390:248 / 390:373
  OnboardingStep(
    pageLabel: () => S.tutorialPageProfile,
    pageId: 'profile',
    title: () => S.tutorialProfileClubsTitle,
    body: () => S.tutorialProfileClubsBody,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.profileClubs),
    tabIndex: 4,
  ),
];

/// The club-admin tour. Their nav has no Search tab and a center "+" button;
/// their Profile tab is the club's own management view.
///
/// `panel-behaviour` `392:5` puts admin and club-officer screens out of scope —
/// "This tour is student side only" — so these keep the guide lines they
/// already had and render them as body copy with no title.
List<OnboardingStep> clubAdminOnboardingSteps({
  bool usesModerationTab = false,
}) => <OnboardingStep>[
  OnboardingStep(
    pageLabel: () => S.tutorialPageClubFeed,
    pageId: 'club-feed',
    body: () => S.onboardingClubComposer,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.clubQuickComposer),
    tabIndex: 0,
    // Opens the Big Picture composer sheet.
    tapThrough: false,
  ),
  OnboardingStep(
    pageLabel: () => S.tutorialPageClubFeed,
    pageId: 'club-feed',
    body: () => S.onboardingClubCreateEvent,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.clubCreateButton),
    tabIndex: 0,
    // Opens CreateEventScreen as a fullscreen dialog.
    tapThrough: false,
  ),
  OnboardingStep(
    pageLabel: () =>
        usesModerationTab ? S.tutorialPageModeration : S.tutorialPageChats,
    pageId: 'club-chats',
    body: () =>
        usesModerationTab ? S.onboardingClubModeration : S.onboardingClubChats,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.navChats),
    tabIndex: 3,
    spotlightRadius: TutorialMetrics.radiusNav,
    tapThrough: false,
  ),
  OnboardingStep(
    pageLabel: () => S.tutorialPageClubProfile,
    pageId: 'club-profile',
    body: () => S.onboardingClubProfileTabs,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.clubProfileTabs),
    tabIndex: 4,
  ),
  OnboardingStep(
    pageLabel: () => S.tutorialPageClubProfile,
    pageId: 'club-profile',
    body: () => S.onboardingClubSettings,
    targetKey: onboardingAnchors.keyFor(OnboardingAnchors.clubProfileSettings),
    tabIndex: 4,
    spotlightRadius: TutorialMetrics.radiusChip,
    // Pushes the settings route.
    tapThrough: false,
  ),
];
