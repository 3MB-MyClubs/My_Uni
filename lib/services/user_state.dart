import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/notification.dart';
import 'content_store.dart';

// Global state singleton. Extends ChangeNotifier so any ListenableBuilder
// that wraps a follow button will rebuild instantly when state changes,
// regardless of which screen triggered the mutation.
class UserState extends ChangeNotifier {
  final Set<String> likedPostIds = {'n1'}; // pre-seed from mock likes
  final Set<String> followedClubIds = {
    'c1',
  }; // pre-seed from mock subscriptions
  final Set<String> savedPostIds = {};
  // User-to-user follows — pre-seeded for demo (assumes Bob/u2 is logged in)
  final Set<String> followedUserIds = {'u1', 'u4'};
  int unreadNotifications = 3;

  // Profile photo image paths keyed by user/admin id.
  final Map<String, String> profilePhotoPaths = {};

  // Mock network photo URLs for demo users (seeded at startup, overridden by a real upload).
  final Map<String, String> mockPhotoUrls = {
    'u1': 'https://i.pravatar.cc/150?img=47',
    'u2': 'https://i.pravatar.cc/150?img=11',
    'u3': 'https://i.pravatar.cc/150?img=15',
    'u4': 'https://i.pravatar.cc/150?img=44',
    'u6': 'https://i.pravatar.cc/150?img=5',
    'u8': 'https://i.pravatar.cc/150?img=9',
    'u10': 'https://i.pravatar.cc/150?img=32',
    'u11': 'https://i.pravatar.cc/150?img=21',
    'u13': 'https://i.pravatar.cc/150?img=53',
    'u14': 'https://i.pravatar.cc/150?img=58',
  };

  // Student bios keyed by user id.
  final Map<String, String> bios = {};

  // Student majors keyed by user id.
  final Map<String, String> majors = {};

  // Student years keyed by user id.
  final Map<String, String> years = {};

  // Student interest topics keyed by user id.
  final Map<String, List<String>> interests = {};

  // Student minor program(s) keyed by user id.
  final Map<String, List<String>> minors = {};

  // Student double-major program(s) keyed by user id.
  final Map<String, List<String>> doubleMajors = {};

  // Club profile photo paths keyed by club id.
  final Map<String, String> clubPhotoPaths = {};

  /// Notifies listeners after a club's editable info (e.g. description) changed
  /// in place, so every screen showing the club rebuilds.
  void bumpClubInfo() => notifyListeners();

  /// Sets the club photo path for [clubId] and notifies all listeners.
  void setClubPhoto(String clubId, String path) {
    // Club photos are overwritten at a stable path. Remove the old decoded
    // bitmap so every ClubAvatar immediately displays the newly edited photo.
    PaintingBinding.instance.imageCache.evict(FileImage(File(path)));
    clubPhotoPaths[clubId] = path;
    notifyListeners();
  }

  /// Sets the profile photo path for [userId] and notifies all listeners.
  void setProfilePhoto(String userId, String path) {
    PaintingBinding.instance.imageCache.evict(FileImage(File(path)));
    profilePhotoPaths[userId] = path;
    notifyListeners();
  }

  /// Removes the profile photo for [userId] and notifies all listeners.
  void removeProfilePhoto(String userId) {
    final removedLocal = profilePhotoPaths.remove(userId) != null;
    final removedRemote = mockPhotoUrls.remove(userId) != null;
    if (removedLocal || removedRemote) notifyListeners();
  }

  /// Sets a remote profile photo URL for [userId] and notifies all listeners.
  void setProfilePhotoUrl(String userId, String url) {
    final value = url.trim();
    if (value.isEmpty) {
      mockPhotoUrls.remove(userId);
    } else {
      mockPhotoUrls[userId] = value;
    }
    notifyListeners();
  }

  bool hasProfilePhoto(String userId) =>
      profilePhotoPaths[userId] != null || mockPhotoUrls[userId] != null;

  /// Sets the student bio for [userId] and notifies all listeners.
  void setBio(String userId, String bio) {
    final value = bio.trim();
    if (value.isEmpty) {
      bios.remove(userId);
    } else {
      bios[userId] = value;
    }
    notifyListeners();
  }

  /// Sets the student major for [userId] and notifies all listeners.
  void setMajor(String userId, String major) {
    final value = major.trim();
    if (value.isEmpty) {
      majors.remove(userId);
    } else {
      majors[userId] = value;
    }
    notifyListeners();
  }

  /// Sets the student year for [userId] and notifies all listeners.
  void setYear(String userId, String year) {
    final value = year.trim();
    if (value.isEmpty) {
      years.remove(userId);
    } else {
      years[userId] = value;
    }
    notifyListeners();
  }

  /// Sets the student interest topics for [userId] and notifies all listeners.
  void setInterests(String userId, List<String> topics) {
    final values = topics.map((topic) => topic.trim()).where((topic) {
      return topic.isNotEmpty;
    }).toList();
    if (values.isEmpty) {
      interests.remove(userId);
    } else {
      interests[userId] = values;
    }
    notifyListeners();
  }

