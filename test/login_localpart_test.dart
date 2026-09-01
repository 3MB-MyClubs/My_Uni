import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/club_admin_auth_screen.dart';
import 'package:flutter_application_1/screens/platform_admin_auth_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/landing_design.dart';

/// `login-screen-light` / `login-screen` (Figma `495:5` / `485:5`).
///
/// The campus-email field needs only the local part ("htuncay23"); the
/// "@ku.edu.tr" domain is shown as a fixed suffix and never typed. Pasting a
/// full email is normalised back down to the local part.
void main() {
  testWidgets('landing wordmark keeps Club burgundy and makes Up foreground', (
    tester,
  ) async {
    await themeService.setDark(true);
    addTearDown(() => themeService.setDark(false));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(onLogin: () {}, onSignUp: () {}, onAdminLogin: () {}),
      ),
    );
    await tester.pump();

    final wordmark = tester.widget<Text>(
      find.byKey(const ValueKey<String>('landing-clubup-wordmark')),
    );
    final spans = (wordmark.textSpan! as TextSpan).children!;
    expect((spans[0] as TextSpan).style?.color, LandingColors.accent);
    expect((spans[1] as TextSpan).style?.color, const Color(0xFFFAFAFA));
    expect((spans[1] as TextSpan).style?.color, LandingColors.text);
  });

  testWidgets('login copy is translated to Turkish', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(onLogin: () {}, onSignUp: () {}, onAdminLogin: () {}),
      ),
    );
    await tester.pumpAndSettle();

    // Stripped to the frame: the crest, the university line and the field
    // labels are gone; the placeholders carry the copy now.
    expect(find.text('KOÇ ÜNİVERSİTESİ'), findsNothing);
    expect(find.text('KAMPÜS E-POSTASI'), findsNothing);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
    expect(find.text('Şifreni mi unuttun?'), findsOneWidget);
    expect(find.text('Kayıt ol'), findsOneWidget);
    expect(find.text(S.landingOr), findsOneWidget);
    expect(find.text(S.landingClubAdminPortal), findsOneWidget);
  });

  testWidgets('Email field only needs the username, not @ku.edu.tr', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(onLogin: () {}, onSignUp: () {}, onAdminLogin: () {}),
      ),
    );
    await tester.pump();

    // The domain is presented for the user — they don't type it.
    expect(find.text('@ku.edu.tr'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);

    final emailField = find.byType(TextField).first;

    // Typing just the username keeps it as-is.
    await tester.enterText(emailField, 'htuncay23');
    await tester.pump();
    expect(tester.widget<TextField>(emailField).controller!.text, 'htuncay23');
    expect(find.text('Email'), findsNothing);
    expect(find.text('@ku.edu.tr'), findsOneWidget);

    // Even if a full email is pasted, the domain is stripped automatically.
    await tester.enterText(emailField, 'htuncay23@ku.edu.tr');
    await tester.pump();
    expect(tester.widget<TextField>(emailField).controller!.text, 'htuncay23');
  });

  testWidgets('one club sign-in tap opens the normal club login', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(onLogin: () {}, onSignUp: () {}, onAdminLogin: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final trigger = find.byKey(
      const ValueKey<String>('club-admin-sign-in-trigger'),
    );
    await tester.ensureVisible(trigger);
    await tester.pumpAndSettle();
    await tester.tap(trigger);
    await tester.pump(const Duration(milliseconds: 699));
    expect(find.byType(ClubAdminAuthScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(ClubAdminAuthScreen), findsOneWidget);
    expect(find.byType(PlatformAdminAuthScreen), findsNothing);
  });

  testWidgets('five club sign-in taps open the platform admin login', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(onLogin: () {}, onSignUp: () {}, onAdminLogin: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final trigger = find.byKey(
      const ValueKey<String>('club-admin-sign-in-trigger'),
    );
    await tester.ensureVisible(trigger);
    await tester.pumpAndSettle();
    for (var tap = 0; tap < 5; tap++) {
      await tester.tap(trigger);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pumpAndSettle();

    expect(find.byType(PlatformAdminAuthScreen), findsOneWidget);
    expect(find.byType(ClubAdminAuthScreen), findsNothing);
    expect(find.text('dev3mb@gmail.com'), findsNothing);

    final emailField = find.byKey(
      const ValueKey<String>('platform-admin-email'),
    );
    expect(tester.widget<TextField>(emailField).controller!.text, isEmpty);
    await tester.enterText(emailField, 'dev3mb@gmail.com');
    expect(
      tester.widget<TextField>(emailField).controller!.text,
      'dev3mb@gmail.com',
    );
  });

  for (final darkMode in [true, false]) {
    testWidgets('landing fields stay transparent and neutral on focus in '
        '${darkMode ? 'dark' : 'light'} mode', (tester) async {
      await themeService.setDark(darkMode);
      addTearDown(() => themeService.setDark(true));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginScreen(
            onLogin: () {},
            onSignUp: () {},
            onAdminLogin: () {},
          ),
        ),
      );
      await tester.pump();

      final fields = find.byType(TextField);
      const surfaceKeys = [
        ValueKey<String>('landing-field-email'),
        ValueKey<String>('landing-field-password'),
      ];

      for (var index = 0; index < surfaceKeys.length; index++) {
        final surface = find.byKey(surfaceKeys[index]);
        final before =
            tester.widget<AnimatedContainer>(surface).decoration!
                as BoxDecoration;
        expect((before.border! as Border).top.color, LandingColors.border);
        expect(before.color, Colors.transparent);

        await tester.tap(fields.at(index));
        await tester.pump(const Duration(milliseconds: 220));

        final after =
            tester.widget<AnimatedContainer>(surface).decoration!
                as BoxDecoration;
        expect((after.border! as Border).top.color, LandingColors.border);
        expect(after.color, Colors.transparent);

        // Focus and typing do not introduce burgundy UI inside the field.
        expect(after.color, before.color);
        final textField = tester.widget<TextField>(fields.at(index));
        expect(textField.cursorColor, LandingColors.text);
        expect(textField.cursorErrorColor, LandingColors.text);
        expect(textField.decoration?.filled, isFalse);
        expect(textField.decoration?.fillColor, Colors.transparent);
        expect(textField.decoration?.focusColor, Colors.transparent);
        expect(textField.decoration?.focusedBorder, InputBorder.none);

        final fieldTheme = tester.widget<Theme>(
          find
              .ancestor(of: fields.at(index), matching: find.byType(Theme))
              .first,
        );
        expect(
          fieldTheme.data.textSelectionTheme.selectionHandleColor,
          LandingColors.placeholder,
        );
      }
    });
  }
}
