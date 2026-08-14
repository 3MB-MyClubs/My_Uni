import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/chat_v2.dart';
import 'package:flutter_application_1/services/chat_v2_controller.dart';
import 'package:flutter_application_1/services/chat_v2_service.dart';

void main() {
  const threadId = 'group:00000000-0000-0000-0000-000000000100';

  test(
    'history keyset pages merge by id with stable timestamp ordering',
    () async {
      final timestamp = DateTime.utc(2026, 8, 12, 12);
      final source = _FakeChatSource(
        messages: (requestedThread, cursor, _) async {
          expect(requestedThread, threadId);
          if (cursor == null) {
            return _messagePage(
              threadId,
              [_message('c', timestamp), _message('b', timestamp)],
              cursor: ChatHistoryCursorV2(createdAt: timestamp, id: 'b'),
              syncCursor: 4,
            );
          }
          return _messagePage(threadId, [
            _message('b', timestamp),
            _message('a', timestamp.subtract(const Duration(seconds: 1))),
          ], syncCursor: 6);
        },
      );
      final controller = ChatV2Controller(source: source, messagePageSize: 2);

      await controller.loadInitialMessages(threadId);
      await controller.loadOlderMessages(threadId);

      expect(
        controller.historyFor(threadId).messages.map((message) => message.id),
        ['a', 'b', 'c'],
      );
      expect(controller.historyFor(threadId).syncCursor, 6);
      expect(source.messageCursors, [null, 'b']);
    },
  );

  test('suppresses duplicate initial and older page requests', () async {
    final timestamp = DateTime.utc(2026, 8, 12, 12);
    final initialGate = Completer<ChatMessagePageV2>();
    final olderGate = Completer<ChatMessagePageV2>();
    final source = _FakeChatSource(
      messages: (_, cursor, _) =>
          cursor == null ? initialGate.future : olderGate.future,
    );
    final controller = ChatV2Controller(source: source);

    final first = controller.loadInitialMessages(threadId);
    final duplicateFirst = controller.loadInitialMessages(threadId);
    expect(identical(first, duplicateFirst), isTrue);
    initialGate.complete(
      _messagePage(threadId, [
        _message('b', timestamp),
      ], cursor: ChatHistoryCursorV2(createdAt: timestamp, id: 'b')),
    );
    await Future.wait([first, duplicateFirst]);

    final older = controller.loadOlderMessages(threadId);
    final duplicateOlder = controller.loadOlderMessages(threadId);
    expect(identical(older, duplicateOlder), isTrue);
    olderGate.complete(_messagePage(threadId, const []));
    await Future.wait([older, duplicateOlder]);

    expect(source.messageCursors, [null, 'b']);
  });

  test(
    'account reset rejects a stale response from the previous generation',
    () async {
      final timestamp = DateTime.utc(2026, 8, 12, 12);
      final stale = Completer<ChatMessagePageV2>();
      var calls = 0;
      final source = _FakeChatSource(
        messages: (_, _, _) {
          calls++;
          if (calls == 1) return stale.future;
          return Future.value(
            _messagePage(threadId, [_message('new', timestamp)]),
          );
        },
      );
      final controller = ChatV2Controller(source: source);

      final oldRequest = controller.loadInitialMessages(threadId);
      controller.reset();
      await controller.loadInitialMessages(threadId);
      stale.complete(
        _messagePage(threadId, [
          _message('stale', timestamp.subtract(const Duration(days: 1))),
        ]),
      );
      await oldRequest;

      expect(
        controller.historyFor(threadId).messages.map((message) => message.id),
        ['new'],
      );
    },
  );

  test(
    'reconnect delta applies upserts, receipts, and deletes without reload',
    () async {
      final timestamp = DateTime.utc(2026, 8, 12, 12);
      final source = _FakeChatSource(
        messages: (_, _, _) async => _messagePage(threadId, [
          _message('old', timestamp),
        ], syncCursor: 10),
        changes: (_, after, _) async {
          expect(after, 10);
          return ChatDeltaPageV2(
            threadId: threadId,
            hasMore: false,
            nextChangeId: 13,
            changes: [
              ChatChangeV2(
                changeId: 11,
                recordType: 'message',
                operation: 'INSERT',
                messageId: 'new',
                record: const {},
                message: _message(
                  'new',
                  timestamp.add(const Duration(seconds: 1)),
                ),
              ),
              const ChatChangeV2(
                changeId: 12,
                recordType: 'receipt',
                operation: 'UPDATE',
                messageId: 'new',
                record: {
                  'user_id': 'reader',
                  'delivered_at': '2026-08-12T12:00:02Z',
                  'seen_at': '2026-08-12T12:00:03Z',
                },
              ),
              const ChatChangeV2(
                changeId: 13,
                recordType: 'message',
                operation: 'DELETE',
                messageId: 'old',
                record: {},
              ),
            ],
          );
        },
      );
      final controller = ChatV2Controller(source: source);

      await controller.loadInitialMessages(threadId);
      await controller.reconcile(threadId);

      final history = controller.historyFor(threadId);
      expect(history.messages.map((message) => message.id), ['new']);
      expect(history.messages.single.receipts.single.userId, 'reader');
      expect(history.messages.single.receipts.single.seenAt, isNotNull);
      expect(history.syncCursor, 13);
      expect(source.messageCalls, 1);
      expect(source.changeCalls, 1);
    },
  );

  test('summary DTO carries server unread scopes without profile email', () {
    final json = <String, dynamic>{
      'thread_id': 'club:00000000-0000-0000-0000-000000000200',
      'thread_type': 'club',
      'activity_at': '2026-08-12T12:00:00Z',
      'unread_count': 5,
      'unread_board_count': 2,
      'unread_chat_count': 3,
      'read_boundaries': {
        'board': {'id': 'message-board', 'created_at': '2026-08-12T11:59:00Z'},
        'chat': {'id': 'message-chat', 'created_at': '2026-08-12T12:00:00Z'},
      },
      'sync_cursor': 9,
      'club': {
        'id': '00000000-0000-0000-0000-000000000200',
        'name': 'Robotics',
        'logo_url': 'https://example.test/logo.png',
      },
    };

    final summary = ChatConversationSummaryV2.fromJson(json);

    expect(summary.unreadBoardCount, 2);
    expect(summary.unreadChatCount, 3);
    expect(summary.latestBoardBoundary!.messageId, 'message-board');
    expect(summary.latestChatBoundary!.messageId, 'message-chat');
    expect(summary.club!.avatarUrl, 'https://example.test/logo.png');
    expect(_containsKeyRecursively(json, 'email'), isFalse);
  });

  test('poll-vote deltas update only the targeted loaded message', () async {
    final timestamp = DateTime.utc(2026, 8, 12, 12);
    final poll = ChatMessage(
      id: 'poll',
      threadId: threadId,
      senderId: 'author',
      content: 'Choose one',
      createdAt: timestamp,
      kind: ChatMessageKind.poll,
      pollOptions: const ['A', 'B'],
    );
    final controller = ChatV2Controller(
      source: _FakeChatSource(
        messages: (_, _, _) async => _messagePage(threadId, [poll]),
      ),
    );
    await controller.loadInitialMessages(threadId);
    controller.applyRealtimeChange(
      threadId,
      const ChatChangeV2(
        changeId: 1,
        recordType: 'poll_vote',
        operation: 'INSERT',
        messageId: 'poll',
        record: {'voter_auth_id': 'voter', 'option_index': 1},
      ),
    );
    expect(controller.historyFor(threadId).messages.single.pollVotes, {
      'voter': 1,
    });
    controller.applyRealtimeChange(
      threadId,
      const ChatChangeV2(
        changeId: 2,
        recordType: 'poll_vote',
        operation: 'DELETE',
        messageId: 'poll',
        record: {'voter_auth_id': 'voter', 'option_index': 1},
      ),
    );

    expect(controller.historyFor(threadId).messages.single.pollVotes, isEmpty);
    expect(controller.historyFor(threadId).syncCursor, 2);
  });

  test('expired journal cursor rebases on one bounded current page', () async {
    final source = _FakeChatSource(
      messages: (threadId, _, _) async => _messagePage(threadId, [
        _message('current', DateTime(2026, 8, 12)),
      ], syncCursor: 99),
      changes: (threadId, _, _) async => const ChatDeltaPageV2(
        threadId: 'club:club',
        changes: [],
        hasMore: false,
        nextChangeId: 99,
        cursorExpired: true,
      ),
    );
    final controller = ChatV2Controller(source: source);
    await controller.loadInitialMessages('club:club');
    await controller.reconcile('club:club');

    expect(controller.historyFor('club:club').messages.single.id, 'current');
    expect(source.messageCalls, 2);
  });
}

