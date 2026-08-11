import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/widgets/club_board_lane.dart';
import 'package:flutter_application_1/widgets/club_chat_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('club chat lanes stay inside compact and large screen widths', (
    tester,
  ) async {
    final initialLanguage = localeService.languageCode;
    await localeService.setLanguage('tr', persistToAccount: false);
    addTearDown(
      () => localeService.setLanguage(initialLanguage, persistToAccount: false),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [320.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 700));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClubLaneSwitch(
              tab: ClubCommunityTab.board,
              onTab: (_) {},
              boardUnread: 8,
              chatUnread: 24,
              soloUnread: 142,
              t: ClubChatTheme.of(const Color(0xFFB41C18)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'screen width: $width');

      final switchRect = tester.getRect(
        find.byKey(const ValueKey('club-lane-switch')),
      );
      for (final tab in ClubCommunityTab.values) {
        final tabRect = tester.getRect(
          find.byKey(ValueKey('club-lane-${tab.name}')),
        );
        expect(
          tabRect.left,
          greaterThanOrEqualTo(switchRect.left),
          reason: '${tab.name} left edge at screen width $width',
        );
        expect(
          tabRect.right,
          lessThanOrEqualTo(switchRect.right),
          reason: '${tab.name} right edge at screen width $width',
        );
      }

      final soloTextRect = tester.getRect(find.text(S.clubSoloChatTab));
      final soloTabRect = tester.getRect(
        find.byKey(const ValueKey('club-lane-solo')),
      );
      expect(
        soloTextRect.left,
        greaterThanOrEqualTo(soloTabRect.left),
        reason: 'Solo Chat text left edge at screen width $width',
      );
      expect(
        soloTextRect.right,
        lessThanOrEqualTo(soloTabRect.right),
        reason: 'Solo Chat text right edge at screen width $width',
      );
    }
  });
}
