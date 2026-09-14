import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/screens/explore_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('club discovery exposes each assigned category', (tester) async {
    final club = Club(
      id: 'club',
      name: 'Design Club',
      description: '',
      categoryName: 'Arts, Technology',
      adminUserIds: const [],
    );
    late List<String> categories;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            categories = ExploreScreen.categoriesFor(context, club);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(categories, ['Arts', 'Technology']);
  });
}
