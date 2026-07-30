import '../models/app_admin.dart';
import '../models/club.dart';
import '../models/comment.dart';
import '../models/event.dart';
import '../models/like.dart';
import '../models/news_post.dart';
import '../models/notification.dart';
import '../models/share.dart';
import '../models/subscription.dart';
import '../models/user.dart';

/// Runtime data registries populated by Supabase and user actions.
///
/// This module keeps its historical filename to avoid a broad import-only
/// migration. It intentionally contains no bundled users, credentials, clubs,
/// posts, events, interactions, notifications, or image URLs.
final List<User> users = [];
final List<Club> clubs = [];
final List<Event> events = [];
final List<NewsPost> newsPosts = [];
final List<Comment> comments = [];
final List<Like> likes = [];
final List<Share> shares = [];
final List<Subscription> subscriptions = [];
final List<AppNotification> notifications = [];

/// Empty sentinel used by code paths that distinguish a platform admin from a
/// club admin. A real authenticated platform admin replaces it at runtime.
var appAdmin = AppAdmin(id: '', name: '', email: '', password: '');

/// Authenticated club administrators are registered here at runtime.
final List<AppAdmin> clubAdmins = [];

double postScore(String postId) {
  final uniqueLikers = likes
      .where((like) => like.postId == postId)
      .map((like) => like.userId)
      .toSet()
      .length;
  final shareCount = shares.where((share) => share.targetId == postId).length;
  return uniqueLikers + (shareCount * 2.0);
}

double eventScore(String eventId) {
  final event = events.firstWhere((event) => event.id == eventId);
  final uniqueAttendees = event.attendeeUserIds.toSet().length;
  final shareCount = shares.where((share) => share.targetId == eventId).length;
  final upcomingBonus = event.dateTime.isAfter(DateTime.now()) ? 3.0 : 0.0;
  return (uniqueAttendees * 1.5) + (shareCount * 2.0) + upcomingBonus;
}

final Map<String, int> supabaseClubMemberCounts = {};
final Map<String, int> supabasePostLikeCounts = {};

List<User> clubMembers(String clubId) {
  final memberIds = <String>{
    for (final subscription in subscriptions)
      if (subscription.clubId == clubId) subscription.userId,
    for (final user in users)
      if (user.subscribedClubIds.contains(clubId)) user.id,
  };
  return users.where((user) => memberIds.contains(user.id)).toList();
}

int clubMemberCount(String clubId) =>
    supabaseClubMemberCounts[clubId] ?? clubMembers(clubId).length;

int postLikeCount(String postId) =>
    supabasePostLikeCounts[postId] ??
    likes.where((like) => like.postId == postId).length;

int postShareCount(String targetId) =>
    shares.where((share) => share.targetId == targetId).length;

int _clubIndexSignature = 0;
Map<String, Club> _clubById = const {};
Map<String, int> _clubOrdinalById = const {};

void _ensureClubIndex() {
  final signature = Object.hash(
    clubs.length,
    clubs.isEmpty ? 0 : identityHashCode(clubs.first),
  );
  if (signature == _clubIndexSignature &&
      _clubById.isNotEmpty == clubs.isNotEmpty) {
    return;
  }

  _clubIndexSignature = signature;
  final byId = <String, Club>{};
  final ordinalById = <String, int>{};
  for (var index = 0; index < clubs.length; index++) {
    byId.putIfAbsent(clubs[index].id, () => clubs[index]);
    ordinalById.putIfAbsent(clubs[index].id, () => index);
  }
  _clubById = byId;
  _clubOrdinalById = ordinalById;
}

Club? clubForId(String id) {
  _ensureClubIndex();
  return _clubById[id];
}

int clubOrdinal(String id) {
  _ensureClubIndex();
  return _clubOrdinalById[id] ?? -1;
}
