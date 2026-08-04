import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/notification.dart';
import 'package:flutter_application_1/screens/notifications_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:hive/hive.dart';

/// Measures the header title at real iPhone width (402 logical px) to see
/// whether it is being ellipsized by the flex split with the trailing Spacer.
void main() {
  testWidgets('header title width at 402', (tester) async {
    final tempDir = await Directory.systemTemp.createTemp('probe_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await viewTracker.initialize();
    await themeService.setDark(false);
    await authService.logout();
    users.removeWhere((user) => user.email.endsWith('@ku.edu.tr'));
    authService.signUp('Probe Tester', 'probe@ku.edu.tr', '135790');
    final myId = authService.currentUser!.id;
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

    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late AppLocalizations l10n;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const NotificationsScreen();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final rendered = tester.getSize(find.text(l10n.notifications));
    final painter = TextPainter(
      text: TextSpan(
        text: l10n.notifications,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    stdout.writeln('rendered title width : ${rendered.width}');
    stdout.writeln('intrinsic title width: ${painter.width}');
    stdout.writeln(
      'CLIPPED: ${rendered.width < painter.width - 0.5}  (mark-all present: '
      '${find.text(l10n.markAllRead).evaluate().isNotEmpty})',
    );
    final pill = find.text('1');
    if (pill.evaluate().isNotEmpty) {
      stdout.writeln('title  top/bottom: ${tester.getRect(find.text(l10n.notifications))}');
      stdout.writeln('pill   top/bottom: ${tester.getRect(pill)}');
    }
    tempDir.deleteSync(recursive: true);
  });
}
