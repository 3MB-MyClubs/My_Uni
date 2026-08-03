import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    authService.logout();
    authService.login('kuacm@ku.edu.tr', '11111111');
  });

  tearDown(authService.logout);

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
    expect(tester.takeException(), isNull);
  });
}
