import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('app shows auth choice screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Koç University'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('I already have one'), findsOneWidget);
  });
}
