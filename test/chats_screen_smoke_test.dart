import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/chats_screen.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';

void main() {
  setUp(() async {
    authService.logout();
    await themeService.setDark(true);
  });

  tearDown(() async {
    authService.logout();
    await themeService.setDark(true);
  });

  testWidgets('ChatsScreen builds for a logged-in student', (tester) async {
    authService.login('alice@ku.edu.tr', '111111');

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChatsScreen())),
    );
    await tester.pump();

    expect(find.byType(ChatsScreen), findsOneWidget);
    expect(AppColors.background, const Color(0xFF0C0608));
    expect(AppColors.card, const Color(0xFF191416));
    expect(AppColors.surfaceAlt, const Color(0xFF241F21));
    expect(AppColors.divider, const Color(0xFF332E30));
    expect(AppColors.text, const Color(0xFFFFFFFF));
    expect(AppColors.secondaryText, const Color(0xFFAFA3A9));
    expect(AppColors.primaryRed, const Color(0xFF9E2045));
    expect(tester.takeException(), isNull);
  });

  testWidgets('student chats default to Students and can filter Clubs', (
    tester,
  ) async {
    authService.login('alice@ku.edu.tr', '111111');
    final controller = ChatsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ChatsScreen(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('chat-filter-students')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-filter-clubs')), findsOneWidget);
    final initialIndicator = tester.widget<AnimatedAlign>(
      find.byKey(const ValueKey('chat-filter-liquid-indicator')),
    );
    expect(initialIndicator.alignment, Alignment.centerLeft);
    expect(initialIndicator.duration, const Duration(milliseconds: 420));
    expect(find.text(S.searchPeople), findsOneWidget);
    expect(find.byIcon(Icons.edit_square), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-filter-clubs')));
    await tester.pump();

    final movedIndicator = tester.widget<AnimatedAlign>(
      find.byKey(const ValueKey('chat-filter-liquid-indicator')),
    );
    expect(movedIndicator.alignment, Alignment.centerRight);
    expect(find.text(S.searchClubChats), findsOneWidget);
    expect(find.byIcon(Icons.edit_square), findsNothing);

    controller.showStudents();
    await tester.pump();

    expect(find.text(S.searchPeople), findsOneWidget);
    expect(find.byIcon(Icons.edit_square), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat people searches stay borderless and hide their hint', (
    tester,
  ) async {
    authService.login('alice@ku.edu.tr', '111111');
    userState.setMajor('u2', 'Computer Engineering');
    userState.setYear('u2', '3rd Year');
    addTearDown(() {
      userState.majors.remove('u2');
      userState.years.remove('u2');
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChatsScreen())),
    );
    await tester.pump();

    final inboxSearch = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-search-students')),
    );
    expect(inboxSearch.decoration?.hintText, S.searchPeople);
    expect(inboxSearch.decoration?.focusedBorder, InputBorder.none);
    expect(find.text('Computer Engineering · 3rd Year'), findsNothing);
    expect(find.text(S.sayHello), findsNothing);

    await tester.tap(find.byIcon(Icons.edit_square));
    await tester.pumpAndSettle();

    final pickerFinder = find.byKey(const ValueKey('new-chat-search'));
    final pickerSearch = tester.widget<TextField>(pickerFinder);
    final focusedBorder = pickerSearch.decoration?.focusedBorder;
    expect(focusedBorder, isA<OutlineInputBorder>());
    expect((focusedBorder! as OutlineInputBorder).borderSide, BorderSide.none);
    final pickerHint = find.descendant(
      of: pickerFinder,
      matching: find.text(S.searchPeople),
    );
    expect(pickerHint, findsOneWidget);
    expect(find.text('Computer Engineering · 3rd Year'), findsOneWidget);

    await tester.enterText(pickerFinder, 'Can');
    await tester.pump();

    expect(pickerHint, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two recipients continue into the optional group setup flow', (
    tester,
  ) async {
    authService.login('alice@ku.edu.tr', '111111');

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChatsScreen())),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.edit_square));
    await tester.pumpAndSettle();

    final continueButton = find.byKey(const ValueKey('new-chat-continue'));
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('recipient-u2')));
    await tester.pump();
    expect(find.text('Start Chat'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recipient-u3')));
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Create Group'), findsWidgets);
    expect(find.text('Can, Emir'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('group-photo-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from library'), findsOneWidget);
    await tester.tap(find.byType(ModalBarrier).last);
    await tester.pumpAndSettle();
    final nameField = tester.widget<TextField>(
      find.byKey(const ValueKey('group-name-field')),
    );
    expect(nameField.decoration?.hintText, 'Enter group name');

    final createButton = find.byKey(const ValueKey('create-group-button'));
    expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('create-group-member-u3')));
    await tester.pump();
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
    expect(find.text('Select at least 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChatsScreen also renders in light mode', (tester) async {
    await themeService.setDark(false);
    authService.login('alice@ku.edu.tr', '111111');

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChatsScreen())),
    );
    await tester.pump();

    expect(find.byType(ChatsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChatsScreen renders logged out without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChatsScreen())),
    );
    await tester.pump();

    expect(find.byType(ChatsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KUACM admin opens only the embedded KUACM community', (
    tester,
  ) async {
    authService.login('kuacm@ku.edu.tr', '11111111');

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChatsScreen())),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('admin-community-thread')),
      findsOneWidget,
    );
    expect(find.text('Bilgisayar Kulübü (KUACM)'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(S.searchStudents), findsNothing);
    expect(find.byKey(const ValueKey('chat-filter-students')), findsNothing);
    expect(find.byKey(const ValueKey('chat-filter-clubs')), findsNothing);
    expect(find.byIcon(Icons.edit_square), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('another club admin sees only their own community', (
    tester,
  ) async {
    authService.login('kudak@ku.edu.tr', '11111111');

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChatsScreen())),
    );
    await tester.pump();

    expect(find.text('Dağcılık Kulübü (KUDAK)'), findsOneWidget);
    expect(find.text('Bilgisayar Kulübü (KUACM)'), findsNothing);
    expect(find.text(S.searchStudents), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('super admin has no messaging destination', (tester) async {
    authService.login('admin@ku.edu.tr', '11111111');

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChatsScreen())),
    );
    await tester.pump();

    expect(find.text('No club community assigned'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text(S.searchStudents), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
