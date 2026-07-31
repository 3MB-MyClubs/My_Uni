import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/admin_dashboard.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/event_cleanup_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Club firstClub;
  late Club secondClub;
  late NewsPost post;
  late Event event;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clubs.clear();
    newsPosts.clear();
    events.clear();

    firstClub = Club(
      id: 'club-a',
      name: 'First Club',
      description: '',
      adminUserIds: const ['owner-a'],
    );
    secondClub = Club(
      id: 'club-b',
      name: 'Second Club',
      description: '',
      adminUserIds: const ['owner-b'],
    );
    post = NewsPost(
      id: 'post-a',
      clubId: firstClub.id,
      authorId: 'owner-a',
      content: 'A post visible to the platform administrator',
      createdAt: DateTime(2026, 7, 30, 12),
    );
    event = Event(
      id: 'event-b',
      clubId: secondClub.id,
      title: 'An archived campus event',
      description: '',
      dateTime: DateTime(2025, 1, 10, 12),
      endTime: DateTime(2025, 1, 10, 14),
      location: 'Campus',
      attendeeUserIds: [],
    );
    clubs.addAll([firstClub, secondClub]);
    newsPosts.add(post);
    events.add(event);
  });

  tearDown(() async {
    clubs.clear();
    newsPosts.clear();
    events.clear();
    await authService.logout();
  });

  test('platform admin can delete content owned by every club', () {
    final platformAdmin = AppAdmin(
      id: 'platform-admin',
      name: 'ClubUp Admin',
      email: 'dev3mb@gmail.com',
      password: '',
      isPlatformAdmin: true,
    );
    authService.setClubAdmin(platformAdmin);

    expect(contentStore.canDeletePost(post.id, platformAdmin.id), isTrue);
    expect(contentStore.canDeleteEvent(event.id, platformAdmin.id), isTrue);
    expect(contentStore.canEditEvent(event.id, platformAdmin.id), isFalse);
  });

  test('ordinary club admin remains limited to their own club', () {
    final clubAdmin = AppAdmin(
      id: 'owner-a',
      name: 'First Club Admin',
      email: 'first@ku.edu.tr',
      password: '',
    );
    authService.setClubAdmin(clubAdmin);

    expect(contentStore.canDeletePost(post.id, clubAdmin.id), isTrue);
    expect(contentStore.canDeleteEvent(event.id, clubAdmin.id), isFalse);
  });

  test(
    'platform admin session retains archived events for moderation',
    () async {
      authService.setClubAdmin(
        AppAdmin(
          id: 'platform-admin',
          name: 'ClubUp Admin',
          email: 'dev3mb@gmail.com',
          password: '',
          isPlatformAdmin: true,
        ),
      );

      await eventCleanupService.cleanupExpiredEvents();

      expect(events, contains(event));
    },
  );

  testWidgets(
    'admin dashboard lists all posts and archived events with delete controls',
    (tester) async {
      authService.setClubAdmin(
        AppAdmin(
          id: 'platform-admin',
          name: 'ClubUp Admin',
          email: 'dev3mb@gmail.com',
          password: '',
          isPlatformAdmin: true,
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminDashboard(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('All posts'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('admin-post-post-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('delete-admin-post-post-a')),
        findsOneWidget,
      );

      await tester.tap(find.text('All events'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('admin-event-event-b')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('delete-admin-event-event-b')),
        findsOneWidget,
      );
    },
  );
}
