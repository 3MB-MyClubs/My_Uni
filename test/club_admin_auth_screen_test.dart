import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/screens/club_admin_auth_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('club admin submit button is labeled Log in', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClubAdminAuthScreen(onAdminLogin: () {}),
      ),
    );

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Sign In as Admin'), findsNothing);
    expect(find.text('@ku.edu.tr'), findsNothing);
  });
}
