import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/screens/create_event_screen.dart';
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

  testWidgets(
    'bottom navigation shrinks scrolling down and restores going up',
    (tester) async {
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
    },
  );

  testWidgets('bottom navigation compacts after three seconds of inactivity', (
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

    final nav = find.byKey(const ValueKey('mobile-bottom-navigation'));
    final bar = find
        .descendant(of: nav, matching: find.byType(ClipRRect))
        .first;
    final expandedHeight = tester.getSize(bar).height;

    await tester.pump(const Duration(milliseconds: 2999));
    expect(tester.getSize(bar).height, expandedHeight);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 160));
    final transitioningHeight = tester.getSize(bar).height;
    expect(transitioningHeight, lessThan(expandedHeight));
    expect(transitioningHeight, greaterThan(52));
    await tester.pump(const Duration(milliseconds: 300));
    final inactiveHeight = tester.getSize(bar).height;
    expect(inactiveHeight, lessThan(expandedHeight));

    // Touching a destination expands the shared bar immediately. Because the
    // timer belongs to MainNavScreen, it starts again on the newly selected tab.
    final events = find.descendant(
      of: nav,
      matching: find.byIcon(Icons.calendar_today_outlined),
    );
    await tester.tap(events);
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.getSize(bar).height, expandedHeight);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.getSize(bar).height, transitioningHeight);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(bar).height, inactiveHeight);

    // Tapping the selected destination also reveals the full-size controls.
    final selectedEvents = find.descendant(
      of: nav,
      matching: find.byIcon(Icons.calendar_today_rounded),
    );
    await tester.tap(selectedEvents);
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.getSize(bar).height, expandedHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('club admin create action opens the Create New chooser', (
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

    // `plus-menu` 297:8 — the + opens the chooser, and Create Event from there
    // reaches the wizard.
    expect(find.byKey(const ValueKey('club-create-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('club-create-post')), findsOneWidget);
    expect(find.byType(CreateEventScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('club-create-event')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CreateEventScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
