import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/onboarding/onboarding_flow.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_steps.dart';
import 'package:flutter_application_1/onboarding/widgets/onboarding_guide_card.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';

/// Every localized string the tutorial renders, keyed for failure messages.
Map<String, String Function()> _allOnboardingCopy() => {
  // Coach-card controls.
  'next': () => S.onboardingNext,
  'back': () => S.onboardingBack,
  'skipTour': () => S.onboardingSkipTour,
  'gotIt': () => S.tutorialGotIt,
  'eyebrow': () => S.tutorialEyebrow(S.tutorialPageHomeFeed, 1, 2),
  // Page names.
  'pageHomeFeed': () => S.tutorialPageHomeFeed,
  'pageThisWeek': () => S.tutorialPageThisWeek,
  'pageSearch': () => S.tutorialPageSearch,
  'pageChats': () => S.tutorialPageChats,
  'pageProfile': () => S.tutorialPageProfile,
  'pageAnnouncements': () => S.tutorialPageAnnouncements,
  // The nine drawn coach marks.
  'homeNavTitle': () => S.tutorialHomeNavTitle,
  'homeNavBody': () => S.tutorialHomeNavBody,
  'homeFollowingTitle': () => S.tutorialHomeFollowingTitle,
  'homeFollowingBody': () => S.tutorialHomeFollowingBody,
  'eventsSearchTitle': () => S.tutorialEventsSearchTitle,
  'eventsSearchBody': () => S.tutorialEventsSearchBody,
  'eventsCardTitle': () => S.tutorialEventsCardTitle,
  'eventsCardBody': () => S.tutorialEventsCardBody,
  'searchTitle': () => S.tutorialSearchTitle,
  'searchBody': () => S.tutorialSearchBody,
  'chatsTitle': () => S.tutorialChatsTitle,
  'chatsBody': () => S.tutorialChatsBody,
  'profileHeroTitle': () => S.tutorialProfileHeroTitle,
  'profileHeroBody': () => S.tutorialProfileHeroBody,
  'profileClubsTitle': () => S.tutorialProfileClubsTitle,
  'profileClubsBody': () => S.tutorialProfileClubsBody,
  'announcementsTitle': () => S.tutorialAnnouncementsTitle,
  'announcementsBody': () => S.tutorialAnnouncementsBody,
  // The two full-screen moments.
  'welcomeEyebrow': () => S.tutorialWelcomeEyebrow,
  'welcomeTitle': () => S.tutorialWelcomeTitle,
  'welcomeBody': () => S.tutorialWelcomeBody,
  'welcomeFootnote': () => S.tutorialWelcomeFootnote,
  'skipForNow': () => S.tutorialSkipForNow,
  'startTour': () => S.tutorialStartTour,
  'finishEyebrow': () => S.tutorialFinishEyebrow,
  'finishTitle': () => S.tutorialFinishTitle,
  'finishBody': () => S.tutorialFinishBody,
  'finishFootnote': () => S.tutorialFinishFootnote,
  'replayTour': () => S.tutorialReplayTour,
  'exploreClubUp': () => S.tutorialExploreClubUp,
  // The club-admin tour still renders through the same card.
  'clubComposer': () => S.onboardingClubComposer,
  'clubCreateEvent': () => S.onboardingClubCreateEvent,
  'clubProfileTabs': () => S.onboardingClubProfileTabs,
  'clubChats': () => S.onboardingClubChats,
  'clubModeration': () => S.onboardingClubModeration,
  'clubSettings': () => S.onboardingClubSettings,
};

