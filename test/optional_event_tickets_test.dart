import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/screens/create_event_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/supabase_event_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ticket setting survives persistence and copying; legacy defaults off',
    () {
      final event = Event(
        id: 'e',
        clubId: 'c',
        title: 'Test',
        description: '',
        dateTime: DateTime(2030),
        endTime: DateTime(2030, 1, 1, 1),
        location: '',
        attendeeUserIds: [],
        isTicketed: true,
      );
      expect(Event.fromMap(event.toMap()).isTicketed, true);
      expect(event.copyWith(title: 'Changed').isTicketed, true);
      expect(event.copyWith(isTicketed: false).isTicketed, false);
      final legacy = event.toMap()..remove('isTicketed');
      expect(Event.fromMap(legacy).isTicketed, false);
    },
  );

  for (final initiallyTicketed in [false, true]) {
    tearDown(() async {
      await authService.logout();
      clubs.clear();
      events.clear();
    });

    testWidgets(
      'ticket toggle saves from $initiallyTicketed to ${!initiallyTicketed}',
      (tester) async {
        final club = Club(
          id: 'club-edit-wizard',
          name: 'Test Club',
          description: '',
          adminUserIds: const [],
        );
        final event = Event(
          id: 'event-edit-wizard',
          clubId: club.id,
          title: 'Original event',
          description: 'Event edit regression fixture',
          dateTime: DateTime(2026, 9, 1, 12),
          endTime: DateTime(2026, 9, 1, 14),
          location: 'Campus',
          attendeeUserIds: const [],
          isTicketed: initiallyTicketed,
        );
        clubs.add(club);
        events.add(event);
        authService.setClubAdmin(
          AppAdmin(
            id: club.id,
            name: club.name,
            email: 'club@ku.edu.tr',
            password: '',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateEventScreen(
                            existing: event,
                            eventService: _FakeEventService(),
                          ),
                        ),
                      ),
                      child: const Text('Open editor'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open editor'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Edit Event'), findsOneWidget);

        final toggle = find.byKey(const ValueKey('event-wizard-ticketed'));
        await tester.scrollUntilVisible(
          toggle,
          250,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('event-wizard-step-details')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(tester.widget<SwitchListTile>(toggle).value, initiallyTicketed);
        await tester.tap(toggle);
        await tester.pump();
        expect(tester.widget<SwitchListTile>(toggle).value, !initiallyTicketed);
        if (initiallyTicketed) {
          expect(
            find.textContaining('Turning this off revokes'),
            findsOneWidget,
          );
        }

        // The redesigned wizard is Details → Speakers & Tags → Programme →
        // Event Preview (`wz-*`), and only the preview's CTA commits.
        // `S.*` follows localeService (Turkish by default in tests) while
        // AppLocalizations resolves to en, so the CTAs are asserted through S.
        for (final cta in [
          S.eventWizardNextStep,
          S.eventWizardNextStep,
          S.eventWizardPreviewBadge,
        ]) {
          await tester.tap(find.text(cta));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.tap(find.text(S.eventWizardSaveChanges));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Open editor'), findsOneWidget);
        expect(events.single.isTicketed, !initiallyTicketed);
        expect(find.text('Could not save changes.'), findsNothing);
      },
    );
  }

  testWidgets('new event ticket toggle defaults off', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CreateEventScreen(eventService: _FakeEventService()),
        ),
      ),
    );
    final toggle = find.byKey(const ValueKey('event-wizard-ticketed'));
    await tester.scrollUntilVisible(
      toggle,
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('event-wizard-step-details')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.widget<SwitchListTile>(toggle).value, false);
    expect(find.textContaining('issued manually'), findsOneWidget);
  });
}

class _FakeEventService extends SupabaseEventService {
  @override
  Future<Event> updateEvent(Event event, {String? previousImagePath}) async {
    return event;
  }
}
