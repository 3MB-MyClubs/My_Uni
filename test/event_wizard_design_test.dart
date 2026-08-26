import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/screens/create_event_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/event_wizard_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The EVENT CREATION flow — the `wz-*` chain from `light-details` 310:11 to
/// **Publish Event** on `324:978`.
void main() {
  const clubId = 'event-wizard-club';

  setUp(() async {
    await themeService.setDark(false);
    await localeService.setLanguage('en');
    clubs
      ..clear()
      ..add(
        Club(
          id: clubId,
          name: 'Rooftop Collective',
          description: 'EVENT WIZARD fixture',
          adminUserIds: const [clubId],
        ),
      );
    events.clear();
    authService.setClubAdmin(
      AppAdmin(
        id: clubId,
        name: 'Rooftop Collective',
        email: 'rooftop@ku.edu.tr',
        password: '',
      ),
    );
  });

  tearDown(() async {
    await authService.logout();
    clubs.clear();
    events.clear();
    await themeService.setDark(false);
  });

  /// An implicit animation only starts on the frame after the state change,
  /// so a single `pump(duration)` captures t≈0 and the page never moves.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  Future<void> pumpWizard(WidgetTester tester, {Event? existing}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(localeService.languageCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CreateEventScreen(existing: existing),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('step 1 draws the frame: cover, fields, Starts and Ends', (
    tester,
  ) async {
    await pumpWizard(tester);

    expect(find.byType(EventWizardTopBar), findsOneWidget);
    expect(find.text(S.eventWizardStepOneTitle), findsOneWidget);
    expect(find.text(S.eventWizardStepOf(1, 3)), findsOneWidget);

    // `photo-uploader` 315:32 and the three text fields.
    expect(find.byKey(const ValueKey('event-wizard-cover')), findsOneWidget);
    expect(find.text(S.eventWizardCoverHint), findsOneWidget);
    expect(find.text(S.eventWizardTitleLabel), findsOneWidget);
    expect(find.text(S.eventWizardLocationLabel), findsOneWidget);
    expect(find.text(S.eventWizardDescriptionLabel), findsOneWidget);

    // `multi-day-dates` 315:44 — Starts and Ends, each Date + Time, all four
    // empty until picked.
    expect(find.text(S.eventWizardStarts), findsOneWidget);
    expect(find.text(S.eventWizardEnds), findsOneWidget);
    expect(find.text(S.eventWizardDate), findsNWidgets(2));
    expect(find.text(S.eventWizardTime), findsNWidgets(2));
    expect(find.text(S.eventWizardSelectStartDate), findsOneWidget);
    expect(find.text(S.eventWizardSelectEndDate), findsOneWidget);

    expect(find.text(S.eventWizardNextStep), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event inputs have one flat surface and no focus frame', (
    tester,
  ) async {
    await themeService.setDark(true);
    await pumpWizard(tester);

    final titleFieldFinder = find.byKey(
      const ValueKey('event-wizard-title-field'),
    );
    final titleField = tester.widget<TextField>(titleFieldFinder);
    expect(titleField.decoration?.filled, isFalse);
    expect(titleField.decoration?.fillColor, Colors.transparent);
    expect(titleField.decoration?.border, InputBorder.none);
    expect(titleField.decoration?.enabledBorder, InputBorder.none);
    expect(titleField.decoration?.focusedBorder, InputBorder.none);

    final inputBoxFinder = find
        .ancestor(
          of: titleFieldFinder,
          matching: find.byType(EventWizardInputBox),
        )
        .first;
    final inputContainer = tester.widget<Container>(
      find
          .descendant(of: inputBoxFinder, matching: find.byType(Container))
          .first,
    );
    final inputDecoration = inputContainer.decoration! as BoxDecoration;
    expect(inputDecoration.color, EventWizardColors.page);
    final border = inputDecoration.border! as Border;
    expect(border.top.color, EventWizardColors.border);
    expect(border.top.width, 1);

    await tester.tap(titleFieldFinder);
    await tester.pump();

    final focusedField = tester.widget<TextField>(titleFieldFinder);
    expect(focusedField.decoration?.focusedBorder, InputBorder.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an incomplete step 1 explains itself instead of greying out', (
    tester,
  ) async {
    await pumpWizard(tester);

    // The frame draws the CTA solid in every state, so it is always tappable.
    await tester.tap(find.text(S.eventWizardNextStep));
    await settle(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    // Still on step 1.
    expect(find.text(S.eventWizardStepOf(1, 3)), findsOneWidget);
  });

  testWidgets('the date sheet is the frame grid, and it fills the cell', (
    tester,
  ) async {
    await pumpWizard(tester);

    await tester.tap(find.byKey(const ValueKey('event-wizard-start-date')));
    await settle(tester);

    // `select-date` 319:7 — a month grid with a Done pill, not showDatePicker.
    expect(find.text(S.eventWizardSelectDate), findsOneWidget);
    expect(
      find.byKey(const ValueKey('event-wizard-month-next')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('event-wizard-sheet-done')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('event-wizard-day-15')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('event-wizard-sheet-done')));
    await settle(tester);

    expect(find.text(S.eventWizardSelectStartDate), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the time sheet is a wheel with the frame chrome', (
    tester,
  ) async {
    await pumpWizard(tester);

    await tester.tap(find.byKey(const ValueKey('event-wizard-start-time')));
    await settle(tester);

    expect(find.text(S.eventWizardSelectStartTime), findsOneWidget);
    expect(
      find.byKey(const ValueKey('event-wizard-hour-wheel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('event-wizard-minute-wheel')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('event-wizard-sheet-done')));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('step 2 adds tags and a speaker through the modal', (
    tester,
  ) async {
    final start = DateTime.now().add(const Duration(days: 2));
    await pumpWizard(
      tester,
      existing: Event(
        id: 'event-wizard-existing',
        clubId: clubId,
        title: 'Sunset Rooftop Sessions',
        description: 'Music and skyline views.',
        dateTime: start,
        endTime: start.add(const Duration(hours: 3)),
        location: 'Sky Terrace',
        attendeeUserIds: const [],
      ),
    );

    await tester.tap(find.text(S.eventWizardNextStep));
    await settle(tester);
    expect(find.text(S.eventWizardStepTwoTitle), findsOneWidget);
    expect(find.text(S.eventWizardStepOf(2, 3)), findsOneWidget);

    // `tags-section` 310:84 — free text plus Add, then a removable chip.
    await tester.enterText(
      find.byKey(const ValueKey('event-wizard-tag-field')),
      'Networking',
    );
    await tester.tap(find.byKey(const ValueKey('event-wizard-tag-add')));
    await settle(tester);
    expect(find.byType(EventWizardTagChip), findsOneWidget);

    // `add-speaker-modal` 325:154.
    await tester.tap(find.byKey(const ValueKey('event-wizard-add-speaker')));
    await settle(tester);
    expect(find.text(S.eventWizardFullName), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('event-wizard-speaker-name')),
      'Sarah Chen',
    );
    await tester.tap(find.byKey(const ValueKey('event-wizard-save-speaker')));
    await settle(tester);

    expect(find.byType(EventWizardSpeakerCard), findsOneWidget);
    expect(find.text('Sarah Chen'), findsOneWidget);
    // With one speaker the dashed row becomes "Add another speaker".
    expect(find.text(S.eventWizardAddAnotherSpeaker), findsOneWidget);

    // `add-registration-link-btn` 310:121 reveals the field of 325:6.
    expect(find.text(S.eventWizardRegistrationLabel), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('event-wizard-add-registration')),
    );
    await settle(tester);
    expect(find.text(S.eventWizardRegistrationLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('step 3 lists sessions and the live preview, then previews', (
    tester,
  ) async {
    final start = DateTime.now().add(const Duration(days: 2));
    await pumpWizard(
      tester,
      existing: Event(
        id: 'event-wizard-existing-2',
        clubId: clubId,
        title: 'Sunset Rooftop Sessions',
        description: 'Music and skyline views.',
        dateTime: start,
        endTime: start.add(const Duration(hours: 3)),
        location: 'Sky Terrace',
        attendeeUserIds: const [],
        tags: const ['Networking'],
        speakers: const [EventSpeaker(name: 'Sarah Chen', role: 'DJ')],
      ),
    );

    await tester.tap(find.text(S.eventWizardNextStep));
    await settle(tester);
    await tester.tap(find.text(S.eventWizardNextStep));
    await settle(tester);

    expect(find.text(S.eventWizardStepThreeTitle), findsOneWidget);
    expect(find.text(S.eventWizardProgrammeSchedule), findsOneWidget);
    expect(find.text(S.eventWizardNoSessions), findsOneWidget);
    // `Live Event Preview`, the card 325:485 puts under the list.
    expect(
      find.byKey(const ValueKey('event-wizard-live-preview')),
      findsOneWidget,
    );

    // `add-session` 325:485.
    await tester.tap(find.byKey(const ValueKey('event-wizard-add-session')));
    await settle(tester);
    expect(find.text(S.eventWizardSessionName), findsOneWidget);
    // The frame's End Time field has no model column behind it.
    expect(find.text(S.eventWizardStartTime), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('event-wizard-session-name')),
      'Opening & Welcome Lounge',
    );
    await tester.tap(find.byKey(const ValueKey('event-wizard-save-session')));
    await settle(tester);

    expect(find.byType(EventWizardSessionRow), findsOneWidget);
    expect(find.text('Opening & Welcome Lounge'), findsOneWidget);

    // Editing reaches the preview through "Preview", never a second commit.
    await tester.tap(find.text(S.eventWizardPreviewBadge).last);
    await settle(tester);

    expect(find.text(S.eventWizardPreviewTitle), findsOneWidget);
    expect(
      find.byKey(const ValueKey('event-wizard-preview-body')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('event-wizard-preview-title')),
      findsOneWidget,
    );
    expect(find.text(S.eventWizardAbout), findsOneWidget);
    expect(find.text(S.eventWizardSaveChanges), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pickers fit a real 402x874 window, unclipped', (
    tester,
  ) async {
    // The wizard's own tests run tall; this one is the real phone height, where
    // a sheet that sizes itself wrongly clips its wheel.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(localeService.languageCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CreateEventScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byKey(const ValueKey('event-wizard-start-time')));
    await settle(tester);
    final wheel = find.byKey(const ValueKey('event-wizard-hour-wheel'));
    expect(wheel, findsOneWidget);
    final wheelRect = tester.getRect(wheel);
    expect(wheelRect.height, 220);
    // The whole wheel has to be on screen, not clipped by the screen edge.
    expect(wheelRect.bottom, lessThanOrEqualTo(874));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('event-wizard-sheet-done')));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('event-wizard-start-date')));
    await settle(tester);
    final grid = find.byType(GridView);
    expect(grid, findsOneWidget);
    expect(tester.getRect(grid).bottom, lessThanOrEqualTo(874));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode lifts the accent to the section pink', (tester) async {
    await themeService.setDark(true);
    addTearDown(() => themeService.setDark(false));
    await pumpWizard(tester);

    // `310:251` paints every button and link `#FA526B`, not `#800020`.
    expect(EventWizardColors.accent, const Color(0xFFFA526B));
    expect(EventWizardColors.page, const Color(0xFF121212));
    expect(EventWizardColors.card, const Color(0xFF1E1E1E));
    expect(EventWizardColors.border, const Color(0xFF27272A));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF121212));

    await themeService.setDark(false);
    expect(EventWizardColors.accent, const Color(0xFF800020));
  });
}
