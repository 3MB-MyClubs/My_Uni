import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    authService.logout();
    clubAdmins.add(
      AppAdmin(
        id: 'responsive-admin',
        name: 'Responsive Club',
        email: 'responsive.club@ku.edu.tr',
        password: '11111111',
      ),
    );
    clubs.add(
      Club(
        id: 'responsive-admin',
        name: 'Responsive Club',
        description: 'Navigation test fixture',
        adminUserIds: const ['responsive-admin'],
      ),
    );
    expect(authService.login('responsive.club@ku.edu.tr', '11111111'), isTrue);
  });

  tearDown(() {
    authService.logout();
    clubAdmins.removeWhere((admin) => admin.id == 'responsive-admin');
    clubs.removeWhere((club) => club.id == 'responsive-admin');
  });

  testWidgets('main navigation adapts between sidebar and bottom bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MainNavScreen(isAdmin: false),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('desktop-navigation-sidebar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-bottom-navigation')),
      findsNothing,
    );

    tester.view.physicalSize = const Size(800, 800);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('desktop-navigation-sidebar')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('mobile-bottom-navigation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('center-add-icon-motion')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
