import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import 'content_store.dart';

// Simple in-memory singleton to track per-user UI state across tab switches.
class UserState {
  final Set<String> likedPostIds = {'n1'}; // pre-seed from mock likes
  final Set<String> followedClubIds = {'c1'}; // pre-seed from mock subscriptions
  final Set<String> savedPostIds = {};
  // User-to-user follows — pre-seeded for demo (assumes Bob/u2 is logged in)
  final Set<String> followedUserIds = {'u1', 'u4'};
  int unreadNotifications = 3;

  // Profile banner image paths keyed by user/admin id.
  final Map<String, String> bannerPaths = {};

  // Profile photo image paths keyed by user/admin id.
  final Map<String, String> profilePhotoPaths = {};

  // ── Privacy ──────────────────────────────────────────────────────────────────

  /// Whether the logged-in user's own profile is private.
  bool isPrivate = false;

  /// User IDs that have private profiles (demo: u3 is private by default).
  final Set<String> privateUserIds = {'u3'};

  bool isProfilePrivate(String userId) => privateUserIds.contains(userId);

  // ── Follow requests ───────────────────────────────────────────────────────────

  /// IDs I have sent a pending follow request to (not yet accepted).
  final Set<String> pendingFollowRequests = {};

  /// IDs where I have already seen the "they don't follow you back" notice,
  /// so we don't show it again on subsequent follows.
  final Set<String> shownFollowNotice = {};

  /// Incoming follow requests waiting for MY decision.
  /// Key = fromId (who sent me the request), Value = notification id.
  final Map<String, String> incomingFollowRequests = {};

  bool hasPendingRequest(String userId) =>
      pendingFollowRequests.contains(userId);

  /// Called when user [fromId] sends a follow request to [toId].
  /// Adds a follow_request notification to the target's alerts.
  void sendFollowRequest(String fromId, String toId, String fromName) {
    pendingFollowRequests.add(toId);
    final notifId =
        'follow_req_${fromId}_${DateTime.now().millisecondsSinceEpoch}';
    incomingFollowRequests[fromId] = notifId;
    final notif = AppNotification(
      id: notifId,
      userId: toId,
      message: '$fromName wants to follow you.',
      createdAt: DateTime.now(),
      targetType: 'follow_request',
      targetId: fromId,
      fromId: fromId,
    );
    addFollowRequestNotification(notif);
  }

  /// Accept an incoming follow request from [fromId].
  void acceptFollowRequest(String fromId, String toId) {
    pendingFollowRequests.remove(toId);
    incomingFollowRequests.remove(fromId);
    followedUserIds.add(toId);
    acceptedMessageRequests.add('$fromId:$toId');
    // Notify the requester that their request was accepted.
    final notif = AppNotification(
      id: 'follow_accepted_${fromId}_${DateTime.now().millisecondsSinceEpoch}',
      userId: fromId,
      message: 'Your follow request was accepted.',
      createdAt: DateTime.now(),
      targetType: 'follow_accepted',
      targetId: toId,
    );
    addMessageNotification(notif);
  }

  /// Decline an incoming follow request from [fromId].
  void declineFollowRequest(String fromId) {
    pendingFollowRequests.remove(fromId);
    incomingFollowRequests.remove(fromId);
  }

  // ── Notification helpers ──────────────────────────────────────────────────────

  /// Adds a follow-request notification WITHOUT firing the in-app banner
  /// (it already shows as a card in the alerts tab).
  void addFollowRequestNotification(AppNotification n) {
    dynamicNotifications.insert(0, n);
    unreadNotifications++;
    contentStore.saveDynamicNotifications(dynamicNotifications);
  }

  // ── Board member requests ─────────────────────────────────────────────────────

  /// Pending board-member requests sent by this user, stored as "userId:clubId".
  /// Removed when the request is approved or declined.
  final Set<String> pendingBoardRequests = {};

  bool hasPendingBoardRequest(String userId, String clubId) =>
      pendingBoardRequests.contains('$userId:$clubId');

  void sendBoardRequest(String userId, String clubId) =>
      pendingBoardRequests.add('$userId:$clubId');

  void removeBoardRequest(String userId, String clubId) =>
      pendingBoardRequests.remove('$userId:$clubId');

  // ── Board member cooldown ─────────────────────────────────────────────────────

  /// Records when a board-member request was declined, keyed "userId:clubId".
  /// Persisted so the cooldown survives app restarts.
  final Map<String, DateTime> boardDeclinedAt = {};

  void recordBoardDecline(String userId, String clubId) =>
      boardDeclinedAt['$userId:$clubId'] = DateTime.now();

  bool isBoardCooldownActive(String userId, String clubId) {
    final dt = boardDeclinedAt['$userId:$clubId'];
    if (dt == null) return false;
    return DateTime.now().difference(dt).inDays < 60;
  }

  DateTime? boardCooldownEnds(String userId, String clubId) {
    final dt = boardDeclinedAt['$userId:$clubId'];
    if (dt == null) return null;
    return dt.add(const Duration(days: 60));
  }

  // ── Message requests ──────────────────────────────────────────────────────────

  /// Accepted message request pairs stored as "myId:theirId".
  final Set<String> acceptedMessageRequests = {};

  bool hasAcceptedMessageRequest(String myId, String theirId) =>
      acceptedMessageRequests.contains('$myId:$theirId');

  void acceptMessageRequest(String myId, String theirId) =>
      acceptedMessageRequests.add('$myId:$theirId');

  // ── Notifications ─────────────────────────────────────────────────────────────

  /// Dynamic notifications generated at runtime (e.g. incoming messages).
  final List<AppNotification> dynamicNotifications = [];

  /// Fires whenever a new incoming-message notification is added.
  final ValueNotifier<AppNotification?> incomingMessageNotifier =
      ValueNotifier(null);

  void addMessageNotification(AppNotification n) {
    dynamicNotifications.insert(0, n);
    unreadNotifications++;
    contentStore.saveDynamicNotifications(dynamicNotifications);
    incomingMessageNotifier.value = n;
    Future.delayed(const Duration(seconds: 4),
        () => incomingMessageNotifier.value = null);
  }

  // ── Likes / saves ─────────────────────────────────────────────────────────────

  bool isLiked(String postId) => likedPostIds.contains(postId);

  void toggleLike(String postId) {
    if (likedPostIds.contains(postId)) {
      likedPostIds.remove(postId);
    } else {
      likedPostIds.add(postId);
    }
  }

  bool isFollowing(String clubId) => followedClubIds.contains(clubId);

  String? get activeClubId =>
      followedClubIds.isEmpty ? null : followedClubIds.first;

  void joinClub(String clubId, {bool exclusive = false}) {
    if (exclusive) followedClubIds.clear();
    followedClubIds.add(clubId);
  }

  void leaveClub(String clubId) => followedClubIds.remove(clubId);

  void toggleFollow(String clubId) {
    if (followedClubIds.contains(clubId)) {
      followedClubIds.remove(clubId);
    } else {
      followedClubIds.add(clubId);
    }
  }

  bool isSaved(String postId) => savedPostIds.contains(postId);

  void toggleSave(String postId) {
    if (savedPostIds.contains(postId)) {
      savedPostIds.remove(postId);
    } else {
      savedPostIds.add(postId);
    }
  }

  bool isFollowingUser(String userId) => followedUserIds.contains(userId);

  void toggleFollowUser(String userId) {
    if (followedUserIds.contains(userId)) {
      followedUserIds.remove(userId);
      pendingFollowRequests.remove(userId);
    } else {
      followedUserIds.add(userId);
    }
  }
}

final userState = UserState();
