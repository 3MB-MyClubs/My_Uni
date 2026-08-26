import 'dart:io';

import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('chat_single_pin_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
    'startup repairs multiple cached pins and keeps the newest item',
    () async {
      const threadId = 'club:11111111-1111-1111-1111-111111111111';
      final olderMessage = ChatMessage(
        id: '11111111-1111-1111-1111-111111111112',
        threadId: threadId,
        senderId: 'club-account',
        content: 'Older pinned message',
        createdAt: DateTime.utc(2026, 8, 25, 10),
        pinned: true,
      );
      final newerAnnouncement = ChatMessage(
        id: '11111111-1111-1111-1111-111111111113',
        threadId: threadId,
        senderId: 'club-account',
        content: 'Newer pinned announcement',
        createdAt: DateTime.utc(2026, 8, 25, 11),
        kind: ChatMessageKind.announcement,
        pinned: true,
      );
      final box = await Hive.openBox<dynamic>('chat_v1');
      await box.put('messages', [
        olderMessage.toMap(),
        newerAnnouncement.toMap(),
      ]);
      await box.close();

      final store = ChatStore();
      await store.initialize();

      final pinned = store
          .messagesFor(threadId)
          .where((message) => message.pinned)
          .toList();
      expect(pinned, hasLength(1));
      expect(pinned.single.id, newerAnnouncement.id);
      expect(store.messageById(olderMessage.id)!.pinned, isFalse);
      expect(store.pinnedMessageIn(threadId)?.id, newerAnnouncement.id);

      await store.saveAll();
      final saved = (Hive.box<dynamic>('chat_v1').get('messages') as List)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .where((raw) => raw['pinned'] == true)
          .toList();
      expect(saved, hasLength(1));
      expect(saved.single['id'], newerAnnouncement.id);
    },
  );
}