  /// Sets the student minor program(s) for [userId] and notifies all listeners.
  void setMinors(String userId, List<String> values) {
    final v = values.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (v.isEmpty) {
      minors.remove(userId);
    } else {
      minors[userId] = v;
    }
    notifyListeners();
  }

  /// Sets the student double-major program(s) for [userId] and notifies listeners.
  void setDoubleMajors(String userId, List<String> values) {
    final v = values.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (v.isEmpty) {
      doubleMajors.remove(userId);
    } else {
      doubleMajors[userId] = v;
    }
    notifyListeners();
  }

  // ── Usernames ─────────────────────────────────────────────────────────────────

  /// Custom usernames keyed by user/admin id. If absent the real name is used.
  final Map<String, String> usernames = {};

  /// Returns the custom username for [userId] if set, otherwise null.
  String? usernameFor(String userId) => usernames[userId];

  /// Sets [username] for [userId] and notifies listeners.
  void setUsername(String userId, String username) {
    usernames[userId] = username;
    notifyListeners();
  }

  /// Removes the custom username for [userId] (reverts to real name).
  void clearUsername(String userId) {
    usernames.remove(userId);
    notifyListeners();
  }

  /// Returns true if [username] is already taken by someone other than [excludeId].
  bool isUsernameTaken(String username, {String? excludeId}) {
    final lower = username.toLowerCase();
    return usernames.entries.any(
      (e) => e.key != excludeId && e.value.toLowerCase() == lower,
    );
  }

  /// The display name to show publicly for [userId]: username if set, else [fallbackName].
  String displayNameFor(String userId, String fallbackName) =>
      usernames[userId] ?? fallbackName;

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
    notifyListeners();
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
    notifyListeners();
  }

  /// Decline an incoming follow request from [fromId].
  void declineFollowRequest(String fromId) {
    pendingFollowRequests.remove(fromId);
    incomingFollowRequests.remove(fromId);
    notifyListeners();
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
  final ValueNotifier<AppNotification?> incomingMessageNotifier = ValueNotifier(
    null,
  );

  void addMessageNotification(AppNotification n) {
    dynamicNotifications.insert(0, n);
    unreadNotifications++;
    contentStore.saveDynamicNotifications(dynamicNotifications);
    incomingMessageNotifier.value = n;
    Future.delayed(
      const Duration(seconds: 4),
      () => incomingMessageNotifier.value = null,
    );
  }

  // ── Pinned club posts (global; set by a club's admin) ───────────────────────
  final Set<String> pinnedPostIds = {};

  bool isPostPinned(String postId) => pinnedPostIds.contains(postId);

  void togglePinnedPost(String postId) {
    if (!pinnedPostIds.remove(postId)) pinnedPostIds.add(postId);
    notifyListeners();
  }

  // ── Likes / saves ─────────────────────────────────────────────────────────────

  bool isLiked(String postId) => likedPostIds.contains(postId);

  void toggleLike(String postId) {
    if (likedPostIds.contains(postId)) {
      likedPostIds.remove(postId);
    } else {
      likedPostIds.add(postId);
    }
    notifyListeners();
  }

  bool isFollowing(String clubId) => followedClubIds.contains(clubId);

  String? get activeClubId =>
      followedClubIds.isEmpty ? null : followedClubIds.first;

  void joinClub(String clubId, {bool exclusive = false}) {
    if (exclusive) followedClubIds.clear();
    followedClubIds.add(clubId);
    notifyListeners();
  }

  void leaveClub(String clubId) {
    followedClubIds.remove(clubId);
    notifyListeners();
  }

  void toggleFollow(String clubId) {
    if (followedClubIds.contains(clubId)) {
      followedClubIds.remove(clubId);
    } else {
      followedClubIds.add(clubId);
    }
    notifyListeners();
  }

  bool isSaved(String postId) => savedPostIds.contains(postId);

  void toggleSave(String postId) {
    if (savedPostIds.contains(postId)) {
      savedPostIds.remove(postId);
    } else {
      savedPostIds.add(postId);
    }
    notifyListeners();
  }

  bool isFollowingUser(String userId) => followedUserIds.contains(userId);

  void replaceFollowedUsers(Iterable<String> userIds) {
    followedUserIds
      ..clear()
      ..addAll(userIds);
    notifyListeners();
  }

  void setFollowingUser(String userId, bool follow) {
    if (follow) {
      followedUserIds.add(userId);
    } else {
      followedUserIds.remove(userId);
      pendingFollowRequests.remove(userId);
    }
    notifyListeners();
  }

  void toggleFollowUser(String userId) {
    if (followedUserIds.contains(userId)) {
      followedUserIds.remove(userId);
      pendingFollowRequests.remove(userId);
    } else {
      followedUserIds.add(userId);
    }
    notifyListeners();
  }
}

final userState = UserState();