/// Pumps enough frames for measurement retries + spotlight/switcher motion.
Future<void> _settleFlow(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  group('OnboardingService', () {
    test('completion is stored per user under the new key', () async {
      SharedPreferences.setMockInitialValues({});
      final service = OnboardingService();
      await service.initialize();

      expect(service.isComplete('student-1'), isFalse);
      expect(service.isComplete('student-2'), isFalse);

      await service.complete('student-1');
      expect(service.isComplete('student-1'), isTrue);
      expect(service.isComplete('student-2'), isFalse);

      await service.reset('student-1');
      expect(service.isComplete('student-1'), isFalse);

      // Empty user ids never show onboarding.
      expect(service.isComplete(''), isTrue);
    });

    test('old tutorial completion does not satisfy the new flow', () async {
      SharedPreferences.setMockInitialValues({'app_tutorial_version_u1': 2});
      final service = OnboardingService();
      await service.initialize();
      expect(service.isComplete('u1'), isFalse);
    });
  });

  group('Onboarding copy', () {
    tearDown(() async {
      await localeService.setLanguage('en');
    });

    test('every string has distinct EN and TR variants', () async {
      await localeService.setLanguage('en');
      final english = _allOnboardingCopy().map(
        (key, resolve) => MapEntry(key, resolve()),
      );
      await localeService.setLanguage('tr');
      final turkish = _allOnboardingCopy().map(
        (key, resolve) => MapEntry(key, resolve()),
      );

      for (final key in english.keys) {
        expect(english[key], isNotEmpty, reason: 'EN "$key" is empty');
        expect(turkish[key], isNotEmpty, reason: 'TR "$key" is empty');
        expect(
          english[key],
          isNot(turkish[key]),
          reason: '"$key" is identical in EN and TR',
        );
      }
    });
  });

  group('OnboardingFlow', () {
    tearDown(() async {
      await localeService.setLanguage('en');
      await themeService.setDark(false);
    });

    testWidgets('follows the theme selected before and during the tour', (
      tester,
    ) async {
      await themeService.setDark(false);
      var completed = false;
      var homeReturns = 0;
      final harness = _TourHarness(
        onComplete: () => completed = true,
        onNavigateHome: () => homeReturns++,
      );
      await tester.pumpWidget(harness.build());
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const ValueKey('onboarding-welcome-light')),
        findsOneWidget,
      );

      await themeService.setDark(true);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('onboarding-welcome-dark')),
        findsOneWidget,
      );

      await tester.tap(find.text(S.tutorialStartTour));
      await _settleFlow(tester);
      expect(
        find.byKey(const ValueKey('onboarding-guide-card-dark')),
        findsOneWidget,
      );

      await themeService.setDark(false);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('onboarding-guide-card-light')),
        findsOneWidget,
      );

      await tester.tap(find.text(S.onboardingNext));
      await _settleFlow(tester);
      await tester.tap(find.text(S.tutorialGotIt));
      await _settleFlow(tester);
      expect(
        find.byKey(const ValueKey('onboarding-finish-light')),
        findsOneWidget,
      );
      expect(homeReturns, 0);
      expect(completed, isFalse);

      await tester.tap(find.text(S.tutorialExploreClubUp));
      await _settleFlow(tester);
      expect(homeReturns, 1);
      expect(completed, isTrue);
    });

    testWidgets('welcome states the tour and skipping completes', (
      tester,
    ) async {
      var skipped = false;
      var completed = false;
      var homeReturns = 0;
      final harness = _TourHarness(
        onComplete: () => completed = true,
        onSkip: () => skipped = true,
        onNavigateHome: () => homeReturns++,
      );
      await tester.pumpWidget(harness.build());
      await tester.pump(const Duration(milliseconds: 400));

      // `tut-welcome` is not personalised: eyebrow, title, body, footnote and
      // the two controls, and nothing else.
      expect(find.text(S.tutorialWelcomeEyebrow), findsOneWidget);
      expect(find.text(S.tutorialWelcomeTitle), findsOneWidget);
      expect(find.text(S.tutorialWelcomeBody), findsOneWidget);
      expect(find.text(S.tutorialWelcomeFootnote), findsOneWidget);
      expect(find.text(S.tutorialStartTour), findsOneWidget);
      expect(find.text(S.tutorialSkipForNow), findsOneWidget);

      await tester.tap(find.text(S.tutorialSkipForNow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Flush the async continuation waiting on the reverse entrance
      // animation; a single timed pump completes the ticker but does not run
      // the callback's post-await microtask until the next frame.
      await tester.pump();

      expect(skipped, isTrue);
      expect(completed, isFalse);
      expect(homeReturns, 1);
    });

    testWidgets('next/back navigate and tapping the spotlit control advances', (
      tester,
    ) async {
      final harness = _TourHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text(S.tutorialStartTour));
      await _settleFlow(tester);

      // Step 1 with its guide line, skip pill, and no Back button yet.
      expect(find.text(S.tutorialHomeNavBody), findsOneWidget);
      expect(find.text(S.onboardingSkipTour), findsOneWidget);
      expect(find.text(S.onboardingBack), findsNothing);
      expect(find.text(S.onboardingNext), findsOneWidget);

      // Next → step 2, Back → step 1.
      await tester.tap(find.text(S.onboardingNext));
      await _settleFlow(tester);
      expect(find.text(S.tutorialProfileHeroBody), findsOneWidget);
      await tester.tap(find.text(S.onboardingBack));
      await _settleFlow(tester);
      expect(find.text(S.tutorialHomeNavBody), findsOneWidget);

      // A tap inside the spotlight reaches the real control AND advances.
      await tester.tapAt(tester.getCenter(find.byKey(harness.firstTargetKey)));
      await _settleFlow(tester);
      expect(harness.firstTaps, 1);
      expect(find.text(S.tutorialProfileHeroBody), findsOneWidget);

      // Step 2 is tapThrough=false: the tap opens the finish moment but must
      // NOT reach the underlying control (it would push a route).
      await tester.tapAt(tester.getCenter(find.byKey(harness.secondTargetKey)));
      await _settleFlow(tester);
      expect(harness.secondTaps, 0);
      expect(find.text(S.tutorialFinishTitle), findsOneWidget);
    });

    testWidgets('Lets go completes the tour and returns directly Home', (
      tester,
    ) async {
      var completed = false;
      var homeReturns = 0;
      final harness = _TourHarness(
        onComplete: () => completed = true,
        onNavigateHome: () => homeReturns++,
      );
      await tester.pumpWidget(harness.build());
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text(S.tutorialStartTour));
      await _settleFlow(tester);
      await tester.tap(find.text(S.onboardingNext));
      await _settleFlow(tester);
      await tester.tap(find.text(S.tutorialGotIt));
      await _settleFlow(tester);

      expect(find.text(S.tutorialFinishTitle), findsOneWidget);
      expect(find.text(S.tutorialExploreClubUp), findsOneWidget);
      expect(completed, isFalse);
      expect(homeReturns, 0);

      await tester.tap(find.text(S.tutorialExploreClubUp));
      await _settleFlow(tester);
      expect(completed, isTrue);
      expect(homeReturns, 1);
    });

    testWidgets(
      'the card clears its target and stays on screen near the edges',
      (tester) async {
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final harness = _PlacementHarness();
        await tester.pumpWidget(harness.build());
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text(S.tutorialStartTour));
        await _settleFlow(tester);

        for (var index = 0; index < harness.targetKeys.length; index++) {
          final targetRect = tester.getRect(
            find.byKey(harness.targetKeys[index]),
          );
          final guideRect = tester.getRect(find.byType(OnboardingGuideCard));
          final skipRect = tester.getRect(
            find.byKey(const ValueKey('onboarding-skip-button')),
          );
          final screenRect = Offset.zero & tester.view.physicalSize;
          // The cut-out is the target inflated by 8; the card sits 14 clear
          // of that, so it must never touch the target's own bounds.
          final cutout = targetRect.inflate(8);

          expect(
            guideRect.overlaps(cutout),
            isFalse,
            reason: 'card overlaps the spotlight at step $index',
          );
          // Skip tour is inside the footer now, not a free-floating pill.
          expect(guideRect.contains(skipRect.topLeft), isTrue);
          expect(guideRect.contains(skipRect.bottomRight), isTrue);

          // "clamped 12 px from the screen edge"
          expect(guideRect.left, greaterThanOrEqualTo(screenRect.left + 12));
          expect(guideRect.top, greaterThanOrEqualTo(screenRect.top));
          expect(guideRect.right, lessThanOrEqualTo(screenRect.right - 12));
          expect(guideRect.bottom, lessThanOrEqualTo(screenRect.bottom));
          // The card is a fixed 306 wide and hugs its content.
          expect(guideRect.width, closeTo(306, 0.5));

          if (index < harness.targetKeys.length - 1) {
            await tester.tap(find.text(S.onboardingNext));
            await _settleFlow(tester);
          }
        }
      },
    );

    testWidgets('guide copy swaps live when the language changes mid-tour', (
      tester,
    ) async {
      final harness = _TourHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text(S.tutorialStartTour));
      await _settleFlow(tester);

      await localeService.setLanguage('en');
      final english = S.tutorialHomeNavBody;
      expect(find.text(english), findsOneWidget);

      await localeService.setLanguage('tr');
      await tester.pump();
      final turkish = S.tutorialHomeNavBody;
      expect(turkish, isNot(english));
      expect(find.text(turkish), findsOneWidget);
      expect(find.text(english), findsNothing);
    });
  });
}

