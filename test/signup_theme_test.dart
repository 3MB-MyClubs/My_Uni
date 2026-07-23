import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/signup_flow_screen.dart';
import 'package:flutter_application_1/screens/signup_steps/signup_theme.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signup background follows the same light and dark app theme', (
    tester,
  ) async {
    addTearDown(() => themeService.setDark(false));

    await themeService.setDark(true);
    await tester.pumpWidget(
      MaterialApp(
        home: SignupFlowScreen(key: const ValueKey('dark'), onSignUp: (_) {}),
      ),
    );
    await tester.pump();

    var signupTheme = tester.widget<Theme>(
      find.byKey(const ValueKey('signup-flow-theme')),
    );
    var signupScaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('signup-flow-scaffold')),
    );
    expect(signupTheme.data.brightness, Brightness.dark);
    expect(signupScaffold.backgroundColor, DarkColors.background);
    expect(SC.card, DarkColors.card);
    expect(SC.ink, DarkColors.text);

    await themeService.setDark(false);
    await tester.pumpWidget(
      MaterialApp(
        home: SignupFlowScreen(key: const ValueKey('light'), onSignUp: (_) {}),
      ),
    );
    await tester.pump();

    signupTheme = tester.widget<Theme>(
      find.byKey(const ValueKey('signup-flow-theme')),
    );
    signupScaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('signup-flow-scaffold')),
    );
    expect(signupTheme.data.brightness, Brightness.light);
    expect(signupScaffold.backgroundColor, LightColors.background);
    expect(SC.card, LightColors.card);
    expect(SC.ink, LightColors.text);
  });
}
