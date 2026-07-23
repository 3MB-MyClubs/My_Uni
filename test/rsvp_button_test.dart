import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/rsvp_button.dart';

void main() {
  testWidgets('past events do not show an RSVP action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RsvpButton(
            eventId: 'past-event',
            color: Colors.red,
            isPast: true,
          ),
        ),
      ),
    );

    expect(find.text('RSVP'), findsNothing);
    expect(find.text('Ended'), findsNothing);
    expect(find.text('This event has passed'), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
  });
}
