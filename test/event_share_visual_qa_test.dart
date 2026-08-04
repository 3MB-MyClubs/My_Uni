import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/event_share_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('capture event share sheet ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => themeService.setDark(false, persistToAccount: false));
      await themeService.setDark(dark, persistToAccount: false);

      final start = DateTime(2026, 9, 17, 18, 30);
      final event = Event(
        id: 'share-visual-event',
        clubId: 'share-visual-club',
        title: 'Atatürk Memorial Panel',
        description: 'A moderated faculty panel followed by an open Q&A.',
        dateTime: start,
        endTime: start.add(const Duration(hours: 2)),
        location: 'SOS Amphitheatre',
        attendeeUserIds: const [],
      );
      final people = [
        _person('friend-1', 'Ceren Levent'),
        _person('friend-2', 'Zeynep Arslan'),
        _person('friend-3', 'Tolga Kurt'),
        _person('friend-4', 'Mina Demir'),
        _person('friend-5', 'Ece Yılmaz'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFF9E2045)),
                    Center(
                      child: FilledButton(
                        onPressed: () => showEventShareSheet(
                          context: context,
                          event: event,
                          people: people,
                          sentUserIds: const {'friend-4'},
                          onInvite: (_) {},
                        ),
                        child: const Text('Share event'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Share event'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile('../design-qa-share-${dark ? 'dark' : 'light'}.png'),
      );
    });
  }
}

User _person(String id, String name) => User(
  id: id,
  name: name,
  email: '$id@ku.edu.tr',
  password: '',
  role: 'student',
  subscribedClubIds: const [],
);
