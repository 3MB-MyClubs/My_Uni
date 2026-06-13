import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/screens/explore_screen.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/screens/student_profile_screen.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';

void main() {
  setUp(() async {
    authService.logout();
    await themeService.setDark(true);
  });

  tearDown(() async {
    authService.logout();
    await themeService.setDark(true);
  });

  testWidgets('ClubProfileScreen builds from a club card route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClubProfileScreen(club: clubs.first, color: Colors.red),
      ),
    );

    await tester.pump();

    expect(find.byType(ClubProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ClubProfileScreen also renders in light mode', (tester) async {
    await themeService.setDark(false);

    await tester.pumpWidget(
      MaterialApp(
        home: ClubProfileScreen(club: clubs.first, color: Colors.red),
      ),
    );

    await tester.pump();

    expect(find.byType(ClubProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ExploreScreen opens a club profile without a render exception', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));

    await tester.pumpAndSettle();

    await tester.tap(find.text(clubs.first.name).first);
    await tester.pumpAndSettle();

    expect(find.byType(ClubProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProfileScreen renders in light mode for a logged-in user', (
    tester,
  ) async {
    await themeService.setDark(false);
    authService.login(users.first.email, users.first.password);

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));

    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student profile uses the dark background in dark mode', (
    tester,
  ) async {
    authService.login(users.first.email, users.first.password);

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));

    await tester.pumpAndSettle();

    expect(find.byType(StudentProfileScreen), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(StudentProfileScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, DarkColors.background);
    expect(tester.takeException(), isNull);
  });
}
