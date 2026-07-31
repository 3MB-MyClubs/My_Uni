import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_clubup_profile.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(onLogout: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() async {
    await authService.logout();
    users.removeWhere((user) => user.email == 'settings.guard@ku.edu.tr');
    removeClubUpMockProfile();
  });

  testWidgets('moderation Settings entry is visible to ClubUp', (tester) async {
    authService.setClubAdmin(ensureClubUpMockProfile());
    await pumpSettings(tester);

    expect(find.text(S.moderationCenter), findsOneWidget);
  });

  testWidgets('moderation Settings entry is hidden from other club admins', (
    tester,
  ) async {
    authService.setClubAdmin(
      AppAdmin(
        id: 'another-club',
        name: 'Another Club',
        email: 'another@ku.edu.tr',
        password: '22222222',
      ),
    );
    await pumpSettings(tester);

    expect(find.text(S.moderationCenter), findsNothing);
  });

  testWidgets('moderation Settings entry is hidden from students', (
    tester,
  ) async {
    users.add(
      User(
        id: 'settings-guard-student',
        name: 'Settings Guard Student',
        email: 'settings.guard@ku.edu.tr',
        password: '135790',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );
    expect(authService.login('settings.guard@ku.edu.tr', '135790'), isTrue);
    await pumpSettings(tester);

    expect(find.text(S.moderationCenter), findsNothing);
  });
}
