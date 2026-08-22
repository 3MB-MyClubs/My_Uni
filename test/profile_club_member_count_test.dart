import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/screens/student_profile_screen.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const clubId = 'profile-member-count-club';
  late Club club;
  late User signedInUser;

  setUp(() {
    club = Club(
      id: clubId,
      name: 'Membership Test Club',
      description: 'Tests the profile member count source.',
      adminUserIds: const [],
    );
    signedInUser = User(
      id: 'profile-member-count-user',
      name: 'Profile Student',
      email: 'profile.student@ku.edu.tr',
      password: '246802',
      role: 'student',
      subscribedClubIds: const [clubId],
    );

    clubs.add(club);
    users.add(signedInUser);
    userState.replaceFollowedClubs(const [clubId]);
    supabaseClubMemberCounts[clubId] = 37;
    authService.login(signedInUser.email, signedInUser.password);
  });

  tearDown(() {
    authService.logout();
    userState.replaceFollowedClubs(const []);
    supabaseClubMemberCounts.remove(clubId);
    subscriptions.removeWhere((item) => item.clubId == clubId);
    users.removeWhere((item) => item.id == signedInUser.id);
    clubs.removeWhere((item) => item.id == clubId);
  });

  Widget app(Widget home) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  testWidgets('own profile uses the latest aggregate club member count', (
    tester,
  ) async {
    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.pump();

    final profile = tester.widget<StudentProfileScreen>(
      find.byType(StudentProfileScreen),
    );
    expect(profile.data.clubDetails.single.memberCount, 37);
  });

  testWidgets('visited profile uses the latest aggregate club member count', (
    tester,
  ) async {
    final visitedUser = User(
      id: 'visited-profile-member-count-user',
      name: 'Visited Student',
      email: 'visited.student@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [clubId],
    );

    await tester.pumpWidget(app(UserProfileScreen(user: visitedUser)));
    await tester.pump();

    // The visited student shares this club with the signed-in student, so it
    // shows up as a mutual club with the aggregate count under its name.
    expect(find.text(S.mutualClubs), findsOneWidget);
    expect(find.text('37 members'), findsOneWidget);
  });
}
