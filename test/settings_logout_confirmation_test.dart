import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logout requires confirmation', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  confirmed = await showLogoutConfirmationDialog(context);
                },
                child: const Text('Open logout'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open logout'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to log out of your account?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsNothing);
    expect(confirmed, isFalse);

    await tester.tap(find.text('Open logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });
}
