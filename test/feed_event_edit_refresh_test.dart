import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/screens/feed_screen.dart';
import 'package:flutter_application_1/screens/this_week_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/club_admin_access.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('feed_event_edit_test_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await viewTracker.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('Home refreshes an event date and time immediately after edit', (
    tester,
  ) async {
    final originalEvents = List<Event>.from(events);
    final originalPosts = [...newsPosts];
    addTearDown(() {
      events
        ..clear()
        ..addAll(originalEvents);
      newsPosts
        ..clear()
        ..addAll(originalPosts);
      authService.logout();
    });

    final admin = clubAdmins.firstWhere(
      (candidate) => managedClubForAdmin(candidate.id) != null,
    );
    final club = managedClubForAdmin(admin.id)!;
    expect(authService.login('alice@ku.edu.tr', '111111'), isTrue);

    final now = DateTime.now();
    final initialStart = DateTime(
      now.year,
      now.month,
      now.day,
      10,
      15,
    ).add(const Duration(days: 1));
    final updatedStart = initialStart.add(
      const Duration(days: 1, hours: 8, minutes: 30),
    );
    final initial = Event(
      id: 'home-event-edit-refresh',
      clubId: club.id,
      title: 'Home Refresh Event',
      description: 'An event used to verify Home refreshes after editing.',
      dateTime: initialStart,
      endTime: initialStart.add(const Duration(hours: 2)),
      location: 'Campus',
      attendeeUserIds: const [],
      createdByUserId: admin.id,
    );
    events
      ..clear()
      ..add(initial);
    newsPosts.clear();

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FeedScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Home Refresh Event'), findsOneWidget);
    expect(find.text(_dateTimeLabel(initialStart)), findsOneWidget);

    await tester.tap(find.text('Home Refresh Event'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text(_timeRange(initialStart, initial.endTime)),
      findsOneWidget,
    );

    final updated = Event(
      id: initial.id,
      clubId: initial.clubId,
      title: initial.title,
      description: initial.description,
      dateTime: updatedStart,
      endTime: updatedStart.add(const Duration(hours: 2)),
      location: initial.location,
      attendeeUserIds: initial.attendeeUserIds,
      createdByUserId: initial.createdByUserId,
    );

    expect(contentStore.updateEvent(updated, admin.id), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_timeRange(initialStart, initial.endTime)), findsNothing);
    expect(
      find.text(_timeRange(updatedStart, updated.endTime)),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(_dateTimeLabel(initialStart)), findsNothing);
    expect(find.text(_dateTimeLabel(updatedStart)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Events tab refreshes an event date and time after edit', (
    tester,
  ) async {
    final originalEvents = List<Event>.from(events);
    addTearDown(() {
      events
        ..clear()
        ..addAll(originalEvents);
      authService.logout();
    });

    final admin = clubAdmins.firstWhere(
      (candidate) => managedClubForAdmin(candidate.id) != null,
    );
    final club = managedClubForAdmin(admin.id)!;
    expect(authService.login('alice@ku.edu.tr', '111111'), isTrue);

    final now = DateTime.now();
    final initialStart = DateTime(
      now.year,
      now.month,
      now.day,
      9,
      20,
    ).add(const Duration(days: 3));
    final updatedStart = initialStart.add(
      const Duration(days: 1, hours: 8, minutes: 25),
    );
    final initial = Event(
      id: 'events-tab-edit-refresh',
      clubId: club.id,
      title: 'Events Tab Refresh',
      description: 'An event used to verify the Events tab refreshes.',
      dateTime: initialStart,
      endTime: initialStart.add(const Duration(hours: 2)),
      location: 'Campus',
      attendeeUserIds: const [],
      createdByUserId: admin.id,
    );
    events
      ..clear()
      ..add(initial);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ThisWeekScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Events Tab Refresh'), findsOneWidget);
    expect(find.text(_dateTimeLabel(initialStart)), findsOneWidget);

    final updated = Event(
      id: initial.id,
      clubId: initial.clubId,
      title: initial.title,
      description: initial.description,
      dateTime: updatedStart,
      endTime: updatedStart.add(const Duration(hours: 2)),
      location: initial.location,
      attendeeUserIds: initial.attendeeUserIds,
      createdByUserId: initial.createdByUserId,
    );

    expect(contentStore.updateEvent(updated, admin.id), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_dateTimeLabel(initialStart)), findsNothing);
    expect(find.text(_dateTimeLabel(updatedStart)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String _dateTimeLabel(DateTime value) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final time =
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
  return '${weekdays[value.weekday - 1]}. $time';
}

String _timeRange(DateTime start, DateTime end) {
  String time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
  return '${time(start)} – ${time(end)}';
}
