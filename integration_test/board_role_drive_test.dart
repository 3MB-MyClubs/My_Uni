import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';

Future<void> _takeScreenshotIfAvailable(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  try {
    await binding.takeScreenshot(name);
  } on MissingPluginException {
    // Direct `flutter test -d macos` does not register the screenshot channel.
  }
}

/// Reproduces: club admin opens BOARD tab and changes a member's role/title.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Change a board member role/title', (tester) async {
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    contentStore.loadBoardMemberIds();
    contentStore.loadBoardMemberTitles();
    await themeService.setDark(false);
    authService.login('kuacm@ku.edu.tr', '11111111'); // KUACM (c4) admin

    final club = clubs.firstWhere((c) => c.id == 'c4');
    if (!club.boardMemberIds.contains('u1')) club.boardMemberIds.add('u1');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ClubProfileScreen(
            club: club,
            color: AppColors.primaryRed,
            onSettings: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // Go to the BOARD tab.
    await tester.tap(find.text('BOARD'));
    await tester.pump(const Duration(milliseconds: 600));
    await _takeScreenshotIfAvailable(binding, 'board-01-tab');

    // Tap the "Set title" pencil for the member.
    await tester.tap(find.byTooltip('Set title').first);
    await tester.pump(const Duration(milliseconds: 500));
    await _takeScreenshotIfAvailable(binding, 'board-02-dialog');

    // Type a role and save.
    await tester.enterText(find.byType(TextField).last, 'President');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 700));
    await _takeScreenshotIfAvailable(binding, 'board-03-after');

    expect(club.boardMemberIds, contains('u1'));
    expect(club.boardMemberTitles['u1'], 'President');

    // Surface any thrown framework error.
    final err = tester.takeException();
    expect(err, isNull, reason: 'changing a board role threw: $err');
  });
}
