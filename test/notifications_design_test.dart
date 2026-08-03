import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/models/notification.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/feed_screen.dart';
import 'package:flutter_application_1/screens/notifications_screen.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:hive/hive.dart';

/// Verifies the "UniHub Notifications" design: grouped chronological feed with
/// sticky section headers, unread emphasis, the collapsible follow-request
/// strip, follow-back accessories and the caught-up footer.
void main() {
  late Directory tempDir;
  late String myId;

  const liker = ('notif-peer-1', 'Deniz Şahin');
  const follower = ('notif-peer-2', 'Ece Tunç');
  const requester = ('notif-peer-3', 'Kaan Öztürk');

  User buildPeer((String, String) person) => User(
    id: person.$1,
    name: person.$2,
    email: '${person.$1}@ku.edu.tr',
    password: '',
    role: 'student',
    subscribedClubIds: const [],
  );

  late String photoPath;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('notifications_design_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await viewTracker.initialize();
    await chatStore.initialize();
    // A real (1×1) PNG, so the preview tile can decode an actual image file.
    photoPath = '${tempDir.path}/shared-post.png';
    File(photoPath).writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await themeService.setDark(false);
    await authService.logout();
    // The mock directory ships empty, so register the session and its peers
    // directly instead of signing in as a seeded user.
    users.removeWhere((user) => user.email.endsWith('@ku.edu.tr'));
    expect(
      authService.signUp('Design Tester', 'notif.tester@ku.edu.tr', '135790'),
      isTrue,
    );
    myId = authService.currentUser!.id;
    for (final person in [liker, follower, requester]) {
      peopleService.cacheRegisteredUser(buildPeer(person));
    }

    userState.dynamicNotifications.clear();
    userState.readNotificationIds.clear();
    userState.incomingFollowRequests.clear();
    userState.followedUserIds.clear();
    userState.pendingFollowRequests.clear();

    // Two unread ("New") and one read, month-old ("This Month") alert.
    userState.dynamicNotifications.addAll([
      AppNotification(
        id: 'n-like',
        userId: myId,
        fromId: liker.$1,
        message: '${liker.$2} liked your post',
        createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
        targetType: 'post',
        targetId: 'missing-post',
      ),
      AppNotification(
        id: 'n-follow',
        userId: myId,
        fromId: follower.$1,
        message: '${follower.$2} started following you',
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
        notificationType: 'profile_follow',
        targetType: 'user',
        targetId: follower.$1,
      ),
      AppNotification(
        id: 'n-old',
        userId: myId,
        message: 'Your @ku.edu.tr email is verified',
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
        read: true,
      ),
    ]);
    userState.incomingFollowRequests[requester.$1] = 'n-request';
  });

  tearDown(() async {
    await themeService.setDark(false);
    userState.dynamicNotifications.clear();
    userState.readNotificationIds.clear();
    userState.incomingFollowRequests.clear();
    userState.followedUserIds.clear();
    userState.pendingFollowRequests.clear();
    await authService.logout();
  });

  Future<AppLocalizations> pumpScreen(WidgetTester tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const NotificationsScreen();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return l10n;
  }

  testWidgets('feed is grouped, headed by an unread count and a footer', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    // Header: title, unread pill (the two unread alerts), mark-all action.
    expect(find.text(l10n.notifications), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text(l10n.markAllRead), findsOneWidget);

    // Sticky group headers: unread alerts sit in NEW, the 12-day-old read one
    // in THIS MONTH.
    expect(find.text(l10n.notifGroupNew), findsOneWidget);
    expect(find.text(l10n.notifGroupThisMonth), findsOneWidget);
    expect(find.text(l10n.notifGroupToday), findsNothing);

    // Caught-up footer.
    expect(find.text(l10n.allCaughtUp), findsOneWidget);
    expect(find.text(l10n.notificationsAutoCleared), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mark all read empties the New group and hides the pill', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    await tester.tap(find.text(l10n.markAllRead));
    await tester.pump();

    // Unread treatment clears from newest to oldest instead of vanishing as
    // one abrupt state change.
    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const ValueKey('notification-unread-dot-n-like')),
          )
          .scale,
      0,
    );
    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const ValueKey('notification-unread-dot-n-follow')),
          )
          .scale,
      1,
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const ValueKey('notification-unread-dot-n-follow')),
          )
          .scale,
      0,
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text(l10n.markAllRead), findsNothing);
    expect(find.text(l10n.notifGroupNew), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'notifications older than the 30-day retention window are hidden',
    (tester) async {
      userState.dynamicNotifications.add(
        AppNotification(
          id: 'n-expired',
          userId: myId,
          message: 'Expired notification should not render',
          createdAt: DateTime.now().subtract(const Duration(days: 31)),
          read: true,
        ),
      );

      await pumpScreen(tester);

      expect(find.textContaining('Expired notification'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tapping an unread row marks only that notification read', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    await tester.tap(find.textContaining(liker.$2));
    await tester.pump(const Duration(milliseconds: 350));

    expect(userState.readNotificationIds, contains('n-like'));
    expect(find.text('1'), findsOneWidget);
    expect(find.text(l10n.markAllRead), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('follow requests collapse into a strip and expand on tap', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    expect(find.text(l10n.followRequests), findsOneWidget);
    // Collapsed: the requester's actions are not reachable yet.
    expect(find.text(l10n.confirm), findsNothing);

    await tester.tap(find.text(l10n.followRequests));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // The name appears twice once expanded: as the collapsed strip's subtitle
    // (the design's "first requester + N others" line) and on the row itself.
    expect(find.text(requester.$2), findsNWidgets(2));
    expect(find.text(l10n.confirm), findsOneWidget);
    expect(find.text(l10n.delete), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('follow requests can be confirmed from the expanded strip', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    await tester.tap(find.text(l10n.followRequests));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text(l10n.confirm));
    await tester.pump(const Duration(milliseconds: 250));

    expect(userState.incomingFollowRequests, isNot(contains(requester.$1)));
    expect(find.text(l10n.followRequests), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('follow requests can be deleted from the expanded strip', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    await tester.tap(find.text(l10n.followRequests));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text(l10n.delete));
    await tester.pump(const Duration(milliseconds: 250));

    expect(userState.incomingFollowRequests, isNot(contains(requester.$1)));
    expect(find.text(l10n.followRequests), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a "started following you" alert carries a follow-back button', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    // Only the follow alert gets the accessory — one button, on that row.
    expect(find.text(l10n.follow), findsOneWidget);

    // Tapping is wired up (the optimistic write is rolled back here because no
    // Supabase client exists in a widget test, so only the tap is asserted).
    await tester.tap(find.text(l10n.follow));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an already-followed actor shows the "Following" variant', (
    tester,
  ) async {
    // The design's `accessory:{kind:'follow', following:true}` state.
    userState.followedUserIds.add(follower.$1);
    final l10n = await pumpScreen(tester);

    expect(find.text(l10n.following), findsOneWidget);
    expect(find.text(l10n.follow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pending request shows the "Requested" variant', (
    tester,
  ) async {
    userState.pendingFollowRequests.add(follower.$1);
    final l10n = await pumpScreen(tester);

    expect(find.text(l10n.requested), findsOneWidget);
    expect(find.text(l10n.follow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a post shared in a DM previews its photo beside the alert', (
    tester,
  ) async {
    newsPosts.add(
      NewsPost(
        id: 'shared-post-1',
        clubId: 'c1',
        authorId: liker.$1,
        content: 'Look at this',
        createdAt: DateTime.now(),
        imagePath: photoPath,
      ),
    );
    addTearDown(() => newsPosts.removeWhere((p) => p.id == 'shared-post-1'));

    final threadId = chatStore.ensureDirectThread(myId, liker.$1);
    expect(threadId, isNotNull);
    final shared = chatStore.sendMessage(
      threadId: threadId!,
      senderId: liker.$1,
      content: '',
      kind: ChatMessageKind.postShare,
      sharedPostId: 'shared-post-1',
    );
    expect(shared, isNotNull);
    // Settles the store's debounced write so no timer outlives the test.
    await tester.runAsync(chatStore.saveAll);

    userState.dynamicNotifications.add(
      AppNotification(
        id: 'n-share',
        userId: myId,
        fromId: liker.$1,
        message: '${liker.$2} sent you a post',
        createdAt: shared!.createdAt,
        notificationType: 'direct_message',
        targetType: 'message',
        targetId: threadId,
      ),
    );

    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 50));

    // The design's 46px trailing tile, carrying the shared post's own photo.
    final tile = find.byWidgetPredicate(
      (widget) => widget is Image && widget.width == 46 && widget.height == 46,
    );
    expect(tile, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a plain text message alert gets no preview tile', (
    tester,
  ) async {
    final threadId = chatStore.ensureDirectThread(myId, follower.$1);
    final plain = chatStore.sendMessage(
      threadId: threadId!,
      senderId: follower.$1,
      content: 'hey, are you coming?',
    );
    await tester.runAsync(chatStore.saveAll);

    userState.dynamicNotifications.add(
      AppNotification(
        id: 'n-plain',
        userId: myId,
        fromId: follower.$1,
        message: '${follower.$2} sent you a message',
        createdAt: plain!.createdAt,
        notificationType: 'direct_message',
        targetType: 'message',
        targetId: threadId,
      ),
    );

    await pumpScreen(tester);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image && widget.width == 46 && widget.height == 46,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat alerts are hidden from non-participants', (tester) async {
    final outsiderGroup = chatStore.createGroupThread(
      creatorId: liker.$1,
      recipientIds: [follower.$1, requester.$1],
      customName: 'Private planning',
    );
    expect(outsiderGroup, isNotNull);

    userState.dynamicNotifications.addAll([
      AppNotification(
        id: 'wrong-direct-recipient',
        userId: myId,
        fromId: liker.$1,
        message: 'Private direct message preview',
        createdAt: DateTime.now(),
        notificationType: 'direct_message',
        targetType: 'message',
        targetId: ChatStore.dmThreadId(liker.$1, follower.$1),
      ),
      AppNotification(
        id: 'wrong-group-recipient',
        userId: myId,
        fromId: liker.$1,
        message: 'Private group message preview',
        createdAt: DateTime.now(),
        notificationType: 'group_message',
        targetType: 'message',
        targetId: outsiderGroup,
      ),
    ]);

    await pumpScreen(tester);

    expect(find.text('Private direct message preview'), findsNothing);
    expect(find.text('Private group message preview'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(chatStore.saveAll);
  });

  testWidgets('opening one chat removes only that conversation alert', (
    tester,
  ) async {
    final openedThread = chatStore.ensureDirectThread(myId, liker.$1)!;
    final otherThread = chatStore.ensureDirectThread(myId, follower.$1)!;
    await tester.runAsync(chatStore.saveAll);
    userState.dynamicNotifications.addAll([
      AppNotification(
        id: 'opened-chat-alert',
        userId: myId,
        fromId: liker.$1,
        message: 'Alert from the opened conversation',
        createdAt: DateTime.now(),
        notificationType: 'direct_message',
        targetType: 'message',
        targetId: openedThread,
      ),
      AppNotification(
        id: 'other-chat-alert',
        userId: myId,
        fromId: follower.$1,
        message: 'Alert from another conversation',
        createdAt: DateTime.now(),
        notificationType: 'direct_message',
        targetType: 'message',
        targetId: otherThread,
      ),
    ]);

    userState.markChatThreadNotificationsRead(
      threadId: openedThread,
      userId: myId,
    );
    await pumpScreen(tester);

    expect(find.text('Alert from the opened conversation'), findsNothing);
    // The normal two unread setup rows plus the untouched other-chat alert.
    expect(find.text('3'), findsOneWidget);
    expect(userState.readNotificationIds, contains('opened-chat-alert'));
    expect(userState.readNotificationIds, isNot(contains('other-chat-alert')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'club activity uses the club photo while reactions use the student photo',
    (tester) async {
      const clubId = 'notification-club';
      const postId = 'notification-club-post';
      clubs.add(
        Club(
          id: clubId,
          name: 'KU Robotics',
          description: 'Robotics club',
          adminUserIds: const [],
        ),
      );
      newsPosts.add(
        NewsPost(
          id: postId,
          clubId: clubId,
          authorId: clubId,
          content: 'Workshop registrations are open',
          createdAt: DateTime.now(),
        ),
      );
      userState.clubPhotoPaths[clubId] = photoPath;
      userState.dynamicNotifications.addAll([
        AppNotification(
          id: 'n-club-post',
          userId: myId,
          message: 'KU Robotics posted something new',
          createdAt: DateTime.now(),
          notificationType: 'club_post',
          targetType: 'post',
          targetId: postId,
        ),
        AppNotification(
          id: 'n-student-reaction',
          userId: myId,
          fromId: liker.$1,
          message: '${liker.$2} liked your post',
          createdAt: DateTime.now(),
          notificationType: 'post_like',
          targetType: 'post',
          targetId: postId,
        ),
      ]);
      addTearDown(() {
        clubs.removeWhere((club) => club.id == clubId);
        newsPosts.removeWhere((post) => post.id == postId);
        userState.clubPhotoPaths.remove(clubId);
      });

      await pumpScreen(tester);

      expect(
        find.byKey(const ValueKey('notification-club-avatar-n-club-post')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('notification-user-avatar-n-student-reaction'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pull to refresh presents the updated confirmation', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 180));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(find.byKey(const ValueKey('pull-refresh-success')), findsOneWidget);
    final toastOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.text(l10n.updatedJustNow),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(toastOpacity.opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification center renders in both light and dark themes', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      LightColors.background,
    );

    await themeService.setDark(true);
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      DarkColors.background,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Home bell reacts to new alerts and opens with a badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeedScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    final bell = find.byKey(const ValueKey('home-notifications-bell'));
    expect(bell, findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    userState.addNotification(
      AppNotification(
        id: 'n-new-reaction',
        userId: myId,
        message: 'A new notification arrived',
        createdAt: DateTime.now(),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('3'), findsOneWidget);
    expect(
      tester
          .widget<Transform>(find.byKey(const ValueKey('top-bar-icon-motion')))
          .transform
          .storage[1]
          .abs(),
      greaterThan(0.01),
    );
    expect(find.byKey(const ValueKey('top-bar-badge-3')), findsOneWidget);

    // Pressing while the automatic jiggle is active should still open alerts.
    await tester.tap(bell);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final bellMotion = tester.widget<Transform>(
      find.byKey(const ValueKey('top-bar-icon-motion')),
    );
    expect(bellMotion.transform.storage[1].abs(), greaterThan(0.01));
    expect(find.byType(NotificationsScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
