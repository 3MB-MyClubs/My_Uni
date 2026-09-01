import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/onboarding/onboarding_anchors.dart';
import 'package:flutter_application_1/onboarding/onboarding_steps.dart';
import 'package:flutter_application_1/onboarding/widgets/onboarding_finish_view.dart';
import 'package:flutter_application_1/onboarding/widgets/onboarding_guide_card.dart';
import 'package:flutter_application_1/onboarding/widgets/onboarding_welcome_view.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/tutorial_design.dart';

/// `STUDENT UI · IN-APP TUTORIAL` — the kit board `canvas-tutorial-kit` 391:4
/// and the eleven `tut-*` frames at y≈34000.
void main() {
  setUp(() async {
    await localeService.setLanguage('en');
    await themeService.setDark(false);
  });

  tearDown(() async {
    await localeService.setLanguage('en');
    await themeService.setDark(false);
  });

  group('placeTutorialCard', () {
    const screen = Size(402, 874);
    const safe = EdgeInsets.only(top: 44, bottom: 34);
    const cardSize = Size(TutorialMetrics.cardWidth, 209);

    test('sits 14 clear below the spotlight and centres on it', () {
      // `tut-chats-tabs`: hole 164,52 106×44 → card at 64,110, beak at 207,101.
      const hole = Rect.fromLTWH(164, 52, 106, 44);
      final placement = placeTutorialCard(
        screen: screen,
        safeArea: safe,
        hole: hole,
        cardSize: cardSize,
      );

      expect(placement.card.top, hole.bottom + 14);
      expect(placement.card.width, 306);
      expect(placement.card.center.dx, closeTo(hole.center.dx, 0.01));
      // The frame puts this card at x=64.
      expect(placement.card.left, closeTo(64, 0.01));

      final beak = placement.beak!;
      expect(beak.pointsUp, isTrue);
      // The frame's beak is at x=207, y=101 — 5 clear of the hole, overlapping
      // the card's top edge by 1.
      expect(beak.left, closeTo(207, 0.01));
      expect(beak.top, closeTo(101, 0.01));
    });

    test('reproduces the events-filters frame exactly', () {
      // hole 8,107 386×56 → card 48,177 (190 tall), beak 191,168.
      const hole = Rect.fromLTWH(8, 107, 386, 56);
      final placement = placeTutorialCard(
        screen: screen,
        safeArea: safe,
        hole: hole,
        cardSize: const Size(TutorialMetrics.cardWidth, 190),
      );
      expect(placement.card.left, closeTo(48, 0.01));
      expect(placement.card.top, closeTo(177, 0.01));
      expect(placement.beak!.left, closeTo(191, 0.01));
      expect(placement.beak!.top, closeTo(168, 0.01));
    });

    test('flips above the spotlight when there is no room below', () {
      // A target low on the screen: the card cannot fit under it.
      const hole = Rect.fromLTWH(20, 760, 360, 60);
      final placement = placeTutorialCard(
        screen: screen,
        safeArea: safe,
        hole: hole,
        cardSize: cardSize,
      );

      expect(placement.beak!.pointsUp, isFalse);
      expect(placement.card.bottom, closeTo(hole.top - 14, 0.01));
      // The beak hangs off the card's bottom edge.
      expect(placement.beak!.top, closeTo(placement.card.bottom - 1, 0.01));
    });

    test('clamps the card 12 from the screen edge', () {
      const hole = Rect.fromLTWH(0, 100, 40, 40);
      final placement = placeTutorialCard(
        screen: screen,
        safeArea: safe,
        hole: hole,
        cardSize: cardSize,
      );
      expect(placement.card.left, TutorialMetrics.screenEdge);

      const rightHole = Rect.fromLTWH(362, 100, 40, 40);
      final rightPlacement = placeTutorialCard(
        screen: screen,
        safeArea: safe,
        hole: rightHole,
        cardSize: cardSize,
      );
      expect(
        rightPlacement.card.right,
        screen.width - TutorialMetrics.screenEdge,
      );
    });

    test('clamps the beak 16 inside the card edge', () {
      // The target is hard against the left edge, so the card is clamped and
      // the beak would otherwise sit on its rounded corner.
      const hole = Rect.fromLTWH(0, 100, 40, 40);
      final placement = placeTutorialCard(
        screen: screen,
        safeArea: safe,
        hole: hole,
        cardSize: cardSize,
      );
      final beak = placement.beak!;
      expect(
        beak.left,
        greaterThanOrEqualTo(
          placement.card.left + TutorialMetrics.beakEdgeClamp - 0.01,
        ),
      );
      expect(
        beak.left + TutorialMetrics.beakWidth,
        lessThanOrEqualTo(
          placement.card.right - TutorialMetrics.beakEdgeClamp + 0.01,
        ),
      );
    });

    test('centres the card with no beak when there is no spotlight', () {
      final placement = placeTutorialCard(
        screen: screen,
        safeArea: safe,
        hole: null,
        cardSize: cardSize,
      );
      expect(placement.beak, isNull);
      expect(placement.card.center.dx, closeTo(screen.width / 2, 0.01));
    });
  });

  group('step resolution', () {
    test('groups consecutive steps into pages and counts them', () {
      final resolved = resolveOnboardingSteps(studentOnboardingSteps());

      // The nine drawn coach marks across five pages.
      expect(resolved.length, 8);
      expect(resolved.map((r) => r.step.pageId).toList(), [
        'home',
        'home',
        'events',
        'events',
        'search',
        'chats',
        'profile',
        'profile',
      ]);
      expect(resolved.first.stepsInPage, 2);
      expect(resolved.first.indexInPage, 0);
      expect(resolved[1].indexInPage, 1);
      // Search and Chats are one step each in this cut of the tour.
      expect(resolved[4].stepsInPage, 1);
      expect(resolved[5].stepsInPage, 1);
    });

    test('the eyebrow counts only when the page has more than one step', () {
      final resolved = resolveOnboardingSteps(studentOnboardingSteps());
      expect(resolved.first.eyebrow, 'HOME FEED · STEP 1 OF 2');
      expect(resolved[1].eyebrow, 'HOME FEED · STEP 2 OF 2');
      // A single-step page shows the bare page name, as `tut-announcements`
      // does.
      expect(resolved[4].eyebrow, 'SEARCH');
    });

    test('Back appears from step two of the page, not of the tour', () {
      final resolved = resolveOnboardingSteps(studentOnboardingSteps());
      expect(resolved[0].showBack, isFalse);
      expect(resolved[1].showBack, isTrue);
      expect(resolved[2].showBack, isFalse, reason: 'This Week step 1');
      // `tut-chats-tabs` is the sixth step of the tour and still shows Next
      // alone.
      expect(resolved[5].showBack, isFalse);
    });

    test('the primary pill reads Got it on a page\'s last step', () {
      final resolved = resolveOnboardingSteps(studentOnboardingSteps());
      expect(resolved[0].isPageEnd, isFalse);
      expect(resolved[1].isPageEnd, isTrue);
      expect(resolved[3].isPageEnd, isTrue, reason: 'This Week step 2');
      expect(resolved[5].isPageEnd, isTrue, reason: 'the only Chats step');
    });

    test('dots are hidden on single-step pages', () {
      final resolved = resolveOnboardingSteps(studentOnboardingSteps());
      expect(resolved[0].showProgress, isTrue);
      expect(resolved[4].showProgress, isFalse);
    });

    test('every student step points at a distinct anchor', () {
      final steps = studentOnboardingSteps();
      final keys = steps.map((s) => s.targetKey).toSet();
      expect(keys.length, steps.length);
      // And they are the anchors the screens actually attach.
      expect(
        steps.first.targetKey,
        same(onboardingAnchors.keyFor(OnboardingAnchors.navBar)),
      );
    });
  });

  group('coach card', () {
    Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('is 306 wide, 22-radius, and reads eyebrow/title/body', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OnboardingGuideCard(
            eyebrow: 'HOME FEED · STEP 1 OF 2',
            title: S.tutorialHomeNavTitle,
            body: S.tutorialHomeNavBody,
            progressIndex: 0,
            progressTotal: 2,
            isPageEnd: false,
            onNext: () {},
            onSkip: () {},
          ),
        ),
      );

      final card = tester.getRect(find.byType(TutorialCardShell));
      expect(card.width, TutorialMetrics.cardWidth);

      final decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(TutorialCardShell),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(TutorialMetrics.cardRadius),
      );
      expect(decoration.color, TutorialColors.card);

      expect(find.text('HOME FEED · STEP 1 OF 2'), findsOneWidget);
      expect(find.text(S.tutorialHomeNavTitle), findsOneWidget);
      expect(find.text(S.tutorialHomeNavBody), findsOneWidget);
    });

    testWidgets('progress dots widen the active one to 20', (tester) async {
      await tester.pumpWidget(
        wrap(
          OnboardingGuideCard(
            eyebrow: 'HOME FEED · STEP 2 OF 2',
            title: S.tutorialHomeFollowingTitle,
            body: S.tutorialHomeFollowingBody,
            progressIndex: 1,
            progressTotal: 2,
            isPageEnd: true,
            onNext: () {},
            onSkip: () {},
            onBack: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final dots = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(TutorialProgressDots),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .toList();
      expect(dots.length, 2);

      // Asserted on the widget rather than its rect: an AnimatedContainer's
      // painted box includes its own margin, which is the 5pt gap.
      expect(dots[0].constraints!.maxWidth, TutorialMetrics.dotWidth);
      expect(dots[1].constraints!.maxWidth, TutorialMetrics.dotActiveWidth);
      expect(dots[0].constraints!.maxHeight, TutorialMetrics.dotHeight);
      expect(dots[1].constraints!.maxHeight, TutorialMetrics.dotHeight);
      expect(
        dots[0].margin,
        const EdgeInsets.only(right: TutorialMetrics.dotGap),
      );
      // The last dot carries no trailing gap.
      expect(dots[1].margin, EdgeInsets.zero);

      final active = dots[1].decoration as BoxDecoration;
      final idle = dots[0].decoration as BoxDecoration;
      expect(active.color, TutorialColors.accentInk);
      expect(idle.color, TutorialColors.dotIdle);
    });

    testWidgets('hides the dots and Back on a single-step page tip', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OnboardingGuideCard(
            eyebrow: S.tutorialPageAnnouncements,
            title: S.tutorialAnnouncementsTitle,
            body: S.tutorialAnnouncementsBody,
            isPageEnd: true,
            onNext: () {},
            onSkip: () {},
          ),
        ),
      );

      expect(find.byType(TutorialProgressDots), findsNothing);
      expect(find.text(S.onboardingBack), findsNothing);
      // Skip tour stays reachable, and the pill reads Got it.
      expect(find.text(S.onboardingSkipTour), findsOneWidget);
      expect(find.text(S.tutorialGotIt), findsOneWidget);
      expect(find.text(S.onboardingNext), findsNothing);
    });

    testWidgets('the footer runs Skip … Back Next at 34 tall', (tester) async {
      await tester.pumpWidget(
        wrap(
          OnboardingGuideCard(
            eyebrow: 'PROFILE · STEP 2 OF 2',
            title: S.tutorialProfileClubsTitle,
            body: S.tutorialProfileClubsBody,
            progressIndex: 1,
            progressTotal: 2,
            isPageEnd: true,
            onNext: () {},
            onSkip: () {},
            onBack: () {},
          ),
        ),
      );

      final skip = tester.getRect(find.text(S.onboardingSkipTour));
      final back = tester.getRect(find.byType(TutorialPillButton).first);
      final primary = tester.getRect(find.byType(TutorialPillButton).last);
      final card = tester.getRect(find.byType(TutorialCardShell));

      // Skip on the left, the pills on the right.
      expect(skip.left, lessThan(back.left));
      expect(back.right, lessThan(primary.left));
      expect(back.height, TutorialMetrics.buttonHeight);
      expect(primary.height, TutorialMetrics.buttonHeight);
      // 20pt side padding, 18pt bottom.
      expect(primary.right, closeTo(card.right - TutorialMetrics.padSide, 0.6));
      expect(
        card.bottom - primary.bottom,
        closeTo(TutorialMetrics.padBottom, 0.6),
      );
      expect(find.text(S.tutorialGotIt), findsOneWidget);
    });

    testWidgets('the primary pill is never truncated, in either language', (
      tester,
    ) async {
      // Turkish runs ~20% longer: "Got it" → "Anladım", "Back" → "Geri".
      // A pill sized by flex rather than by its content ellipsises here.
      for (final language in ['en', 'tr']) {
        await localeService.setLanguage(language);
        await tester.pumpWidget(
          wrap(
            OnboardingGuideCard(
              eyebrow: 'HOME FEED · STEP 2 OF 2',
              title: S.tutorialHomeFollowingTitle,
              body: S.tutorialHomeFollowingBody,
              progressIndex: 1,
              progressTotal: 2,
              isPageEnd: true,
              onNext: () {},
              onSkip: () {},
              onBack: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        for (final label in [S.onboardingBack, S.tutorialGotIt]) {
          final painter = TextPainter(
            text: TextSpan(
              text: label,
              style: tutorialPillStyle(const Color(0xFF000000)),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final pill = tester.getRect(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(TutorialPillButton),
            ),
          );
          // Its natural width, give or take sub-pixel text rounding — a
          // truncated pill comes out far narrower than this.
          expect(
            pill.width,
            closeTo(painter.width + (TutorialMetrics.buttonPadding * 2), 2.5),
            reason: '"$label" pill is not its natural width in $language',
          );
        }
      }
      await localeService.setLanguage('en');
    });

    testWidgets('the accent lifts on dark but the pill keeps the burgundy', (
      tester,
    ) async {
      await themeService.setDark(true);
      await tester.pumpWidget(
        wrap(
          OnboardingGuideCard(
            eyebrow: 'CHATS',
            title: S.tutorialChatsTitle,
            body: S.tutorialChatsBody,
            isPageEnd: true,
            onNext: () {},
            onSkip: () {},
          ),
        ),
      );

      expect(TutorialColors.accentInk, const Color(0xFFE8A1B0));
      expect(TutorialColors.accent, const Color(0xFF800020));
      expect(TutorialColors.card, const Color(0xFF18181B));

      final eyebrow = tester.widget<Text>(find.text('CHATS'));
      expect(eyebrow.style!.color, const Color(0xFFE8A1B0));
      expect(eyebrow.style!.fontSize, 10);
      expect(eyebrow.style!.fontWeight, FontWeight.w800);

      final pill = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TutorialPillButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(pill.color, const Color(0xFF800020));
    });

    testWidgets('scrim is 74% in light and 80% in dark', (tester) async {
      await themeService.setDark(false);
      expect(TutorialColors.scrim.a, closeTo(0.74, 0.005));
      expect((TutorialColors.scrim.r * 255).round(), (0x09090B >> 16) & 0xFF);
      await themeService.setDark(true);
      expect(TutorialColors.scrim.a, closeTo(0.80, 0.005));
      expect((TutorialColors.scrim.r * 255).round(), 0);
    });
  });

  group('full-screen moments', () {
    testWidgets('tut-welcome centres a 330 card over the dimmed app', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingWelcomeView(onStartTour: () {}, onSkip: () {}),
          ),
        ),
      );

      final card = tester.getRect(find.byType(TutorialCardShell));
      expect(card.width, TutorialMetrics.fullScreenCardWidth);
      // No cut-out and therefore no beak.
      expect(find.byType(TutorialBeakView), findsNothing);

      expect(find.text(S.tutorialWelcomeEyebrow), findsOneWidget);
      expect(find.text(S.tutorialWelcomeTitle), findsOneWidget);
      expect(find.text(S.tutorialWelcomeBody), findsOneWidget);
      expect(find.text(S.tutorialWelcomeFootnote), findsOneWidget);
      expect(find.text(S.tutorialSkipForNow), findsOneWidget);
      expect(find.text(S.tutorialStartTour), findsOneWidget);

      final title = tester.widget<Text>(find.text(S.tutorialWelcomeTitle));
      expect(title.style!.fontSize, 20);
      // The welcome card is neutral, unlike the finish card.
      final shell = tester.widget<TutorialCardShell>(
        find.byType(TutorialCardShell),
      );
      expect(shell.accented, isFalse);
    });

    testWidgets('tut-finish is accent-washed with an accent footnote', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingFinishView(onReplay: () {}, onDone: () {}),
          ),
        ),
      );

      final shell = tester.widget<TutorialCardShell>(
        find.byType(TutorialCardShell),
      );
      expect(shell.accented, isTrue);
      expect(shell.width, TutorialMetrics.fullScreenCardWidth);

      expect(find.text(S.tutorialFinishEyebrow), findsOneWidget);
      expect(find.text(S.tutorialFinishTitle), findsOneWidget);
      expect(find.text(S.tutorialFinishBody), findsOneWidget);
      expect(find.text(S.tutorialReplayTour), findsOneWidget);
      expect(find.text(S.tutorialExploreClubUp), findsOneWidget);

      final footnote = tester.widget<Text>(find.text(S.tutorialFinishFootnote));
      expect(footnote.style!.color, TutorialColors.accentInk);
      expect(footnote.style!.fontSize, 11);
    });

    testWidgets('Replay the tour restarts, Explore ClubUp completes', (
      tester,
    ) async {
      var replays = 0;
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingFinishView(
              onReplay: () => replays++,
              onDone: () => done++,
            ),
          ),
        ),
      );

      await tester.tap(find.text(S.tutorialReplayTour));
      await tester.pump();
      expect(replays, 1);
      expect(done, 0);

      await tester.tap(find.text(S.tutorialExploreClubUp));
      await tester.pump();
      expect(done, 1);
    });
  });
}
