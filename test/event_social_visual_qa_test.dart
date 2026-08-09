import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/event_detail_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('capture event social sections', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() async {
      authService.logout();
      await themeService.setDark(false, persistToAccount: false);
    });

    tester.view.physicalSize = const Size(748, 1218);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await themeService.setDark(true, persistToAccount: false);
    users.clear();
    events.clear();
    users.add(
      User(
        id: 'visual-current-student',
        name: 'Current Student',
        email: 'visual.qa@ku.edu.tr',
        password: '135790',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );
    authService.login('visual.qa@ku.edu.tr', '135790');

    for (final entry in const [
      ('attendee-1', 'Ceren Levent'),
      ('attendee-2', 'Zeynep Arslan'),
      ('attendee-3', 'Tolga Kurt'),
      ('attendee-4', 'Mina Demir'),
      ('friend-1', 'Ceren Levent'),
      ('friend-2', 'Zeynep Arslan'),
      ('friend-3', 'Tolga Kurt'),
    ]) {
      users.add(
        User(
          id: entry.$1,
          name: entry.$2,
          email: '${entry.$1}@ku.edu.tr',
          password: '',
          role: 'student',
          subscribedClubIds: const [],
        ),
      );
    }
    userState.replaceFollowedUsers(const [
      'attendee-1',
      'attendee-2',
      'attendee-3',
      'attendee-4',
    ]);
    userState.setMajor('friend-1', 'Also in KUADK');
    userState.setMajor('friend-2', 'Going · Econ 21');
    userState.setMajor('friend-3', '2 mutual clubs');

    final start = DateTime.now().add(const Duration(days: 5));
    final event = Event(
      id: 'visual-event',
      clubId: 'visual-club',
      title: 'Atatürk Memorial Panel',
      description: 'A moderated faculty panel followed by an open Q&A.',
      dateTime: start,
      endTime: start.add(const Duration(hours: 2)),
      location: 'SOS Amphitheatre',
      attendeeUserIds: [
        for (var index = 1; index <= 47; index++) 'attendee-$index',
      ],
      speakers: const [
        EventSpeaker(name: 'Prof. Elif Yıldız', role: 'History'),
        EventSpeaker(name: 'Dr. Mert Kaya', role: 'Pol. Sci.'),
        EventSpeaker(name: 'Prof. Selin Aydın', role: 'Law'),
        EventSpeaker(name: 'Prof. Can Erdem', role: 'Sociology'),
      ],
    );
    events.add(event);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          darkTheme: ThemeData(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EventDetailScreen(event: event, color: const Color(0xFF9E2045)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('../design-qa-implementation.png'),
    );
  });
}
