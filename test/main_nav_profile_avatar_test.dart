import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/services/account_switcher_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/widgets/club_avatar.dart';
import 'package:flutter_application_1/widgets/user_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Widget _app() => const ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MainNavScreen(isAdmin: false),
  ),
);

void main() {
  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'main_nav_profile_avatar_',
    );
    Hive.init(tempDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDirectory.existsSync()) tempDirectory.deleteSync(recursive: true);
  });

  setUp(() {
    authService.logout();
    accountSwitcherService.clear();
  });

  tearDown(() {
    authService.logout();
    accountSwitcherService.clear();
  });

  testWidgets('student profile nav item uses the shared user avatar', (
    tester,
  ) async {
    expect(
      authService.signUp(
        'Nav Avatar Student',
        'nav.avatar.student@ku.edu.tr',
        '135790',
      ),
      isTrue,
    );
    final user = authService.currentUser!;
    addTearDown(
      () => users.removeWhere((candidate) => candidate.id == user.id),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app());
    await tester.pump();

    final nav = find.byKey(const ValueKey('mobile-bottom-navigation'));
    final avatar = find.descendant(of: nav, matching: find.byType(UserAvatar));
    expect(avatar, findsOneWidget);
    expect(
      find.byKey(ValueKey('profile-nav-user-avatar-${user.id}')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('club profile nav item uses the shared club avatar', (
    tester,
  ) async {
    const adminId = 'nav-avatar-club';
    final admin = AppAdmin(
      id: adminId,
      name: 'Nav Avatar Club',
      email: 'nav.avatar.club@ku.edu.tr',
      password: '11111111',
    );
    final club = Club(
      id: adminId,
      name: admin.name,
      description: '',
      adminUserIds: const [adminId],
    );
    clubs.add(club);
    clubAdmins.add(admin);
    authService.setClubAdmin(admin);
    addTearDown(() {
      clubAdmins.removeWhere((candidate) => candidate.id == adminId);
      clubs.removeWhere((candidate) => candidate.id == adminId);
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app());
    await tester.pump();

    final nav = find.byKey(const ValueKey('desktop-navigation-sidebar'));
    final avatar = find.descendant(of: nav, matching: find.byType(ClubAvatar));
    expect(avatar, findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-nav-club-avatar-nav-avatar-club')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
