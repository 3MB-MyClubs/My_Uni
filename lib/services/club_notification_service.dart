import '../models/event.dart';
import '../models/news_post.dart';
import '../models/notification.dart';
import 'auth_service.dart';
import 'content_store.dart';
import 'mock_data.dart';
import 'user_state.dart';

/// Generates in-app notifications for club followers when new content is published.
///
/// ARCHITECTURE NOTE (local/mock limitation):
/// User follows are persisted per-account in Hive via userPrefsService, but
/// only the currently logged-in account's prefs are loaded into memory at any
/// time. To determine which users follow a club for OTHER accounts, we fall
/// back to User.subscribedClubIds from mock_data.dart (the static seed list).
/// This means:
///   - Seed-subscribed users always receive notifications (demo-correct).
///   - The currently logged-in user's runtime follows are also respected.
///   - Runtime follows by other (not currently logged-in) accounts are not
///     visible here — a real backend would query a follows table instead.
class ClubNotificationService {
  // ── Recipient resolution ─────────────────────────────────────────────────────

  /// Returns the user IDs that should receive a notification for [clubId],
  /// excluding [excludeUserId] (the author/admin who created the content).
  List<String> _recipientIds(String clubId, String excludeUserId) {
    final ids = <String>{};

    // Source 1 — static seed subscriptions (covers all seeded user accounts).
    for (final user in users) {
      if (user.subscribedClubIds.contains(clubId)) {
        ids.add(user.id);
      }
    }

    // Source 2 — runtime follows of the currently logged-in user.
    final loggedInId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    if (loggedInId.isNotEmpty &&
        userState.followedClubIds.contains(clubId)) {
      ids.add(loggedInId);
    }

    // Exclude the content author and guard against empty string.
    ids.remove(excludeUserId);
    ids.remove('');

    return ids.toList();
  }

  /// Returns true if a notification with [notifId] already exists,
  /// preventing duplicate delivery for the same content/user pair.
  bool _alreadyNotified(String notifId) =>
      userState.dynamicNotifications.any((n) => n.id == notifId);

  /// Inserts [n] into the dynamic notification list, increments the
  /// unread counter only for the currently logged-in user, and persists.
  void _emit(AppNotification n) {
    userState.dynamicNotifications.insert(0, n);
    final currentId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    if (n.userId == currentId) {
      userState.unreadNotifications++;
    }
    contentStore.saveDynamicNotifications(userState.dynamicNotifications);
  }

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Notifies all followers of [post.clubId] that a new post was published.
  void notifyFollowersAboutPost(NewsPost post) {
    final club = clubs.firstWhere(
      (c) => c.id == post.clubId,
      orElse: () => clubs.first,
    );
    for (final userId in _recipientIds(post.clubId, post.authorId)) {
      final notifId = 'club_post_${post.id}_$userId';
      if (_alreadyNotified(notifId)) continue;
      _emit(AppNotification(
        id: notifId,
        userId: userId,
        message: '${club.name} shared a new post',
        createdAt: DateTime.now(),
        targetType: 'post',
        targetId: post.id,
        fromId: post.clubId,
      ));
    }
  }

  /// Notifies all followers of [event.clubId] that a new event was created.
  void notifyFollowersAboutEvent(Event event) {
    final club = clubs.firstWhere(
      (c) => c.id == event.clubId,
      orElse: () => clubs.first,
    );
    final authorId = event.createdByUserId ?? '';
    for (final userId in _recipientIds(event.clubId, authorId)) {
      final notifId = 'club_event_${event.id}_$userId';
      if (_alreadyNotified(notifId)) continue;
      _emit(AppNotification(
        id: notifId,
        userId: userId,
        message: '${club.name} posted a new event: ${event.title}',
        createdAt: DateTime.now(),
        targetType: 'event',
        targetId: event.id,
        fromId: event.clubId,
      ));
    }
  }

  /// Notifies all followers of [story.clubId] that a new story was posted.
  /// Routes to the club profile (no standalone story-detail screen exists).
  void notifyFollowersAboutStory(ClubStory story) {
    final club = clubs.firstWhere(
      (c) => c.id == story.clubId,
      orElse: () => clubs.first,
    );
    final authorId = story.createdByUserId ?? '';
    for (final userId in _recipientIds(story.clubId, authorId)) {
      final notifId = 'club_story_${story.id}_$userId';
      if (_alreadyNotified(notifId)) continue;
      _emit(AppNotification(
        id: notifId,
        userId: userId,
        message: '${club.name} added a new story',
        createdAt: DateTime.now(),
        targetType: 'story',
        targetId: story.clubId, // navigates to club profile
        fromId: story.clubId,
      ));
    }
  }
}

final clubNotificationService = ClubNotificationService();
