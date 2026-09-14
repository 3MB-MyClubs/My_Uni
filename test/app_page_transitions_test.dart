import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/navigation/chat_page_route.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

/// Guards the app-wide slide-back gesture that `AppTheme.build` installs via
/// `pageTransitionsTheme`. Everything here needs the real theme: a bare
/// `MaterialApp` resolves to Flutter's default builder, which has no
/// leading-edge gesture, so these tests would pass for the wrong reason.
void main() {
  Widget page(String label) => Scaffold(
    body: ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: Center(child: Text(label)),
    ),
  );

  Future<void> pumpApp(
    WidgetTester tester, {
    required Route<void> Function() onPush,
    bool reduceMotion = false,
  }) async {
    Widget app = MaterialApp(
      theme: AppTheme.build(AppThemeVariant.light, reduceMotion: reduceMotion),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(onPush()),
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    );
    if (reduceMotion) {
      // Platform-level accessibility flags reach the app's own MediaQuery
      // through the ancestor, which is how ChatPageRoute reads them.
      app = MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: app,
      );
    }
    await tester.pumpWidget(app);
  }

  /// Pushes [onPush] and returns the route it landed on.
  Future<PageRoute<void>> open(
    WidgetTester tester, {
    required Route<void> Function() onPush,
    String label = 'Detail',
    bool reduceMotion = false,
  }) async {
    await pumpApp(tester, onPush: onPush, reduceMotion: reduceMotion);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    final route = ModalRoute.of(tester.element(find.text(label)));
    return route! as PageRoute<void>;
  }

  testWidgets('a leading-edge drag pops an ordinary screen', (tester) async {
    final route = await open(
      tester,
      onPush: () => MaterialPageRoute<void>(builder: (_) => page('Detail')),
    );
    expect(route.popGestureEnabled, isTrue);

    await tester.dragFrom(const Offset(1, 300), const Offset(700, 0));
    await tester.pumpAndSettle();

    expect(find.text('Detail'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a drag that starts away from the edge does not pop', (
    tester,
  ) async {
    await open(
      tester,
      onPush: () => MaterialPageRoute<void>(builder: (_) => page('Detail')),
    );

    await tester.dragFrom(const Offset(400, 300), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('Detail'), findsOneWidget);
  });

  testWidgets('an incomplete edge drag settles back without popping', (
    tester,
  ) async {
    final route = await open(
      tester,
      onPush: () => MaterialPageRoute<void>(builder: (_) => page('Detail')),
    );
    final gesture = await tester.startGesture(const Offset(1, 300));

    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();

    expect(route.popGestureInProgress, isTrue);
    expect(route.animation!.value, lessThan(1));
    expect(find.text('Home'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(route.popGestureInProgress, isFalse);
    expect(route.animation!.value, 1);
    expect(find.text('Detail'), findsOneWidget);
  });

  testWidgets('ordinary screens share the chat route transition duration', (
    tester,
  ) async {
    final route = await open(
      tester,
      onPush: () => MaterialPageRoute<void>(builder: (_) => page('Detail')),
    );

    // The Cupertino curve is tuned for 500ms. Falling back to the framework's
    // 300ms default would run it too fast and desync it from ChatPageRoute.
    expect(route.transitionDuration, const Duration(milliseconds: 500));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 500));
  });

  testWidgets('the page below slides across differing route types', (
    tester,
  ) async {
    // A MaterialPageRoute pushed over a ChatPageRoute resolves the lower page's
    // motion through the theme builder's delegatedTransition. If that getter
    // ever returns null the chat page freezes in place instead of parallaxing.
    await pumpApp(
      tester,
      onPush: () => ChatPageRoute<void>(builder: (_) => page('Chat')),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    final restingDx = tester.getTopLeft(find.text('Chat')).dx;

    final chatContext = tester.element(find.text('Chat'));
    Navigator.of(
      chatContext,
    ).push(MaterialPageRoute<void>(builder: (_) => page('Detail')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // A full parallax carries the lower page a third of the screen to the left.
    expect(tester.getTopLeft(find.text('Chat')).dx, lessThan(restingDx - 50));

    await tester.pumpAndSettle();
  });

  testWidgets('fullscreen dialogs are not swipeable', (tester) async {
    final route = await open(
      tester,
      onPush: () => MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => page('Compose'),
      ),
      label: 'Compose',
    );
    expect(route.fullscreenDialog, isTrue);

    await tester.dragFrom(const Offset(1, 300), const Offset(700, 0));
    await tester.pumpAndSettle();

    expect(find.text('Compose'), findsOneWidget);
  });

  testWidgets('a screen that blocks popping is not swipeable', (tester) async {
    final route = await open(
      tester,
      onPush: () => MaterialPageRoute<void>(
        builder: (_) => PopScope(canPop: false, child: page('Gate')),
      ),
      label: 'Gate',
    );
    expect(route.popGestureEnabled, isFalse);

    await tester.dragFrom(const Offset(1, 300), const Offset(700, 0));
    await tester.pumpAndSettle();

    expect(find.text('Gate'), findsOneWidget);
  });

  group('reduced motion', () {
    testWidgets('drops the transition but keeps the gesture', (tester) async {
      final route = await open(
        tester,
        onPush: () => MaterialPageRoute<void>(builder: (_) => page('Detail')),
        reduceMotion: true,
      );

      expect(route.transitionDuration, Duration.zero);
      expect(route.popGestureEnabled, isTrue);

      await tester.dragFrom(const Offset(1, 300), const Offset(700, 0));
      await tester.pumpAndSettle();

      expect(find.text('Detail'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('reaches chat routes too', (tester) async {
      final route = await open(
        tester,
        onPush: () => ChatPageRoute<void>(builder: (_) => page('Chat')),
        label: 'Chat',
        reduceMotion: true,
      );

      expect(route.transitionDuration, Duration.zero);
      expect(route.popGestureEnabled, isTrue);
    });
  });
}
