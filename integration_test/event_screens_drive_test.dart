import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/screens/create_event_screen.dart';
import 'package:flutter_application_1/screens/event_detail_screen.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/message_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';

/// Drives the redesigned event flow:
///  A) Club creates event — the form with Speakers / Registration / Capacity.
///  B) Attendee sees event — full detail with capacity bar, registration card,
///     speakers, and the sticky CTA (bell + Register + Add to calendar).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot() async {
    await messageService.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
  }

  Widget wrap(Widget home) => ListenableBuilder(
        listenable: themeService,
        builder: (context, _) => ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: themeService.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(brightness: Brightness.light),
            darkTheme: ThemeData(brightness: Brightness.dark),
            home: home,
          ),
        ),
      );

  testWidgets('Club creates event — form with new sections', (tester) async {
    await boot();
    authService.login('kuacm@ku.edu.tr', '11111111'); // KUACM club admin

    await tester.pumpWidget(wrap(const CreateEventScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('evt-01-create-top');

    // Scroll down to reveal Speakers / Registration / Capacity.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('evt-02-create-sections');
    expect(find.text('Speakers'), findsWidgets);
    expect(find.text('Registration'), findsOneWidget);
    expect(find.text('Capacity'), findsOneWidget);
  });

  testWidgets('Attendee sees event — full detail + sticky CTA', (tester) async {
    await boot();
    authService.login('htuncay23@ku.edu.tr'); // a student attendee

    final now = DateTime.now();
    final event = Event(
      id: 'evt_demo',
      clubId: 'c1',
      title: 'Atatürk Memorial Panel',
      description:
          'A moderated panel marking the legacy of Mustafa Kemal Atatürk — '
          'four faculty speakers on the founding ideals of the Republic, '
          'followed by an open Q&A. Doors open early; seating is first-come.',
      dateTime: now.add(const Duration(days: 3, hours: 2)),
      endTime: now.add(const Duration(days: 3, hours: 4)),
      location: 'SOS Amphitheatre',
      attendeeUserIds: const ['u1', 'u2', 'u3', 'u4', 'u6'],
      tags: const ['Panel', 'Cultural', 'Free entry'],
      capacity: 120,
      registrationUrl: 'https://forms.gle/kuadk-panel',
      speakers: const [
        EventSpeaker(name: 'Prof. Elif Yıldız', role: 'History', linkedin: 'https://linkedin.com/in/elif-yildiz'),
        EventSpeaker(name: 'Dr. Mert Kaya', role: 'Pol. Sci.', linkedin: 'https://linkedin.com/in/mert-kaya'),
        EventSpeaker(name: 'Prof. Selin Aydın', role: 'Law'),
      ],
      schedule: [
        EventSlot(time: now.add(const Duration(days: 3, hours: 2)), title: 'Opening remarks', subtitle: 'Club president'),
        EventSlot(time: now.add(const Duration(days: 3, hours: 3)), title: 'Panel', subtitle: '4 speakers', isHighlighted: true),
      ],
    );

    await tester.pumpWidget(wrap(EventDetailScreen(event: event, color: AppColors.primaryRed)));
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // Sticky CTA is present: Register + Add to Calendar beneath.
    expect(find.textContaining('Add to Calendar'), findsOneWidget);
    await binding.takeScreenshot('evt-03-detail-top');

    // Scroll to reveal capacity, registration, speakers.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -360));
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('evt-04-detail-body');
    expect(find.text('Registration'), findsWidgets);
    expect(find.text('SPEAKERS'), findsOneWidget);
  });
}
