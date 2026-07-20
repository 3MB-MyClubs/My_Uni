import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/theme_service.dart';

/// The campus-email field needs only the local part ("htuncay23"); the
/// "@ku.edu.tr" domain is shown as a fixed suffix and never typed. Pasting a
/// full email is normalised back down to the local part.
void main() {
  testWidgets('Email field only needs the username, not @ku.edu.tr', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onLogin: () {}, onSignUp: () {}, onAdminLogin: () {}),
      ),
    );
    await tester.pump();

    // The domain is presented for the user — they don't type it.
    expect(find.text('@ku.edu.tr'), findsOneWidget);

    final emailField = find.byType(TextField).first;

    // Typing just the username keeps it as-is.
    await tester.enterText(emailField, 'htuncay23');
    await tester.pump();
    expect(tester.widget<TextField>(emailField).controller!.text, 'htuncay23');

    // Even if a full email is pasted, the domain is stripped automatically.
    await tester.enterText(emailField, 'htuncay23@ku.edu.tr');
    await tester.pump();
    expect(tester.widget<TextField>(emailField).controller!.text, 'htuncay23');
  });

  for (final darkMode in [true, false]) {
    testWidgets('login fields keep identical neutral styling while focused in '
        '${darkMode ? 'dark' : 'light'} mode', (tester) async {
      await themeService.setDark(darkMode);
      addTearDown(() => themeService.setDark(true));

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onLogin: () {},
            onSignUp: () {},
            onAdminLogin: () {},
          ),
        ),
      );
      await tester.pump();

      final fields = find.byType(TextField);
      final surfaceKeys = [
        const ValueKey<String>('login-field-Campus email'),
        const ValueKey<String>('login-field-Password'),
      ];

      for (var index = 0; index < surfaceKeys.length; index++) {
        final surface = find.byKey(surfaceKeys[index]);
        final before =
            tester.widget<Container>(surface).decoration! as BoxDecoration;

        await tester.tap(fields.at(index));
        await tester.pump();
        await tester.enterText(
          fields.at(index),
          index == 0 ? 'student' : '123456',
        );
        await tester.pump();

        final after =
            tester.widget<Container>(surface).decoration! as BoxDecoration;
        expect(after.color, before.color);
        expect(after.border, before.border);
        expect(after.boxShadow, before.boxShadow);

        final textField = tester.widget<TextField>(fields.at(index));
        expect(textField.cursorColor, AppColors.text);
        expect(textField.cursorErrorColor, AppColors.text);
        expect(textField.decoration!.focusColor, Colors.transparent);
        expect(textField.decoration!.hoverColor, Colors.transparent);
        expect(textField.decoration!.focusedBorder, InputBorder.none);

        final themes = tester.widgetList<Theme>(
          find.ancestor(of: fields.at(index), matching: find.byType(Theme)),
        );
        expect(
          themes.any(
            (theme) =>
                theme.data.focusColor == Colors.transparent &&
                theme.data.hoverColor == Colors.transparent &&
                theme.data.splashColor == Colors.transparent &&
                theme.data.highlightColor == Colors.transparent &&
                theme.data.textSelectionTheme.selectionColor ==
                    Colors.transparent &&
                theme.data.textSelectionTheme.selectionHandleColor ==
                    Colors.transparent,
          ),
          isTrue,
        );
      }
    });
  }
}
