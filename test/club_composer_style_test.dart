import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/club_chat_theme.dart';
import 'package:flutter_application_1/widgets/club_composer.dart';

void main() {
  const accent = Color(0xFF9E2045);
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
  });

  tearDown(() async {
    controller.dispose();
    await themeService.setDark(false, persistToAccount: false);
  });

  Widget composer({required bool enabled}) {
    final clubTheme = ClubChatTheme.of(accent);
    return MaterialApp(
      theme: ThemeData(
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFCCCCCC),
        ),
      ),
      home: Scaffold(
        body: ClubComposer(
          controller: controller,
          t: clubTheme,
          hintText: "What's up?",
          people: const [],
          avatarBuilder: (_, _) => const SizedBox.shrink(),
          onSend: (_, _) {},
          onAttach: (_) {},
          onTypingChanged: () {},
          enabled: enabled,
        ),
      ),
    );
  }

  Color inputBackground(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.byKey(const ValueKey('club-message-input-container')),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  testWidgets(
    'light club input stays white when unfocused, focused, typing, and disabled',
    (tester) async {
      await themeService.setDark(false, persistToAccount: false);
      await tester.pumpWidget(composer(enabled: true));

      TextField field() => tester.widget<TextField>(find.byType(TextField));

      expect(inputBackground(tester), LightColors.card);
      expect(field().decoration?.filled, isFalse);
      expect(field().decoration?.hintText, "What's up?");
      expect(field().focusNode?.hasFocus, isFalse);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(field().focusNode?.hasFocus, isTrue);
      expect(inputBackground(tester), LightColors.card);

      await tester.enterText(find.byType(TextField), 'Hello club');
      await tester.pump();
      expect(controller.text, 'Hello club');
      expect(inputBackground(tester), LightColors.card);

      await tester.pumpWidget(composer(enabled: false));
      await tester.pump();
      expect(field().enabled, isFalse);
      expect(field().decoration?.filled, isFalse);
      expect(inputBackground(tester), LightColors.card);
    },
  );

  testWidgets('dark club input keeps its existing raised surface', (
    tester,
  ) async {
    await themeService.setDark(true, persistToAccount: false);
    await tester.pumpWidget(composer(enabled: true));

    expect(inputBackground(tester), DarkColors.surfaceAlt);
  });
}
