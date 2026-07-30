import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/club_admin_access.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('club categories follow the settings language switcher', (
    tester,
  ) async {
    final originalLanguage = localeService.languageCode;
    await authService.logout();
    expect(authService.login('kuacm@ku.edu.tr', '11111111'), isTrue);

    final club = managedClubForAdmin(authService.currentAdmin!.id)!;
    final originalCategories = club.categoryName;
    club.categoryName = 'Career, Arts, Academic, Social Impact, Tech, Wellness';

    addTearDown(() async {
      club.categoryName = originalCategories;
      await authService.logout();
      await localeService.setLanguage(originalLanguage);
      await tester.binding.setSurfaceSize(null);
    });

    await localeService.setLanguage('en');
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: localeService,
        builder: (context, _) => ProviderScope(
          child: MaterialApp(
            locale: Locale(localeService.languageCode),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(onLogout: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Career, Arts, Academic, Social Impact, Tech, Wellness'),
      findsOneWidget,
    );

    final turkishToggle = find.byKey(const ValueKey<String>('language-TR'));
    await tester.ensureVisible(turkishToggle);
    await tester.tap(turkishToggle);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Kariyer, Sanat, Akademik, Sosyal Etki, Teknoloji, Sağlıklı Yaşam',
      ),
      findsOneWidget,
    );

    final categoriesTile = find.text('Kulüp Kategorileri');
    await tester.ensureVisible(categoriesTile);
    await tester.tap(categoriesTile);
    await tester.pumpAndSettle();

    for (final translatedCategory in [
      'Akademik',
      'Sanat',
      'İşletme',
      'Kariyer',
      'Mühendislik',
      'Müzik',
      'Sosyal Etki',
      'Spor',
      'Teknoloji',
      'Sağlıklı Yaşam',
    ]) {
      expect(find.text(translatedCategory), findsOneWidget);
    }
  });
}
