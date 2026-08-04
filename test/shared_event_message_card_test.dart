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
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/widgets/shared_event_message_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late User sender;
  late User recipient;
  late Event event;
  late String threadId;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'shared_event_message_test_',
    );
    Hive.init(tempDir.path);
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
    users.addAll([sender, recipient]);
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
    await chatStore.saveAll();
    authService.logout();
    expect(authService.login(recipient.email, recipient.password), isTrue);
    chatStore.markThreadRead(threadId, recipient.id);
    await chatStore.saveAll();
  });

  tearDownAll(() async {
    await chatStore.saveAll();
    authService.logout();
    users.removeWhere((user) => user == sender || user == recipient);
    events.remove(event);
    await Hive.close();
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
}
