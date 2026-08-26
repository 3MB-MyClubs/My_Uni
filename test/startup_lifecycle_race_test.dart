import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/app_launch_screen.dart';
import 'package:flutter_application_1/screens/onboarding_carousel_screen.dart';
import 'package:flutter_application_1/services/app_update_service.dart';
import 'package:flutter_application_1/services/onboarding_intro_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'resuming during the initial update check releases the launch screen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await onboardingIntroService.initialize();

      final firstCheck = Completer<Map<String, dynamic>?>();
      final resumedCheck = Completer<Map<String, dynamic>?>();
      var checkCount = 0;
      final updateService = AppUpdateService(
        targetPlatform: TargetPlatform.iOS,
        isWeb: false,
        checkTimeout: const Duration(seconds: 5),
        configLoader: () {
          checkCount++;
          return checkCount == 1 ? firstCheck.future : resumedCheck.future;
        },
        installedAppInfoLoader: () async =>
            const InstalledAppInfo(version: '1.1', buildNumber: 9),
      );

      await tester.pumpWidget(
        MyApp(
          minimumLaunchDuration: Duration.zero,
          updateService: updateService,
          startupInitializer: () async {},
        ),
      );
      await tester.pump();
      expect(checkCount, 1);
      expect(find.byKey(AppLaunchScreen.progressKey), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(checkCount, 2);

      resumedCheck.complete(null);
      await tester.pump();
      expect(find.byType(OnboardingCarouselScreen), findsOneWidget);

      firstCheck.complete(null);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(OnboardingCarouselScreen), findsOneWidget);
    },
  );
}
