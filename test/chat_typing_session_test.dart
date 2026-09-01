import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _actor = 'a1000000-0000-4000-8000-000000000001';
const _peer = 'a1000000-0000-4000-8000-000000000002';
const _outsider = 'a1000000-0000-4000-8000-000000000003';

void main() {
  late _FakeTypingTransport transport;
  late ChatStore store;
  late String threadId;

  setUp(() {
    transport = _FakeTypingTransport();
    store = ChatStore(
      typingTransport: transport,
      typingRefreshInterval: const Duration(milliseconds: 45),
      typingIdleTimeout: const Duration(milliseconds: 110),
      typingExpiry: const Duration(milliseconds: 80),
    );
    threadId = ChatStore.dmThreadId(_actor, _peer);
  });

  test(
    'starts immediately, throttles refreshes, then stops when idle',
    () async {
      final session = store.openTypingSession(
        threadId: threadId,
        actorId: _actor,
      )!;
      final channel = transport.single;
      channel.setSubscribed(true);

      session.updateFocus(true);
      session.updateDraft('h');
      await _flush();
      expect(channel.sent, hasLength(1));
      expect(channel.sent.single['is_typing'], isTrue);

      session.updateDraft('he');
      session.updateDraft('hel');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(channel.sent, hasLength(1));

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(
        channel.sent.where((payload) => payload['is_typing'] == true).length,
        2,
      );

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(channel.sent.last['is_typing'], isFalse);
      expect(session.isTyping, isFalse);
      session.dispose();
    },
  );

  test('empty draft and focus loss clear active state immediately', () async {
    final session = store.openTypingSession(
      threadId: threadId,
      actorId: _actor,
    )!;
    final channel = transport.single..setSubscribed(true);

    session.updateFocus(true);
    session.updateDraft('draft');
    await _flush();
    session.updateDraft('');
    await _flush();
    expect(channel.sent.map((event) => event['is_typing']), [true, false]);

    session.updateDraft('again');
    await _flush();
    session.updateFocus(false);
    await _flush();
    expect(channel.sent.map((event) => event['is_typing']), [
      true,
      false,
      true,
      false,
    ]);
    session.dispose();
  });

  test('queues only the latest desired state until subscription', () async {
    final session = store.openTypingSession(
      threadId: threadId,
      actorId: _actor,
    )!;
    final channel = transport.single;

    session.updateFocus(true);
    session.updateDraft('draft');
    session.updateDraft('');
    expect(channel.sent, isEmpty);

    channel.setSubscribed(true);
    await _flush();
    expect(channel.sent, hasLength(1));
    expect(channel.sent.single['is_typing'], isFalse);
    session.dispose();
  });

  test('reconnect flushes the current desired state silently', () async {
    final session = store.openTypingSession(
      threadId: threadId,
      actorId: _actor,
    )!;
    final channel = transport.single..setSubscribed(true);
    session.updateFocus(true);
    session.updateDraft('draft');
    await _flush();

    channel.setSubscribed(false);
    channel.setSubscribed(true);
    await _flush();
    expect(channel.sent, hasLength(2));
    expect(channel.sent.last['is_typing'], isTrue);
    session.dispose();
  });

  test('one ref-counted channel keeps screen sessions distinct', () async {
    final first = store.openTypingSession(threadId: threadId, actorId: _actor)!;
    final second = store.openTypingSession(
      threadId: threadId,
      actorId: _actor,
    )!;
    final channel = transport.single..setSubscribed(true);

    expect(transport.channels, hasLength(1));
    expect(store.debugTypingChannelReferences(threadId), 2);
    first.updateFocus(true);
    first.updateDraft('one');
    second.updateFocus(true);
    second.updateDraft('two');
    await _flush();
    expect(
      channel.sent.map((event) => event['session_id']).toSet(),
      hasLength(2),
    );

    first.dispose();
    await _flush();
    expect(store.debugTypingChannelReferences(threadId), 1);
    expect(channel.closed, isFalse);
    second.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(channel.closed, isTrue);
  });

  test('disposal drains the final stopped event before closing', () async {
    final session = store.openTypingSession(
      threadId: threadId,
      actorId: _actor,
    )!;
    final channel = transport.single
      ..sendDelay = const Duration(milliseconds: 20)
      ..setSubscribed(true);

    session.updateFocus(true);
    session.updateDraft('draft');
    session.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 55));

    expect(channel.sent.map((event) => event['is_typing']), [true, false]);
    expect(channel.closed, isTrue);
  });

  test('remote device sessions expire and stop independently', () async {
    final local = store.openTypingSession(threadId: threadId, actorId: _actor)!;
    final channel = transport.single..setSubscribed(true);
    const firstSession = 'b1000000-0000-4000-8000-000000000001';
    const secondSession = 'b1000000-0000-4000-8000-000000000002';

    channel.emit(_event(_peer, firstSession, true));
    channel.emit(_event(_peer, secondSession, true));
    expect(store.typingUserIds(threadId, excluding: _actor), [_peer]);

    channel.emit(_event(_peer, firstSession, false));
    expect(store.typingUserIds(threadId, excluding: _actor), [_peer]);
    channel.emit(_event(_peer, secondSession, false));
    expect(store.typingUserIds(threadId, excluding: _actor), isEmpty);

    channel.emit(_event(_peer, firstSession, true));
    await Future<void>.delayed(const Duration(milliseconds: 95));
    expect(store.typingUserIds(threadId, excluding: _actor), isEmpty);
    local.dispose();
  });

  test('ignores malformed and non-participant broadcasts', () {
    final local = store.openTypingSession(threadId: threadId, actorId: _actor)!;
    final channel = transport.single..setSubscribed(true);

    channel.emit({..._event(_peer, 'not-a-uuid', true)});
    channel.emit(
      _event(_outsider, 'b1000000-0000-4000-8000-000000000003', true),
    );
    channel.emit({
      ..._event(_peer, 'b1000000-0000-4000-8000-000000000004', true),
      'version': 2,
    });
    expect(store.typingUserIds(threadId, excluding: _actor), isEmpty);
    local.dispose();
  });

  test('club readers receive but cannot emit or display outsider signals', () {
    const clubId = '92000000-0000-4000-8000-000000000001';
    final club = Club(
      id: clubId,
      name: 'Typing Club',
      description: '',
      adminUserIds: const [],
      boardMemberIds: const [_peer],
    );
    clubs.add(club);
    userState.followedClubIds.add(clubId);
    addTearDown(() {
      clubs.remove(club);
      userState.followedClubIds.remove(clubId);
    });

    final local = store.openTypingSession(
      threadId: ChatStore.clubThreadId(clubId),
      actorId: _actor,
    )!;
    final channel = transport.single..setSubscribed(true);
    local.updateFocus(true);
    local.updateDraft('read only');
    expect(channel.sent, isEmpty);

    channel.emit(
      _event(_outsider, 'b1000000-0000-4000-8000-000000000005', true),
    );
    expect(
      store.typingUserIds(ChatStore.clubThreadId(clubId), excluding: _actor),
      isEmpty,
    );

    channel.emit(_event(_peer, 'b1000000-0000-4000-8000-000000000006', true));
    expect(
      store.typingUserIds(ChatStore.clubThreadId(clubId), excluding: _actor),
      [_peer],
    );
    local.dispose();
  });
}

