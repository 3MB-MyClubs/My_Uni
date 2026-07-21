import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/screens/explore_screen.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/screens/student_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/user_avatar.dart';
import 'package:flutter_application_1/widgets/student_campus_profile.dart';

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
      ProviderScope(
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
          home: ClubProfileScreen(club: clubs.first, color: Colors.red),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(ClubProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ClubProfileScreen also renders in light mode', (tester) async {
    await themeService.setDark(false);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
          home: ClubProfileScreen(club: clubs.first, color: Colors.red),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(ClubProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ExploreScreen opens a club profile without a render exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,home: ExploreScreen())),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text(clubs.first.name).first);
    await tester.pumpAndSettle();

    expect(find.byType(ClubProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Find People previews up to 10 random profiles and searches', (
    tester,
  ) async {
    await tester.pumpWidget(
<<<<<<< Updated upstream
      ProviderScope(child: MaterialApp(home: ExploreScreen())),
=======
      ProviderScope(
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,home: ExploreScreen(initialTabIndex: 2)),
      ),
>>>>>>> Stashed changes
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Find People'));
    await tester.pumpAndSettle();

    final previewAvatars = find.byType(UserAvatar).evaluate().length;
    expect(previewAvatars, greaterThan(0));
    expect(previewAvatars, lessThanOrEqualTo(10));

    await tester.enterText(
      find.widgetWithText(TextField, 'Search by name or surname…'),
      users.first.name.split(' ').first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(UserAvatar), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProfileScreen renders in light mode for a logged-in user', (
    tester,
  ) async {
    await themeService.setDark(false);
    authService.login(users.first.email, users.first.password);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,home: ProfileScreen())),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student profile uses the dark background in dark mode', (
    tester,
  ) async {
    authService.login(users.first.email, users.first.password);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,home: ProfileScreen())),
    );

    await tester.pumpAndSettle();

    expect(find.byType(StudentProfileScreen), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(StudentProfileScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, StudentCampusPalette.background);
    expect(tester.takeException(), isNull);
  });
}
