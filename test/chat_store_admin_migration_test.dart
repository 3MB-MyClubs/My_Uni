import 'dart:io';

import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test(
    'legacy admin DMs and their read state are removed on migration',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'chat_admin_migration_test_',
      );
      Hive.init(tempDir.path);
      addTearDown(() async {
        await Hive.close();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final adminThread = ChatStore.dmThreadId('cadmin5', 'u2');
      final studentThread = ChatStore.dmThreadId('u2', 'u3');
      final now = DateTime(2025, 1, 1, 12);
      final box = await Hive.openBox<dynamic>('chat_v1');
      await box.put('seedVersion', 1);
      await box.put('adminMessagingMigrationVersion', 0);
      await box.put('messages', [
        ChatMessage(
          id: 'legacy-admin-message',
          threadId: adminThread,
          senderId: 'cadmin5',
          content: 'must be removed',
          createdAt: now,
        ).toMap(),
        ChatMessage(
          id: 'student-message',
          threadId: studentThread,
          senderId: 'u3',
          content: 'must be preserved',
          createdAt: now,
        ).toMap(),
      ]);
      await box.put('directThreadIds', [adminThread, studentThread]);
      await box.put('lastRead', {
        'cadmin5': {adminThread: now.toIso8601String()},
        'u2': {
          adminThread: now.toIso8601String(),
          studentThread: now.toIso8601String(),
        },
      });
      await box.put('dmSeededUserIds', ['cadmin5', 'u2']);

      final store = ChatStore()..autoRepliesEnabled = false;
      await store.initialize();
      await store.saveAll();

      expect(store.messagesFor(adminThread), isEmpty);
      expect(store.messagesFor(studentThread), hasLength(1));
      expect(
        store.messagesFor(studentThread).single.status,
        MessageDeliveryStatus.seen,
      );
      expect(
        (box.get('directThreadIds') as List).cast<String>(),
        isNot(contains(adminThread)),
      );
      expect(
        (box.get('directThreadIds') as List).cast<String>(),
        contains(studentThread),
      );
      final persistedReads = Map<String, dynamic>.from(
        box.get('lastRead') as Map,
      );
      expect(
        Map<String, dynamic>.from(persistedReads['u2'] as Map),
        isNot(contains(adminThread)),
      );
      expect(
        (box.get('dmSeededUserIds') as List).cast<String>(),
        isNot(contains('cadmin5')),
      );
      expect(box.get('adminMessagingMigrationVersion'), 1);
    },
  );
}