/// Two real buttons under an [OnboardingFlow] with a two-step tour aimed at
/// them — step 1 passes taps through, step 2 doesn't.
class _TourHarness {
  final GlobalKey firstTargetKey = GlobalKey();
  final GlobalKey secondTargetKey = GlobalKey();
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final VoidCallback? onNavigateHome;
  int firstTaps = 0;
  int secondTaps = 0;

  _TourHarness({this.onComplete, this.onSkip, this.onNavigateHome});

  Widget build() {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        key: firstTargetKey,
                        icon: const Icon(Icons.home_rounded),
                        onPressed: () => firstTaps++,
                      ),
                      IconButton(
                        key: secondTargetKey,
                        icon: const Icon(Icons.person_rounded),
                        onPressed: () => secondTaps++,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: OnboardingFlow(
                  steps: [
                    // Two steps on one page, so the second gets Back and the
                    // primary pill reads "Got it".
                    OnboardingStep(
                      pageLabel: () => S.tutorialPageHomeFeed,
                      pageId: 'home',
                      title: () => S.tutorialHomeNavTitle,
                      body: () => S.tutorialHomeNavBody,
                      targetKey: firstTargetKey,
                      tabIndex: 0,
                    ),
                    OnboardingStep(
                      pageLabel: () => S.tutorialPageHomeFeed,
                      pageId: 'home',
                      title: () => S.tutorialProfileHeroTitle,
                      body: () => S.tutorialProfileHeroBody,
                      targetKey: secondTargetKey,
                      tabIndex: 0,
                      tapThrough: false,
                    ),
                  ],
                  onStepChanged: (_) {},
                  onComplete: onComplete ?? () {},
                  onSkip: onSkip ?? () {},
                  onNavigateHome: onNavigateHome,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlacementHarness {
  final List<GlobalKey> targetKeys = List.generate(3, (_) => GlobalKey());

  Widget build() {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 8,
                top: 72,
                child: IconButton(
                  key: targetKeys[0],
                  onPressed: () {},
                  icon: const Icon(Icons.home_rounded),
                ),
              ),
              Center(
                child: IconButton(
                  key: targetKeys[1],
                  onPressed: () {},
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 72,
                child: IconButton(
                  key: targetKeys[2],
                  onPressed: () {},
                  icon: const Icon(Icons.person_rounded),
                ),
              ),
              Positioned.fill(
                child: OnboardingFlow(
                  steps: [
                    for (var index = 0; index < targetKeys.length; index++)
                      OnboardingStep(
                        pageLabel: () => S.tutorialPageHomeFeed,
                        // One page, so the pill reads Next until the last.
                        pageId: 'page',
                        title: () => S.tutorialHomeNavTitle,
                        body: () => S.tutorialHomeNavBody,
                        targetKey: targetKeys[index],
                        tabIndex: 0,
                      ),
                  ],
                  onStepChanged: (_) {},
                  onComplete: () {},
                  onSkip: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