typedef _MessagesHandler =
    Future<ChatMessagePageV2> Function(
      String threadId,
      ChatHistoryCursorV2? cursor,
      int limit,
    );

typedef _ChangesHandler =
    Future<ChatDeltaPageV2> Function(
      String threadId,
      int afterChangeId,
      int limit,
    );

class _FakeChatSource implements ChatV2Source {
  _FakeChatSource({required this.messages, _ChangesHandler? changes})
    : changes =
          changes ??
          ((threadId, after, _) async => ChatDeltaPageV2(
            threadId: threadId,
            changes: const [],
            hasMore: false,
            nextChangeId: after,
          ));

  final _MessagesHandler messages;
  final _ChangesHandler changes;
  final List<String?> messageCursors = [];
  int messageCalls = 0;
  int changeCalls = 0;

  @override
  Future<ChatMessagePageV2> fetchMessages({
    required String threadId,
    ChatHistoryCursorV2? cursor,
    int limit = 40,
  }) {
    messageCalls++;
    messageCursors.add(cursor?.id);
    return messages(threadId, cursor, limit);
  }

  @override
  Future<ChatDeltaPageV2> fetchChanges({
    required String threadId,
    required int afterChangeId,
    int limit = 200,
  }) {
    changeCalls++;
    return changes(threadId, afterChangeId, limit);
  }

