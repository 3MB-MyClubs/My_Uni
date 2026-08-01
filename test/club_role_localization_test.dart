import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/widgets/student_campus_profile.dart';

void main() {
  Widget roleBadge(String role, Locale locale) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: StudentClubRoleBadge(role: role)),
  );

  testWidgets('standard club roles follow the selected language', (
    tester,
  ) async {
    await tester.pumpWidget(roleBadge('President', const Locale('tr')));
    await tester.pumpAndSettle();
    expect(find.text('Başkan'), findsOneWidget);
    expect(find.text('President'), findsNothing);

    await tester.pumpWidget(roleBadge('Başkan', const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('President'), findsOneWidget);
    expect(find.text('Başkan'), findsNothing);
  });

  testWidgets('founder, member, and custom roles are handled safely', (
    tester,
  ) async {
    for (final pair in <(String, String)>[
      ('Founder', 'Kurucu'),
      ('Member', 'Üye'),
      ('Treasurer', 'Sayman'),
      ('Robotics Captain', 'Robotics Captain'),
    ]) {
      await tester.pumpWidget(roleBadge(pair.$1, const Locale('tr')));
      await tester.pumpAndSettle();
      expect(find.text(pair.$2), findsOneWidget);
    }
  });
}
