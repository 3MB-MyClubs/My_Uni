import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/rsvp_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/widgets/rsvp_button.dart';

/// Verifies the RSVP button renders cleanly in both states when placed
/// full-width like the event detail CTA: "Let's Go" before, Cancel-only after.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RSVP → cancel-only attending UI', (tester) async {
    authService.logout();
    await hiveBootstrap.initialize();
    await contentStore.initialize();
    await themeService.initialize();
    await themeService.setDark(false);
    // Sign in as a club admin so toggle() skips the Supabase write path
    // (unavailable headless); this test only exercises the button's UI.
    authService.login('kuacm@ku.edu.tr', '11111111');

    final now = DateTime.now();
    final event = Event(
      id: 'evt_rsvp_demo',
      clubId: 'c1',
      title: 'AI & Ethics Symposium',
      description: 'An evening symposium on the ethics of AI.',
      dateTime: now.add(const Duration(days: 3, hours: 2)),
      endTime: now.add(const Duration(days: 3, hours: 4)),
      location: 'Sevgi Gönül Auditorium',
      attendeeUserIds: const ['u2', 'u3'],
    );
    events.add(event); // rsvpStore.toggle looks the event up in the global list
    rsvpStore.seed(event.id, false);

    // Mimic the event-detail sticky CTA: the button owns the full width.
    // event: null → skip device-calendar sync (plugin unavailable headless).
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RsvpButton(
                eventId: event.id,
                color: AppColors.primaryRed,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('rsvp-01-before');
    expect(find.text("Let's Go"), findsOneWidget);

    await tester.tap(find.text("Let's Go"));
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('rsvp-02-attending');

    // Cancel-only: no redundant "you're going" affirmation in this slot.
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text("You're going"), findsNothing);
    expect(tester.takeException(), isNull);

    // Toggle back off → returns to the primary CTA cleanly.
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("Let's Go"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Attending state renders at full height', (tester) async {
    authService.logout();
    await hiveBootstrap.initialize();
    await contentStore.initialize();
    await themeService.initialize();
    await themeService.setDark(false);
    authService.login('kuacm@ku.edu.tr', '11111111');

    const id = 'evt_rsvp_render';
    rsvpStore.seed(id, true); // start in the attending state, no taps/plugins

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RsvpButton(eventId: id, color: AppColors.primaryRed),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('rsvp-03-attending-render');
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
