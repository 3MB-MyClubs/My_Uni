import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/sent_message_entrance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rowHeight = 60.0;

  Widget host({
    required bool animate,
    VoidCallback? onCompleted,
    bool disableAnimations = false,
  }) => MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: Scaffold(
          // Stands in for the bottom of a reverse:true message list, where the
          // newest row's bottom edge is pinned to the composer.
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SentMessageEntrance(
              animate: animate,
              onCompleted: onCompleted,
              child: const SizedBox(
                height: rowHeight,
                child: Text('Sent message'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  double heightFactor(WidgetTester tester) => tester
      .widget<Align>(
        find.descendant(
          of: find.byType(SentMessageEntrance),
          matching: find.byType(Align),
        ),
      )
      .heightFactor!;

  double opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(SentMessageEntrance),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  testWidgets('sent message rises out of the composer as the row opens', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      host(animate: true, onCompleted: () => completions++),
    );

    // The row starts with no height at all, so the conversation above it is
    // pushed up gradually instead of by a whole bubble on the first frame.
    expect(heightFactor(tester), 0);
    expect(opacity(tester), 0);
    expect(tester.getSize(find.byType(SentMessageEntrance)).height, 0);

    final step = Duration(
      milliseconds: sentMessageEntranceDuration.inMilliseconds ~/ 6,
    );
    final rowBottom = tester.getBottomLeft(find.byType(SentMessageEntrance)).dy;
    var previousFactor = 0.0;
    var previousTop = tester.getTopLeft(find.text('Sent message')).dy;
    for (var i = 0; i < 5; i++) {
      await tester.pump(step);
      final factor = heightFactor(tester);
      // Monotonic and never past 1: an overshoot here would shove the messages
      // above their resting place and snap them back.
      expect(factor, greaterThan(previousFactor));
      expect(factor, lessThanOrEqualTo(1));
      // The bubble rides up by exactly what the row gained, so the two read as
      // one rigid movement rather than the bubble sliding inside its own row.
      final top = tester.getTopLeft(find.text('Sent message')).dy;
      expect(top, lessThan(previousTop));
      expect(top, closeTo(rowBottom - rowHeight * factor, 0.01));
      previousFactor = factor;
      previousTop = top;
    }

    await tester.pumpAndSettle();
    expect(heightFactor(tester), 1);
    expect(opacity(tester), 1);
    expect(tester.getSize(find.byType(SentMessageEntrance)).height, rowHeight);
    expect(completions, 1);
  });

  testWidgets('opacity is spent before the slide finishes', (tester) async {
    await tester.pumpWidget(host(animate: true));
    await tester.pump(
      Duration(milliseconds: sentMessageEntranceDuration.inMilliseconds ~/ 2),
    );
    // Fully opaque by mid-flight: the bubble is only translucent while it is
    // still half-hidden behind the composer edge.
    expect(opacity(tester), 1);
    expect(heightFactor(tester), lessThan(1));
    await tester.pumpAndSettle();
  });

  testWidgets('a message that was not just sent is laid out at rest', (
    tester,
  ) async {
    await tester.pumpWidget(host(animate: false));
    expect(find.byType(SizeTransition), findsNothing);
    expect(tester.getSize(find.byType(SentMessageEntrance)).height, rowHeight);
  });

  testWidgets('respects the platform reduce-motion setting', (tester) async {
    await tester.pumpWidget(host(animate: true, disableAnimations: true));
    expect(find.byType(SizeTransition), findsNothing);
    expect(tester.getSize(find.byType(SentMessageEntrance)).height, rowHeight);
  });
}
