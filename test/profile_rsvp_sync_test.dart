import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/screens/student_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/rsvp_store.dart';
import 'package:flutter_application_1/services/student_activity_service.dart';
import 'package:flutter_application_1/services/supabase_interaction_service.dart';
import 'package:flutter_application_1/services/supabase_read_cache.dart';
import 'package:flutter_application_1/widgets/rsvp_button.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeInteractionService extends SupabaseInteractionService {
  int calls = 0;
  final List<bool> requestedStates = [];
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<void> setEventRsvp({
    required String profileId,
    required String eventId,
    required bool attending,
  }) async {
    calls++;
    requestedStates.add(attending);
    final pending = gate;
    if (pending != null) await pending.future;
    if (fail) throw StateError('simulated RSVP failure');
  }
}

Event _event({
  required String id,
  required String userId,
  bool attending = true,
}) {
  final start = DateTime.now().add(const Duration(days: 2));
  return Event(
    id: id,
    // Matching the actor avoids creating a local club notification in this
    // service-level test; RSVP state is the behavior under test.
    clubId: userId,
    title: 'Profile RSVP event',
    description: 'Profile RSVP regression test',
    dateTime: start,
    endTime: start.add(const Duration(hours: 2)),
    location: 'Campus',
    attendeeUserIds: attending ? [userId] : [],
  );
}

void main() {
  late String userId;
  late List<Event> originalEvents;
  late Directory hiveDir;
  const notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('profile_rsvp_sync_');
    Hive.init(hiveDir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (call) async {
          if (call.method == 'initialize') return true;
          return null;
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, null);
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await authService.logout();
    originalEvents = List<Event>.from(events);
    events.clear();
    supabaseEventRsvpCounts.clear();
    supabaseReadCache.clear();
    rsvpStore.clear();
    supabaseReadCache.clear();
    studentActivityService.clearRemoteHistory();

    final email = 'profile-rsvp-${DateTime.now().microsecondsSinceEpoch}@test';
    expect(authService.signUp('Profile RSVP Tester', email, '135790'), isTrue);
    userId = authService.currentUser!.id;
  });

  tearDown(() async {
    events
      ..clear()
      ..addAll(originalEvents);
    rsvpStore.clear();
    studentActivityService.clearRemoteHistory();
    await authService.logout();
  });

  test('profile event can un-RSVP even when its event is not global', () async {
    final activity = StudentActivityService();
    final fake = _FakeInteractionService();
    final store = RsvpStore(
      interactionService: fake,
      activityService: activity,
    );
    final event = _event(id: 'profile-only-event', userId: userId);

    // This models a profile history event that was fetched separately and is
    // not present in the app-wide feed snapshot.
    store.seed(event.id, true);
    final mutation = store.toggle(event.id, userId, event: event);

    expect(store.isAttending(event.id), isFalse);
    expect(store.isPending(event.id), isTrue);
    await mutation;

    expect(fake.calls, 1);
    expect(fake.requestedStates, [false]);
    expect(store.isAttending(event.id), isFalse);
    expect(events.single.attendeeUserIds, isEmpty);
    expect(activity.summaryFor(userId).isEmpty, isTrue);
  });

  test('failed un-RSVP restores the previous state and profile row', () async {
    final activity = StudentActivityService();
    final fake = _FakeInteractionService()..fail = true;
    final store = RsvpStore(
      interactionService: fake,
      activityService: activity,
    );
    final event = _event(id: 'rollback-event', userId: userId);
    events.add(event);
    store.seed(event.id, true);

    final mutation = store.toggle(event.id, userId, event: event);
    expect(store.isAttending(event.id), isFalse);
    await mutation;

    expect(store.isAttending(event.id), isTrue);
    expect(events.single.attendeeUserIds, [userId]);
    expect(activity.summaryFor(userId).eventIdList, [event.id]);
  });

  test(
    'an RSVP update from another surface removes the profile event',
    () async {
      final activity = StudentActivityService();
      final fake = _FakeInteractionService();
      final store = RsvpStore(
        interactionService: fake,
        activityService: activity,
      );
      final event = _event(id: 'cross-screen-event', userId: userId);
      events.add(event);
      store.seed(event.id, true);

      expect(activity.summaryFor(userId).eventIdList, [event.id]);
      await store.toggle(event.id, userId, event: event);

      expect(activity.summaryFor(userId).isEmpty, isTrue);
      expect(events.single.attendeeUserIds, isEmpty);
    },
  );

  testWidgets('profile activity omits the inline RSVP control', (tester) async {
    final event = _event(id: 'profile-control-event', userId: userId);
    events.add(event);
    rsvpStore.seed(event.id, true);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StudentProfileScreen(
            onSettings: () {},
            data: StudentProfileData(
              userId: userId,
              initials: 'PR',
              name: 'Profile RSVP Tester',
              graduation: 'Class of 27',
              major: 'Computer Engineering',
              year: 'Class of 27',
              bio: 'Testing RSVP controls.',
              clubs: 0,
              followers: 0,
              following: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Profile RSVP event'),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Profile RSVP event'), findsOneWidget);
    expect(find.byType(RsvpButton), findsNothing);
  });

  test('rapid duplicate taps share one mutation and do not race', () async {
    final fake = _FakeInteractionService()..gate = Completer<void>();
    final store = RsvpStore(interactionService: fake);
    final event = _event(
      id: 'duplicate-tap-event',
      userId: userId,
      attending: false,
    );
    events.add(event);
    store.seed(event.id, false);

    final first = store.toggle(event.id, userId, event: event);
    final second = store.toggle(event.id, userId, event: event);

    expect(identical(first, second), isTrue);
    expect(fake.calls, 1);
    expect(store.isAttending(event.id), isTrue);

    fake.gate!.complete();
    await Future.wait([first, second]);
    expect(fake.requestedStates, [true]);
    expect(store.isAttending(event.id), isTrue);
  });

  test('RSVP mutation invalidates cached profile/attendee reads', () async {
    final cacheKey = 'rsvp-events:$userId';
    const feedCacheKey = 'feed-v2:first:false:25';
    var reads = 0;
    var feedReads = 0;
    Future<Set<String>> readCache() =>
        supabaseReadCache.getOrFetch<Set<String>>(
          key: cacheKey,
          ttl: const Duration(minutes: 1),
          fetch: () async {
            reads++;
            return {'cached-event'};
          },
        );

    await readCache();
    await supabaseReadCache.getOrFetch<String>(
      key: feedCacheKey,
      ttl: const Duration(minutes: 1),
      fetch: () async {
        feedReads++;
        return 'cached-feed';
      },
    );
    await supabaseInteractionService.setEventRsvp(
      profileId: userId,
      eventId: 'cached-event',
      attending: false,
    );
    await readCache();
    await supabaseReadCache.getOrFetch<String>(
      key: feedCacheKey,
      ttl: const Duration(minutes: 1),
      fetch: () async {
        feedReads++;
        return 'refetched-feed';
      },
    );

    expect(reads, 2);
    expect(feedReads, 2);
  });
}

extension on StudentActivitySummary {
  List<String> get eventIdList => all.map((entry) => entry.eventId).toList();
}
