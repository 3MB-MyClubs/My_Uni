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
      final studentThread = ChatStore.dmThreadId(
        'registered-student-a',
        'registered-student-b',
      );
      final mockOnlyThread = ChatStore.dmThreadId('u2', 'u4');
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
          senderId: 'registered-student-b',
          content: 'must be preserved',
          createdAt: now,
        ).toMap(),
        ChatMessage(
          id: 'seed_dm_u2_u4_0',
          threadId: mockOnlyThread,
          senderId: 'u4',
          content: 'scripted DM must be removed',
          createdAt: now,
        ).toMap(),
        ChatMessage(
          id: 'seed_club_c4_0',
          threadId: ChatStore.clubThreadId('c4'),
          senderId: 'u2',
          content: 'scripted club message must be removed',
          createdAt: now,
        ).toMap(),
      ]);
      await box.put('directThreadIds', [
        adminThread,
        studentThread,
        mockOnlyThread,
      ]);
      await box.put('lastRead', {
        'cadmin5': {adminThread: now.toIso8601String()},
        'u2': {adminThread: now.toIso8601String()},
        'registered-student-a': {studentThread: now.toIso8601String()},
      });
      await box.put('dmSeededUserIds', ['cadmin5', 'u2']);

      final store = ChatStore();
      await store.initialize();
      await store.saveAll();

      expect(store.messagesFor(adminThread), isEmpty);
      expect(store.messagesFor(mockOnlyThread), isEmpty);
      expect(store.messagesFor(ChatStore.clubThreadId('c4')), isEmpty);
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
      expect(
        (box.get('directThreadIds') as List).cast<String>(),
        isNot(contains(mockOnlyThread)),
      );
      final persistedReads = Map<String, dynamic>.from(
        box.get('lastRead') as Map,
      );
      expect(
        Map<String, dynamic>.from(persistedReads['u2'] as Map),
        isNot(contains(adminThread)),
      );
      expect(box.get('dmSeededUserIds'), isNull);
      expect(box.get('seedVersion'), isNull);
      expect(box.get('mockChatRemovalVersion'), 1);
      expect(box.get('adminMessagingMigrationVersion'), 1);
    },
  );
}
