import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';

/// A student can copy a message, not only reply to it.
///
/// The club community sheet has offered "Copy text" since it was written; the
/// student thread offered Reply and Delete and nothing else, on *two* separate
/// sheets — the reaction picker for other people's messages and the message-info
/// sheet for your own. So these tests are mostly about both paths carrying the
/// action, and about it appearing only where there is something to copy.
void main() {
  late Directory tempDir;
  late List<User> originalUsers;
  late String myId;
  late String threadId;
  late String photoPath;

  const partnerId = 'copy-partner';
  final clipboardWrites = <String>[];

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('chat_copy_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();

    // Written here, not inside a test: `toImage` is a real async call and
    // never completes under a widget test's fake clock — the test hangs until
    // `testWidgets` gives up ten minutes later.
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 40, 40),
      ui.Paint()..color = const ui.Color(0xFF8B1538),
    );
    final image = await recorder.endRecording().toImage(40, 40);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    photoPath = '${tempDir.path}/attachment.png';
    await File(photoPath).writeAsBytes(data!.buffer.asUint8List(), flush: true);
  });

  tearDownAll(() async {
    // Deliberately no `chatStore.saveAll()`: it never completes outside
    // `runAsync` here and wedges the whole file in teardown. The box lives in
    // a temp dir that goes away on the next line anyway.
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await themeService.setDark(false);
    await localeService.setLanguage('en');
    originalUsers = List<User>.from(users);
    clipboardWrites.clear();

    // `Clipboard.setData` goes out over the platform channel, which no test
    // binding answers; mock it so the payload can be asserted on.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardWrites.add(
              (call.arguments as Map)['text']?.toString() ?? '',
            );
          }
          return null;
        });

    peopleService.cacheRegisteredUser(
      User(
        id: partnerId,
        name: 'Deniz Kaya',
        email: 'deniz.copy@ku.edu.tr',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );
    // A fixture login is not available here — the mock `users` list is empty in
    // this suite — so the viewer is a freshly signed-up student.
    expect(authService.signUp('Copy Tester', 'copy@ku.edu.tr', '135790'), true);
    myId = authService.currentUser!.id;
    threadId = ChatStore.dmThreadId(myId, partnerId);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    authService.logout();
    users
      ..clear()
      ..addAll(originalUsers);
  });

  Future<void> pumpThread(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(localeService.languageCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatThreadScreen(threadId: threadId),
        ),
      ),
    );
    await tester.pump();
  }

  ChatMessage send({
    required String senderId,
    required String content,
    ChatMessageKind kind = ChatMessageKind.text,
    String? attachmentPath,
  }) {
    final message = chatStore.sendMessage(
      threadId: threadId,
      senderId: senderId,
      content: content,
      kind: kind,
      attachmentPath: attachmentPath,
    );
    expect(message, isNotNull, reason: 'fixture message was rejected');
    return message!;
  }

  Finder copyRowFor(ChatMessage message) =>
      find.byKey(ValueKey('chat-copy-message-${message.id}'));

  testWidgets("copies someone else's message from the reaction sheet", (
    tester,
  ) async {
    final message = send(
      senderId: partnerId,
      content: 'Library, 5th floor, 7pm',
    );
    await pumpThread(tester);

    await tester.longPress(find.byKey(ValueKey('chat-message-${message.id}')));
    await tester.pumpAndSettle();

    // The sheet that already offered Reply now offers Copy beside it.
    expect(find.byKey(ValueKey('chat-reply-message-${message.id}')), findsOne);
    expect(copyRowFor(message), findsOneWidget);

    await tester.tap(copyRowFor(message));
    await tester.pumpAndSettle();

    expect(clipboardWrites, ['Library, 5th floor, 7pm']);
    expect(find.text(S.copied), findsOneWidget);
    expect(find.byKey(const ValueKey('brief-toast')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the copied bubble is gone inside a second', (tester) async {
    // It replaced a `SnackBar`, which sat over the composer for four seconds.
    final message = send(senderId: partnerId, content: 'Thanks!');
    await pumpThread(tester);
    await tester.longPress(find.byKey(ValueKey('chat-message-${message.id}')));
    await tester.pumpAndSettle();
    await tester.tap(copyRowFor(message));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(const ValueKey('brief-toast')), findsOneWidget);

    // Stepped rather than jumped: the linger is a timer but the fade-out is an
    // animation, and an animation needs a frame *after* the timer fires to
    // make any progress at all.
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    // 800ms of fake time, start to finish.
    expect(find.byKey(const ValueKey('brief-toast')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copies your own message from the message-info sheet', (
    tester,
  ) async {
    // Long-pressing your own message opens delivery receipts, not the reaction
    // picker. Copy has to be on that sheet too or half a thread cannot be
    // copied at all.
    final message = send(senderId: myId, content: 'On my way');
    await pumpThread(tester);

    await tester.longPress(find.byKey(ValueKey('chat-message-${message.id}')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('chat-message-info-sheet')),
      findsOneWidget,
    );
    expect(copyRowFor(message), findsOneWidget);

    await tester.tap(copyRowFor(message));
    await tester.pumpAndSettle();

    expect(clipboardWrites, ['On my way']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a photo with no caption offers nothing to copy', (tester) async {
    final message = send(
      senderId: partnerId,
      content: '',
      kind: ChatMessageKind.photo,
      attachmentPath: photoPath,
    );
    await pumpThread(tester);

    // Bounded pumps, not `pumpAndSettle`: a photo bubble keeps scheduling
    // frames while its file decodes, so settling never arrives.
    await tester.longPress(find.byKey(ValueKey('chat-message-${message.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    // The sheet still opens — reply and react still make sense on a photo.
    expect(find.byKey(ValueKey('chat-reply-message-${message.id}')), findsOne);
    expect(copyRowFor(message), findsNothing);
  });

  testWidgets('a captioned photo copies its caption', (tester) async {
    final message = send(
      senderId: partnerId,
      content: 'Here is the poster',
      kind: ChatMessageKind.photo,
      attachmentPath: photoPath,
    );
    await pumpThread(tester);

    await tester.longPress(find.byKey(ValueKey('chat-message-${message.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(copyRowFor(message), findsOneWidget);

    await tester.tap(copyRowFor(message));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(clipboardWrites, ['Here is the poster']);
  });

  testWidgets('the copy label follows the app language', (tester) async {
    await localeService.setLanguage('tr');
    addTearDown(() => localeService.setLanguage('en'));

    final message = send(senderId: partnerId, content: 'Görüşürüz');
    await pumpThread(tester);
    await tester.longPress(find.byKey(ValueKey('chat-message-${message.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Metni kopyala'), findsOneWidget);
    expect(find.text('Copy text'), findsNothing);
  });
}
