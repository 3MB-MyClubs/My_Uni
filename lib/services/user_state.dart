// Simple in-memory singleton to track per-user UI state across tab switches.
class UserState {
  final Set<String> likedPostIds = {'n1'}; // pre-seed from mock likes
  final Set<String> followedClubIds = {'c1'}; // pre-seed from mock subscriptions
  final Set<String> savedPostIds = {};
  // User-to-user follows — pre-seeded for demo (assumes Bob/u2 is logged in)
  final Set<String> followedUserIds = {'u1', 'u4'};
  int unreadNotifications = 3;

  bool isLiked(String postId) => likedPostIds.contains(postId);

  void toggleLike(String postId) {
    if (likedPostIds.contains(postId)) {
      likedPostIds.remove(postId);
    } else {
      likedPostIds.add(postId);
    }
  }

  bool isFollowing(String clubId) => followedClubIds.contains(clubId);

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
    } else {
      followedUserIds.add(userId);
    }
  }
}

final userState = UserState();
