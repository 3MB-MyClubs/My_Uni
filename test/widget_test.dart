import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('calculator adds numbers together', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('0'), findsWidgets);

    await tester.tap(find.text('7'));
    await tester.pump();
    await tester.tap(find.text('+'));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('='));
    await tester.pump();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('7 + 5 ='), findsOneWidget);
  });
}
