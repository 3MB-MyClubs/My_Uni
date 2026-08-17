import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/screens/create_post_screen.dart';
import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/widgets/lazy_indexed_stack.dart';
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

  testWidgets('bottom navigation shrinks scrolling down and restores going up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
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

    final barFinder = find
        .descendant(
          of: find.byKey(const ValueKey('mobile-bottom-navigation')),
          matching: find.byType(ClipRRect),
        )
        .first;
    final expandedHeight = tester.getSize(barFinder).height;

    // The tab bodies own their scrollables, so drive the nav bar the same way
    // they do: a scroll notification bubbling up from inside the body.
    void scrollBy(double delta, double pixels) {
      ScrollUpdateNotification(
        metrics: FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 4000,
          pixels: pixels,
          viewportDimension: 800,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1,
        ),
        context: tester.element(find.byType(LazyIndexedStack)),
        scrollDelta: delta,
      ).dispatch(tester.element(find.byType(LazyIndexedStack)));
    }

    scrollBy(400, 400);
    await tester.pump();
    final shrunkHeight = tester.getSize(barFinder).height;
    expect(shrunkHeight, lessThan(expandedHeight));

    // Once at the floor, scrolling further down must not keep shrinking it.
    scrollBy(400, 800);
    await tester.pump();
    expect(tester.getSize(barFinder).height, shrunkHeight);

    // A settling fling's sub-pixel upward jitter is not a move back up.
    scrollBy(-1, 799);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(barFinder).height, shrunkHeight);

    scrollBy(-30, 770);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(barFinder).height, expandedHeight);

    // A short downward scroll that ends mid-shrink still settles compact
    // rather than springing back to the full bar.
    scrollBy(20, 790);
    await tester.pump();
    expect(tester.getSize(barFinder).height, greaterThan(shrunkHeight));
    ScrollEndNotification(
      metrics: FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 4000,
        pixels: 790,
        viewportDimension: 800,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      ),
      context: tester.element(find.byType(LazyIndexedStack)),
    ).dispatch(tester.element(find.byType(LazyIndexedStack)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(barFinder).height, shrunkHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('club admin create action offers a post composer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
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

    await tester.tap(find.byKey(const ValueKey('center-add-icon-motion')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final postLabel = AppLocalizations.of(
      tester.element(find.byType(MainNavScreen)),
    )!.post;
    expect(find.text(postLabel), findsOneWidget);
    await tester.tap(find.text(postLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CreatePostScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
