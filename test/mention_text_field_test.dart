import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/mention_text_field.dart';

void main() {
  testWidgets('shows mention options after @ and inserts selected mention', (
    tester,
  ) async {
    final controller = TextEditingController();
    MentionOption? selectedMention;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MentionTextField(
            controller: controller,
            options: const [
              MentionOption(
                id: 'c1',
                label: 'Computer Engineering Club',
                type: MentionType.club,
              ),
              MentionOption(
                id: 'u1',
                label: 'Alice Yilmaz',
                type: MentionType.student,
              ),
            ],
            onMentionSelected: (option) => selectedMention = option,
            decoration: const InputDecoration(hintText: 'Write...'),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '@');
    await tester.pumpAndSettle();

    expect(find.text('Computer Engineering Club'), findsOneWidget);
    expect(find.text('Alice Yilmaz'), findsOneWidget);

    await tester.tap(find.text('Alice Yilmaz'));
    await tester.pumpAndSettle();

    expect(controller.text, '@Alice Yilmaz ');
    expect(selectedMention?.id, 'u1');
  });
}
