import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/onboarding/onboarding_flow.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_steps.dart';
import 'package:flutter_application_1/onboarding/starter_checklist_service.dart';
import 'package:flutter_application_1/onboarding/widgets/onboarding_guide_card.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/rsvp_store.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';

/// Every localized string the onboarding renders, keyed for failure messages.
Map<String, String Function()> _allOnboardingCopy() => {
  'welcomeEyebrow': () => S.onboardingWelcomeEyebrow,
  'welcomeTitle': () => S.onboardingWelcomeTitle('Ayşe'),
  'welcomeBody': () => S.onboardingWelcomeBody,
  'showMeAround': () => S.onboardingShowMeAround,
  'exploreOnMyOwn': () => S.onboardingExploreOnMyOwn,
  'next': () => S.onboardingNext,
  'back': () => S.onboardingBack,
  'finish': () => S.onboardingFinish,
  'skipTour': () => S.onboardingSkipTour,
  'stepLabel': () => S.onboardingStepLabel(1, 6),
  'tapHint': () => S.onboardingTapHint,
  'studentHome': () => S.onboardingStudentHome,
  'studentFeedToggle': () => S.onboardingStudentFeedToggle,
  'studentRsvp': () => S.onboardingStudentRsvp,
  'studentExplore': () => S.onboardingStudentExplore,
  'studentCompose': () => S.onboardingStudentCompose,
  'studentProfile': () => S.onboardingStudentProfile,
  'clubComposer': () => S.onboardingClubComposer,
  'clubCreateEvent': () => S.onboardingClubCreateEvent,
  'clubProfileTabs': () => S.onboardingClubProfileTabs,
  'clubChats': () => S.onboardingClubChats,
  'clubSettings': () => S.onboardingClubSettings,
  'finishTitle': () => S.onboardingFinishTitle,
  'finishBody': () => S.onboardingFinishBody,
  'finishBodyClub': () => S.onboardingFinishBodyClub,
  'letsGo': () => S.onboardingLetsGo,
  'checklistTitle': () => S.checklistTitle,
  'checklistSubtitle': () => S.checklistSubtitle,
  'checklistFollowClub': () => S.checklistFollowClub,
  'checklistFollowClubAction': () => S.checklistFollowClubAction,
  'checklistRsvpEvent': () => S.checklistRsvpEvent,
  'checklistRsvpEventAction': () => S.checklistRsvpEventAction,
  'checklistSayHi': () => S.checklistSayHi,
  'checklistSayHiAction': () => S.checklistSayHiAction,
  'checklistDismiss': () => S.checklistDismiss,
  'checklistAllDone': () => S.checklistAllDone,
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

      await tester.tap(find.text(S.onboardingShowMeAround));
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
      await tester.tap(find.text(S.onboardingFinish));
      await _settleFlow(tester);
      expect(
        find.byKey(const ValueKey('onboarding-finish-light')),
        findsOneWidget,
      );
      expect(homeReturns, 0);
      expect(completed, isFalse);

      await tester.tap(find.text(S.onboardingLetsGo));
      await _settleFlow(tester);
      expect(homeReturns, 1);
      expect(completed, isTrue);
    });

    testWidgets('welcome greets by name and skipping completes', (
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

      expect(find.textContaining('Ayşe'), findsOneWidget);
      expect(find.text(S.onboardingShowMeAround), findsOneWidget);
      expect(find.text(S.onboardingExploreOnMyOwn), findsOneWidget);

      await tester.tap(find.text(S.onboardingExploreOnMyOwn));
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

      await tester.tap(find.text(S.onboardingShowMeAround));
      await _settleFlow(tester);

      // Step 1 with its guide line, skip pill, and no Back button yet.
      expect(find.text(S.onboardingStudentHome), findsOneWidget);
      expect(find.text(S.onboardingSkipTour), findsOneWidget);
      expect(find.text(S.onboardingBack), findsNothing);
      expect(find.text(S.onboardingNext), findsOneWidget);

      // Next → step 2, Back → step 1.
      await tester.tap(find.text(S.onboardingNext));
      await _settleFlow(tester);
      expect(find.text(S.onboardingStudentProfile), findsOneWidget);
      await tester.tap(find.text(S.onboardingBack));
      await _settleFlow(tester);
      expect(find.text(S.onboardingStudentHome), findsOneWidget);

      // A tap inside the spotlight reaches the real control AND advances.
      await tester.tapAt(tester.getCenter(find.byKey(harness.firstTargetKey)));
      await _settleFlow(tester);
      expect(harness.firstTaps, 1);
      expect(find.text(S.onboardingStudentProfile), findsOneWidget);

      // Step 2 is tapThrough=false: the tap opens the finish moment but must
      // NOT reach the underlying control (it would push a route).
      await tester.tapAt(tester.getCenter(find.byKey(harness.secondTargetKey)));
      await _settleFlow(tester);
      expect(harness.secondTaps, 0);
      expect(find.text(S.onboardingFinishTitle), findsOneWidget);
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

      await tester.tap(find.text(S.onboardingShowMeAround));
      await _settleFlow(tester);
      await tester.tap(find.text(S.onboardingNext));
      await _settleFlow(tester);
      await tester.tap(find.text(S.onboardingFinish));
      await _settleFlow(tester);

      expect(find.text(S.onboardingFinishTitle), findsOneWidget);
      expect(find.text(S.onboardingLetsGo), findsOneWidget);
      expect(completed, isFalse);
      expect(homeReturns, 0);

      await tester.tap(find.text(S.onboardingLetsGo));
      await _settleFlow(tester);
      expect(completed, isTrue);
      expect(homeReturns, 1);
    });

    testWidgets(
      'card and Skip avoid targets and each other near screen edges',
      (tester) async {
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final harness = _PlacementHarness();
        await tester.pumpWidget(harness.build());
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text(S.onboardingShowMeAround));
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

          expect(guideRect.overlaps(targetRect.inflate(12)), isFalse);
          expect(skipRect.overlaps(targetRect.inflate(12)), isFalse);
          expect(skipRect.overlaps(guideRect.inflate(12)), isFalse);
          expect(guideRect.left, greaterThanOrEqualTo(screenRect.left));
          expect(guideRect.top, greaterThanOrEqualTo(screenRect.top));
          expect(guideRect.right, lessThanOrEqualTo(screenRect.right));
          expect(guideRect.bottom, lessThanOrEqualTo(screenRect.bottom));
          expect(skipRect.left, greaterThanOrEqualTo(screenRect.left));
          expect(skipRect.top, greaterThanOrEqualTo(screenRect.top));
          expect(skipRect.right, lessThanOrEqualTo(screenRect.right));
          expect(skipRect.bottom, lessThanOrEqualTo(screenRect.bottom));

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

      await tester.tap(find.text(S.onboardingShowMeAround));
      await _settleFlow(tester);

      await localeService.setLanguage('en');
      final english = S.onboardingStudentHome;
      expect(find.text(english), findsOneWidget);

      await localeService.setLanguage('tr');
      await tester.pump();
      final turkish = S.onboardingStudentHome;
      expect(turkish, isNot(english));
      expect(find.text(turkish), findsOneWidget);
      expect(find.text(english), findsNothing);
    });
  });

  group('StarterChecklistService', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('onboarding_test_');
      Hive.init(tempDir.path);
      await chatStore.initialize();
    });

    tearDownAll(() async {
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('detection is baseline-relative and sticky', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StarterChecklistService();
      await service.initialize();

      // 'c1' is pre-seeded — it must NOT count as "followed a club".
      expect(userState.followedClubIds, contains('c1'));
      await service.startFor('u1');
      expect(service.isActiveFor('u1'), isTrue);
      expect(service.followDone, isFalse);
      expect(service.rsvpDone, isFalse);
      expect(service.chatDone, isFalse);

      // Following a NEW club checks the item off.
      userState.toggleFollow('c2');
      expect(service.followDone, isTrue);
      // Sticky: unfollowing doesn't un-check it.
      userState.toggleFollow('c2');
      expect(service.followDone, isTrue);

      // A new RSVP checks the item off (seed + any store notification).
      rsvpStore.seed(events.first.id, true);
      userState.toggleFollowUser('test-peer');
      expect(service.rsvpDone, isTrue);
      rsvpStore.seed(events.first.id, false);
      userState.toggleFollowUser('test-peer');

      // Sending a message after the tour checks the last item off.
      final threadId = chatStore.ensureDirectThread('u1', 'u2')!;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final sent = chatStore.sendMessage(
        threadId: threadId,
        senderId: 'u1',
        content: 'hi there!',
      );
      expect(sent, isNotNull);
      expect(service.chatDone, isTrue);
      expect(service.allDone, isTrue);
      expect(service.isActiveFor('u1'), isFalse);
    });

    test('dismissal and progress survive a service restart', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StarterChecklistService();
      await service.initialize();
      await service.startFor('u9');
      expect(service.isActiveFor('u9'), isTrue);

      userState.toggleFollow('c3');
      expect(service.followDone, isTrue);
      userState.toggleFollow('c3'); // restore global state

      await service.dismiss();
      expect(service.isActiveFor('u9'), isFalse);

      // A fresh instance reading the same prefs sees the same state.
      final revived = StarterChecklistService();
      await revived.initialize();
      await revived.startFor('u9');
      expect(revived.isActiveFor('u9'), isFalse);
      expect(revived.followDone, isTrue);
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
                    OnboardingStep(
                      guideLine: () => S.onboardingStudentHome,
                      icon: Icons.home_rounded,
                      targetKey: firstTargetKey,
                      tabIndex: 0,
                    ),
                    OnboardingStep(
                      guideLine: () => S.onboardingStudentProfile,
                      icon: Icons.person_rounded,
                      targetKey: secondTargetKey,
                      tabIndex: 0,
                      tapThrough: false,
                    ),
                  ],
                  userId: 'u1',
                  firstName: 'Ayşe',
                  showChecklist: true,
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
                        guideLine: () => S.onboardingStudentHome,
                        icon: Icons.auto_awesome_rounded,
                        targetKey: targetKeys[index],
                        tabIndex: 0,
                      ),
                  ],
                  userId: 'u1',
                  firstName: 'Ayşe',
                  showChecklist: false,
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
