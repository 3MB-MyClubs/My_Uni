import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/mutual_followers_badge.dart';
import 'package:flutter_application_1/widgets/user_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

User _student(String id) => User(
  id: id,
  name: 'Student $id',
  email: '$id@ku.edu.tr',
  password: '',
  role: 'student',
  subscribedClubIds: const [],
);

void main() {
  testWidgets('mutual avatars and count remain visible in both themes', (
    tester,
  ) async {
    addTearDown(() => themeService.setDark(false));
    final mutualUsers = [
      _student('mutual-1'),
      _student('mutual-2'),
      _student('mutual-3'),
      _student('mutual-4'),
    ];

    for (final brightness in [Brightness.light, Brightness.dark]) {
      await themeService.setDark(brightness == Brightness.dark);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: MutualFollowersBadge(
                  suggestedUserId: 'suggestion',
                  mutualUsers: mutualUsers,
                  mutualCount: 4,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final badgeFinder = find.byKey(
        const ValueKey('mutual-followers-suggestion'),
      );
      final badge = tester.widget<Container>(badgeFinder);
      final decoration = badge.decoration! as BoxDecoration;
      final label = tester.widget<Text>(find.text('4 mutuals'));

      expect(
        decoration.color,
        brightness == Brightness.light ? LightColors.card : DarkColors.card,
      );
      expect(
        label.style!.color,
        brightness == Brightness.light ? LightColors.text : DarkColors.text,
      );
      expect(
        find.descendant(of: badgeFinder, matching: find.byType(UserAvatar)),
        findsNWidgets(3),
      );
    }
  });
}
