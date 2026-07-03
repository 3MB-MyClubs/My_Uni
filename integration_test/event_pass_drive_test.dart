import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:flutter_application_1/screens/event_detail_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/checkin_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/rsvp_store.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/widgets/event_pass_sheet.dart';

/// Phase 3: RSVP'd students get a QR Event Pass; check-ins are recorded and
/// scanned payloads parse/validate correctly.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RSVPd student can open their QR Event Pass', (tester) async {
    authService.logout();
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await checkinStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
    authService.login('alice@ku.edu.tr', '111111');

    final event = events.firstWhere(
      (e) => e.endTime.isAfter(DateTime.now()),
    );
    if (!event.attendeeUserIds.contains('u1')) {
      event.attendeeUserIds.add('u1');
    }
    rsvpStore.seed(event.id, true);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EventDetailScreen(
            event: event,
            color: const Color(0xFF8C1D40),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    // The QR pass button sits next to the RSVP CTA.
    final passButton = find.byIcon(Icons.qr_code_2_rounded);
    expect(passButton, findsOneWidget);
    await tester.tap(passButton);
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Event Pass'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('phase3-event-pass');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pass payloads parse and check-ins record + toggle', (
    tester,
  ) async {
    final event = events.first;

    // Payload round-trip.
    final payload = eventPassPayload(event.id, 'u2');
    final parsed = parseEventPassPayload(payload);
    expect(parsed, isNotNull);
    expect(parsed!.$1, event.id);
    expect(parsed.$2, 'u2');
    expect(parseEventPassPayload('https://random.link'), isNull);
    expect(parseEventPassPayload('kuqr:v9:a:b'), isNull);

    // Manual check-in toggling (what the scanner + admin list drive).
    expect(checkinStore.isCheckedIn(event.id, 'u2'), isFalse);
    await checkinStore.toggle(
      eventId: event.id,
      userId: 'u2',
      actorId: 'c1',
      method: 'qr',
    );
    expect(checkinStore.isCheckedIn(event.id, 'u2'), isTrue);
    expect(checkinStore.countFor(event.id), 1);

    await checkinStore.toggle(
      eventId: event.id,
      userId: 'u2',
      actorId: 'c1',
    );
    expect(checkinStore.isCheckedIn(event.id, 'u2'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
