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
  tearDown(() async {
    await authService.logout();
    clubs.clear();
    events.clear();
  });

  testWidgets('the edit wizard saves and returns to its caller', (
    tester,
  ) async {
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

    await tester.enterText(find.byType(TextField).first, 'Edited in wizard');
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
    expect(events.single.title, 'Edited in wizard');
    expect(find.text('Could not save changes.'), findsNothing);
  });
}

class _FakeEventService extends SupabaseEventService {
  @override
  Future<Event> updateEvent(Event event, {String? previousImagePath}) async {
    return event;
  }
}
