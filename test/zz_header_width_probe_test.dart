import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/notification.dart';
import 'package:flutter_application_1/screens/notifications_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/user_state.dart';

/// Guards the notification title against being ellipsized on phone screens.
void main() {
  testWidgets('header title fits at 402 logical pixels', (tester) async {
    const myId = 'notification-header-test-admin';
    authService.setClubAdmin(
      AppAdmin(
        id: myId,
        name: 'Header Test',
        email: 'header.test@ku.edu.tr',
        password: 'test-password',
      ),
      checkTerms: false,
    );
    userState.dynamicNotifications
      ..clear()
      ..add(
        AppNotification(
          id: 'p1',
          userId: myId,
          message: 'Somebody liked your post',
          createdAt: DateTime.now(),
        ),
      );
    addTearDown(userState.dynamicNotifications.clear);

    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late AppLocalizations l10n;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          initialRoute: '/notifications',
          routes: {
            '/': (_) => const SizedBox.shrink(),
            '/notifications': (context) {
              l10n = AppLocalizations.of(context)!;
              return const NotificationsScreen();
            },
          },
        ),
      ),
    );
    await tester.pump();

    final title = find.text(l10n.notifications);
    final titleParagraph = tester.renderObject<RenderParagraph>(title);
    final titleText = tester.widget<Text>(title);

    expect(find.text(l10n.markAllRead), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(
      titleText.style?.fontSize,
      23,
      reason: 'The smaller notification title should fit beside the actions.',
    );
    expect(titleParagraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
}
