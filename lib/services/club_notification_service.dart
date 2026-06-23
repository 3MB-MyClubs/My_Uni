import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import '../models/news_post.dart';
import '../models/notification.dart';
import 'auth_service.dart';
import 'mock_data.dart';
import 'supabase_config.dart';
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
  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<List<String>> _recipientIds(
    String clubId,
    String excludeUserId,
  ) async {
    final ids = <String>{};

    final client = _client;
    if (client != null) {
      try {
        final rows = await client
            .from('club_followers')
            .select('profile_id')
            .eq('club_id', clubId);
        ids.addAll(
          rows
              .map((row) => row['profile_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty),
        );
      } catch (_) {
        // Fall back to local/demo recipients below.
      }
    }

    // Source 1 — static seed subscriptions (covers all seeded user accounts).
    for (final user in users) {
      if (user.subscribedClubIds.contains(clubId)) {
        ids.add(user.id);
      }
    }

    // Source 2 — runtime follows of the currently logged-in user.
    final loggedInId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    if (loggedInId.isNotEmpty && userState.followedClubIds.contains(clubId)) {
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
    userState.addNotification(n);
  }

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Notifies all followers of [post.clubId] that a new post was published.
  Future<void> notifyFollowersAboutPost(NewsPost post) async {
    final club = clubs.firstWhere(
      (c) => c.id == post.clubId,
      orElse: () => clubs.first,
    );
    for (final userId in await _recipientIds(post.clubId, post.authorId)) {
      final notifId = 'club_post_${post.id}_$userId';
      if (_alreadyNotified(notifId)) continue;
      _emit(
        AppNotification(
          id: notifId,
          userId: userId,
          message: '${club.name} shared a new post',
          createdAt: DateTime.now(),
          targetType: 'post',
          targetId: post.id,
          fromId: post.clubId,
        ),
      );
    }
  }

  /// Notifies all followers of [event.clubId] that a new event was created.
  Future<void> notifyFollowersAboutEvent(Event event) async {
    final club = clubs.firstWhere(
      (c) => c.id == event.clubId,
      orElse: () => clubs.first,
    );
    final authorId = event.createdByUserId ?? '';
    for (final userId in await _recipientIds(event.clubId, authorId)) {
      final notifId = 'club_event_${event.id}_$userId';
      if (_alreadyNotified(notifId)) continue;
      _emit(
        AppNotification(
          id: notifId,
          userId: userId,
          message: '${club.name} posted a new event: ${event.title}',
          createdAt: DateTime.now(),
          targetType: 'event',
          targetId: event.id,
          fromId: event.clubId,
        ),
      );
    }
  }
}

final clubNotificationService = ClubNotificationService();
