import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';
import 'package:flutter_application_1/services/user_state.dart';

/// Reproduces the 72px overflow on a student profile whose major is long.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Long major does not overflow the profile header', (
    tester,
  ) async {
    authService.logout();
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(true); // match the reported dark-mode screenshot
    authService.login('alice@ku.edu.tr', '11111111');

    final efe = User(
      id: 'u_efe_overflow',
      name: 'Efe Dinc',
      email: 'efe@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [],
    );
    userState.setMajor(efe.id, 'Electrical & Electronics Engineering');
    userState.setYear(efe.id, '3rd Year');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: Brightness.dark),
          home: UserProfileScreen(user: efe),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('user-profile-long-major');

    expect(find.text('Efe Dinc'), findsWidgets); // app bar title + header
    expect(tester.takeException(), isNull); // would fail on a RenderFlex overflow
  });
}