  @override
  Future<ChatSummaryPageV2> fetchSummaries({
    ChatSummaryCursorV2? cursor,
    int limit = 40,
    bool force = false,
  }) async => const ChatSummaryPageV2(items: [], hasMore: false, pageSize: 40);

  @override
  Future<void> markRead({
    required String threadId,
    required DateTime throughCreatedAt,
    required String throughMessageId,
    String scope = 'all',
  }) async {}

  @override
  Future<void> sendMessage({
    required ChatMessage message,
    required Map<String, dynamic> payload,
    required bool sendAsClub,
  }) async {}
}

ChatMessagePageV2 _messagePage(
  String threadId,
  List<ChatMessage> items, {
  ChatHistoryCursorV2? cursor,
  int syncCursor = 0,
}) => ChatMessagePageV2(
  threadId: threadId,
  items: items,
  hasMore: cursor != null,
  pageSize: 40,
  syncCursor: syncCursor,
  nextCursor: cursor,
);

ChatMessage _message(String id, DateTime createdAt) => ChatMessage(
  id: id,
  threadId: 'group:00000000-0000-0000-0000-000000000100',
  senderId: '00000000-0000-0000-0000-000000000001',
  content: id,
  createdAt: createdAt,
);

bool _containsKeyRecursively(Object? value, String key) {
  if (value is Map) {
    if (value.keys.any((candidate) => candidate.toString() == key)) return true;
    return value.values.any((item) => _containsKeyRecursively(item, key));
  }
  if (value is List) {
    return value.any((item) => _containsKeyRecursively(item, key));
  }
  return false;
}
