import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/widgets/chats_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// A chat photo is the bubble — WhatsApp draws no frame of bubble colour
/// around the picture, and neither do we.
///
/// Deliberately its own file rather than a case in
/// `chat_thread_screen_smoke_test.dart`: that suite's `tearDownAll` calls
/// `chatStore.saveAll`, which wedges for ten minutes here.
void main() {
  late Directory tempDir;
  late String photoPath;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('chat_photo_bubble_test_');
    photoPath = await _writePhoto(tempDir, width: 480, height: 360);
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  tearDown(() => authService.logout());

  testWidgets('a photo fills its bubble, with no inset frame around it', (
    tester,
  ) async {
    final me = User(
      id: 'chat-photo-me',
      name: 'Photo Sender',
      email: 'chat.photo.me@ku.edu.tr',
      password: '13579024',
      role: 'student',
      subscribedClubIds: const [],
    );
    final them = User(
      id: 'chat-photo-them',
      name: 'Photo Recipient',
      email: 'chat.photo.them@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [],
    );
    users.addAll([me, them]);
    addTearDown(
      () => users.removeWhere((user) => user.id == me.id || user.id == them.id),
    );
    expect(authService.login(me.email, me.password), isTrue);

    final threadId = chatStore.ensureDirectThread(me.id, them.id)!;
    final sent = chatStore.sendMessage(
      threadId: threadId,
      senderId: me.id,
      content: '',
      kind: ChatMessageKind.photo,
      attachmentPath: photoPath,
      attachmentName: 'photo.png',
    )!;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChatThreadScreen(threadId: threadId, recipient: them),
        ),
      ),
    );
    await tester.pump();

    final bubble = tester.widget<ChatBubbleShell>(
      find.byKey(ValueKey('chat-message-bubble-${sent.id}')),
    );
    expect(bubble.padding, EdgeInsets.zero);

    // The picture carries the bubble's own corners, so it ends exactly where
    // the bubble does instead of sitting inside it.
    final clip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byKey(ValueKey('chat-photo-${sent.id}')),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    final radius = clip.borderRadius as BorderRadius;
    expect(radius.topLeft.x, kChatBubbleRadius);
    expect(radius.topRight.x, kChatBubbleRadius);

    // Flushes ChatStore's one-second save debounce so the test does not end
    // with a pending timer.
    await tester.pump(const Duration(seconds: 1));
  });
}

Future<String> _writePhoto(
  Directory directory, {
  required int width,
  required int height,
}) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF8B1538),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final path = '${directory.path}/chat-photo.png';
  await File(path).writeAsBytes(data!.buffer.asUint8List(), flush: true);
  return path;
}
