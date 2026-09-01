import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/calendar/providers/calendar_provider.dart';
import 'package:flutter_application_1/features/calendar/providers/calendar_state.dart';
import 'package:flutter_application_1/features/calendar/services/calendar_service.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/onboarding/onboarding_anchors.dart';
import 'package:flutter_application_1/onboarding/onboarding_steps.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/onboarding/starter_checklist_service.dart';
import 'package:flutter_application_1/onboarding/widgets/onboarding_guide_card.dart';
import 'package:flutter_application_1/onboarding/widgets/starter_checklist_card.dart';
import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/view_tracker.dart';

class _GrantedCalendarService extends CalendarService {
  @override
  Future<CalendarPermissionState> checkPermission() async =>
      CalendarPermissionState.granted;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settleFlow(WidgetTester tester) async {
    // The tour's glow pulse repeats forever, so pumpAndSettle cannot be used.
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 120));
    try {
      await binding.takeScreenshot(name);
    } catch (_) {
      // Direct desktop `flutter test` runs do not register the screenshot
      // channel. The iOS drive/screenshot harness does.
    }
  }

  void expectChromeClearOf(WidgetTester tester, GlobalKey targetKey) {
    final target = find.byKey(targetKey);
    expect(target, findsOneWidget);
    final targetRect = tester.getRect(target).inflate(12);
    final guideRect = tester.getRect(find.byType(OnboardingGuideCard));
    final skipRect = tester.getRect(
      find.byKey(const ValueKey('onboarding-skip-button')),
    );
    expect(guideRect.overlaps(targetRect), isFalse);
    expect(skipRect.overlaps(targetRect), isFalse);
    expect(guideRect.contains(skipRect.center), isTrue);
  }

  testWidgets('student completes the campus tour and uses the checklist', (
    tester,
  ) async {
    authService.logout();
    await hiveBootstrap.initialize();
    await Future.wait([
      userPrefsService.initialize(),
      contentStore.initialize(),
      chatStore.initialize(),
      viewTracker.initialize(),
      personalizationService.initialize(),
      themeService.initialize(),
      localeService.initialize(),
      onboardingService.initialize(),
      starterChecklistService.initialize(),
    ]);
    contentStore.applyToLists();

    const testEmail = 'onboarding.drive@ku.edu.tr';
    const testPassword = '135790';
    if (!authService.login(testEmail, testPassword)) {
      expect(
        authService.signUp('Onboarding Student', testEmail, testPassword),
        isTrue,
      );
    }
    final userId = authService.currentUser!.id;

    // Runtime data no longer ships with bundled fixtures. Supply one upcoming
    // event so the event-card coach mark exercises a real anchor rather than
    // the flow's card-only fallback for empty states.
    const fixtureClubId = 'onboarding-drive-club';
    const fixtureEventId = 'onboarding-drive-event';
    clubs.removeWhere((club) => club.id == fixtureClubId);
    events.removeWhere((event) => event.id == fixtureEventId);
    clubs.add(
      Club(
        id: fixtureClubId,
        name: 'Campus Tour Club',
        description: 'Integration-test fixture',
        adminUserIds: const [],
      ),
    );
    final eventStart = DateTime.now().add(const Duration(days: 1));
    events.add(
      Event(
        id: fixtureEventId,
        clubId: fixtureClubId,
        title: 'Campus Tour Event',
        description: 'Integration-test fixture',
        dateTime: eventStart,
        endTime: eventStart.add(const Duration(hours: 1)),
        location: 'Koç University',
        attendeeUserIds: const [],
      ),
    );
    addTearDown(() {
      events.removeWhere((event) => event.id == fixtureEventId);
      clubs.removeWhere((club) => club.id == fixtureClubId);
      authService.logout();
    });

    userPrefsService.load(userId);
    await themeService.markThemeChosen(userId, false);
    await localeService.markLanguageChosen(userId, 'en');
    await onboardingService.reset(userId);

    // A drive can reuse simulator preferences from an earlier run. Clear only
    // this test user's checklist so the post-tour card starts fresh.
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('onboarding_checklist_$userId');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarServiceProvider.overrideWithValue(_GrantedCalendarService()),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MainNavScreen(isAdmin: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(S.tutorialWelcomeTitle), findsOneWidget);
    expect(find.text(S.tutorialStartTour), findsOneWidget);
    expect(find.text(S.tutorialSkipForNow), findsOneWidget);
    await shot(tester, 'onboarding-01-welcome');

    await themeService.setDark(true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('onboarding-welcome-dark')),
      findsOneWidget,
    );
    await shot(tester, 'onboarding-01b-welcome-dark');
    await themeService.setDark(false);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text(S.tutorialStartTour));
    await settleFlow(tester);

    final tourSteps = resolveOnboardingSteps(studentOnboardingSteps());

    expect(find.text(tourSteps.first.step.body()), findsOneWidget);
    expectChromeClearOf(tester, tourSteps.first.step.targetKey);
    await shot(tester, 'onboarding-02-home');

    await themeService.setDark(true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('onboarding-guide-card-dark')),
      findsOneWidget,
    );
    await shot(tester, 'onboarding-02b-home-dark');
    await themeService.setDark(false);
    await tester.pump(const Duration(milliseconds: 400));

    // Exercise the alternate advancement path once. The whole navigation bar
    // is the first target; the overlay consumes this tap so it advances the
    // tour without accidentally switching tabs.
    await tester.tap(
      find.byKey(tourSteps.first.step.targetKey),
      // The onboarding overlay intentionally owns this hit while the real
      // navigation bar remains underneath it.
      warnIfMissed: false,
    );
    await settleFlow(tester);

    for (var index = 1; index < tourSteps.length; index++) {
      final step = tourSteps[index];
      expect(find.text(step.step.body()), findsOneWidget);
      expectChromeClearOf(tester, step.step.targetKey);
      await shot(tester, 'onboarding-${index + 2}-stop-${index + 1}');
      final advanceLabel = step.isPageEnd ? S.tutorialGotIt : S.onboardingNext;
      await tester.tap(find.text(advanceLabel));
      await settleFlow(tester);
    }

    expect(find.text(S.tutorialFinishTitle), findsOneWidget);
    expect(find.text(S.tutorialReplayTour), findsOneWidget);
    expect(find.text(S.tutorialExploreClubUp), findsOneWidget);
    expect(find.text(S.checklistTitle), findsNothing);
    expect(onboardingService.isComplete(userId), isFalse);
    await shot(tester, 'onboarding-08-finish');

    // The one final CTA starts the Home transition while the overlay fades,
    // then persists completion and starts the checklist.
    await tester.tap(find.text(S.tutorialExploreClubUp));
    await settleFlow(tester);
    expect(find.byKey(const ValueKey('onboarding-skip-button')), findsNothing);
    expect(onboardingService.isComplete(userId), isTrue);
    expect(find.byType(StarterChecklistCard), findsNothing);
    expect(find.text(S.checklistTitle), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    await shot(tester, 'onboarding-09-home-after-finish');

    // Get started lives on Profile, with a clear manual close control.
    await tester.tap(
      find.byKey(onboardingAnchors.keyFor(OnboardingAnchors.navProfile)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StarterChecklistCard), findsOneWidget);
    expect(find.text(S.checklistTitle), findsOneWidget);
    expect(
      find.byKey(const ValueKey('starter-checklist-close')),
      findsOneWidget,
    );
    await shot(tester, 'onboarding-10-profile-checklist');

    // The checklist's first action requests Explore (student tab 2).
    await tester.tap(find.text(S.checklistFollowClubAction));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(onboardingAnchors.keyFor(OnboardingAnchors.searchField)),
      findsOneWidget,
    );
    await shot(tester, 'onboarding-11-checklist-explore');

    // A student who already knows the app can close the checklist directly.
    await tester.tap(
      find.byKey(onboardingAnchors.keyFor(OnboardingAnchors.navProfile)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('starter-checklist-close')));
    await tester.pump(const Duration(milliseconds: 500));
    // The Profile screen keeps the card widget mounted; dismissal collapses
    // its contents instead of replacing the widget itself.
    expect(find.byType(StarterChecklistCard), findsOneWidget);
    expect(find.text(S.checklistTitle), findsNothing);
    expect(find.byKey(const ValueKey('starter-checklist-close')), findsNothing);
    expect(starterChecklistService.isActiveFor(userId), isFalse);
    await shot(tester, 'onboarding-12-profile-checklist-dismissed');
    expect(tester.takeException(), isNull);
  });
}
