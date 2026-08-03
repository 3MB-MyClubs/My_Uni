import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/onboarding/starter_checklist_service.dart';
import 'package:flutter_application_1/onboarding/widgets/starter_checklist_card.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';

/// The profile screen inserts the checklist card as `const`, so a rebuild of
/// the app root does not reach it — the card has to watch the locale itself or
/// its copy stays frozen in whichever language was active when it first built.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('checklist_locale_test_');
    Hive.init(tempDir.path);
    await chatStore.initialize();
    users.add(
      User(
        id: 'checklist-user',
        name: 'Deniz',
        email: 'checklist.user@ku.edu.tr',
        password: '111111',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );
  });

  tearDownAll(() async {
    users.removeWhere((user) => user.id == 'checklist-user');
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('card copy swaps live when the language changes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    expect(authService.login('checklist.user@ku.edu.tr', '111111'), isTrue);
    await starterChecklistService.initialize();
    await starterChecklistService.startFor(authService.currentUser!.id);
    addTearDown(
      () => localeService.setLanguage(LocaleService.defaultLanguageCode),
    );

    await localeService.setLanguage('en');
    // `const` on purpose — this mirrors how the profile screen embeds the card.
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: localeService,
        builder: (context, _) =>
            const MaterialApp(home: Scaffold(body: StarterChecklistCard())),
      ),
    );

    final english = S.checklistTitle;
    expect(find.text(english), findsOneWidget);
    expect(find.text(S.checklistSubtitle), findsOneWidget);
    expect(find.text(S.checklistFollowClub), findsOneWidget);
    expect(find.text(S.checklistRsvpEvent), findsOneWidget);
    expect(find.text(S.checklistSayHi), findsOneWidget);

    await localeService.setLanguage('tr');
    await tester.pump();

    final turkish = S.checklistTitle;
    expect(turkish, isNot(english));
    expect(find.text(english), findsNothing);
    expect(find.text(turkish), findsOneWidget);
    expect(find.text(S.checklistSubtitle), findsOneWidget);
    expect(find.text(S.checklistFollowClub), findsOneWidget);
    expect(find.text(S.checklistRsvpEvent), findsOneWidget);
    expect(find.text(S.checklistSayHi), findsOneWidget);
  });
}
