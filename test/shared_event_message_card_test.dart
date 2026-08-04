import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/event_detail_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/widgets/shared_event_message_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late User sender;
  late User recipient;
  late User groupPeer;
  late Event event;
  late String threadId;
  late String groupThreadId;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'shared_event_message_test_',
    );
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();

    sender = User(
      id: 'shared-event-sender',
      name: 'Event Sender',
      email: 'shared.event.sender@ku.edu.tr',
      password: '135790',
      role: 'student',
      subscribedClubIds: const [],
    );
    recipient = User(
      id: 'shared-event-recipient',
      name: 'Event Recipient',
      email: 'shared.event.recipient@ku.edu.tr',
      password: '246802',
      role: 'student',
      subscribedClubIds: const [],
    );
    groupPeer = User(
      id: 'shared-event-group-peer',
      name: 'Group Peer',
      email: 'shared.event.group.peer@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [],
    );
    users.addAll([sender, recipient, groupPeer]);
    expect(authService.login(sender.email, sender.password), isTrue);

    final start = DateTime.now().add(const Duration(days: 5));
    event = Event(
      id: 'shared-event-message',
      clubId: 'c1',
      title: 'Campus Futures Forum',
      description: 'A student-led conversation about campus life.',
      dateTime: start,
      endTime: start.add(const Duration(hours: 2)),
      location: 'Student Center',
      attendeeUserIds: const [],
    );
    events.add(event);

    threadId = chatStore.ensureDirectThread(sender.id, recipient.id)!;
    final message = chatStore.sendMessage(
      threadId: threadId,
      senderId: sender.id,
      content: '${event.title}\nkuclubs://event/${event.id}',
      kind: ChatMessageKind.event,
      title: event.title,
      eventId: event.id,
    );
    expect(message, isNotNull);

    groupThreadId = chatStore.createGroupThread(
      creatorId: sender.id,
      recipientIds: [recipient.id, groupPeer.id],
      customName: 'Event Planning',
    )!;
    final groupMessage = chatStore.sendMessage(
      threadId: groupThreadId,
      senderId: sender.id,
      content: '${event.title}\nkuclubs://event/${event.id}',
      kind: ChatMessageKind.event,
      title: event.title,
      eventId: event.id,
    );
    expect(groupMessage, isNotNull);
    await chatStore.saveAll();
    authService.logout();
    expect(authService.login(recipient.email, recipient.password), isTrue);
    chatStore.markThreadRead(threadId, recipient.id);
    chatStore.markThreadRead(groupThreadId, recipient.id);
    await chatStore.saveAll();
  });

  tearDownAll(() async {
    await chatStore.saveAll();
    authService.logout();
    users.removeWhere(
      (user) => user == sender || user == recipient || user == groupPeer,
    );
    events.remove(event);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('event message renders a rich card and opens the event', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatThreadScreen(threadId: threadId),
        ),
      ),
    );
    await tester.pump();

    final card = find.byKey(
      const ValueKey('shared-event-card-shared-event-message'),
    );
    expect(card, findsOneWidget);
    expect(find.byType(SharedEventMessageCard), findsOneWidget);
    expect(find.text('Campus Futures Forum'), findsOneWidget);
    expect(find.text('Student Center'), findsOneWidget);
    expect(find.textContaining('kuclubs://event/'), findsNothing);

    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('group recipient can open the shared event card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatThreadScreen(threadId: groupThreadId),
        ),
      ),
    );
    await tester.pump();

    final card = find.byKey(
      const ValueKey('shared-event-card-shared-event-message'),
    );
    expect(card, findsOneWidget);
    expect(find.textContaining('kuclubs://event/'), findsNothing);

    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recipient loads an event missing from the local feed cache', (
    tester,
  ) async {
    events.remove(event);
    addTearDown(() {
      if (!events.contains(event)) events.add(event);
    });
    var resolveCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SharedEventMessageCard(
              eventId: event.id,
              resolveEvent: (eventId) async {
                resolveCalls++;
                expect(eventId, event.id);
                return event;
              },
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(ValueKey('shared-event-loading-${event.id}')),
      findsOneWidget,
    );
    await tester.pump();

    final card = find.byKey(ValueKey('shared-event-card-${event.id}'));
    expect(card, findsOneWidget);
    expect(resolveCalls, 1);
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(EventDetailScreen), findsOneWidget);
  });

  test('legacy plaintext event links still resolve to a card id', () {
    final message = ChatMessage(
      id: 'legacy-event-message',
      threadId: 'dm:one|two',
      senderId: 'one',
      content: 'Campus Futures Forum\nkuclubs://event/${event.id}',
      createdAt: DateTime.now(),
    );

    expect(message.linkedEventId, event.id);
  });
}