Map<String, dynamic> _event(String actor, String session, bool typing) => {
  'version': 1,
  'actor_id': actor,
  'session_id': session,
  'is_typing': typing,
};

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeTypingTransport implements ChatTypingTransport {
  final List<_FakeTypingConnection> channels = [];

  _FakeTypingConnection get single => channels.single;

  @override
  ChatTypingConnection open({
    required String topic,
    required void Function(Map<String, dynamic>) onPayload,
    required void Function(bool) onSubscribed,
  }) {
    final channel = _FakeTypingConnection(
      topic: topic,
      onPayload: onPayload,
      onSubscribed: onSubscribed,
    );
    channels.add(channel);
    return channel;
  }
}

class _FakeTypingConnection implements ChatTypingConnection {
  _FakeTypingConnection({
    required this.topic,
    required this.onPayload,
    required this.onSubscribed,
  });

  final String topic;
  final void Function(Map<String, dynamic>) onPayload;
  final void Function(bool) onSubscribed;
  final List<Map<String, dynamic>> sent = [];
  Duration sendDelay = Duration.zero;
  bool closed = false;

  void setSubscribed(bool value) => onSubscribed(value);
  void emit(Map<String, dynamic> payload) => onPayload(payload);

  @override
  Future<void> send(Map<String, dynamic> payload) async {
    sent.add(Map<String, dynamic>.from(payload));
    if (sendDelay > Duration.zero) {
      await Future<void>.delayed(sendDelay);
    }
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
