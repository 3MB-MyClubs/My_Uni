import 'package:flutter/foundation.dart';

import '../models/club.dart';
import '../models/event.dart';
import '../models/news_post.dart';
import 'checkin_store.dart';
import 'mock_data.dart';
import 'supabase_interaction_service.dart';
import 'view_tracker.dart';

class EventAttendanceStat {
  final Event event;
  final int rsvpCount;
  final int checkinCount;

  const EventAttendanceStat({
    required this.event,
    required this.rsvpCount,
    required this.checkinCount,
  });

  double get checkinRate => rsvpCount == 0 ? 0 : checkinCount / rsvpCount;
}

class PostStat {
  final NewsPost post;
  final int likes;
  final int views;

  const PostStat({required this.post, required this.likes, required this.views});
}

class ClubInsightsData {
  final int followers;
  final int totalRsvps;
  final int totalLikes;
  final int totalViews;
  final List<EventAttendanceStat> events;
  final List<PostStat> topPosts;

  const ClubInsightsData({
    required this.followers,
    required this.totalRsvps,
    required this.totalLikes,
    required this.totalViews,
    required this.events,
    required this.topPosts,
  });
}

/// Aggregates a club's engagement numbers from the same caches the rest of
/// the app maintains (member counts, likes, views, RSVPs, check-ins), with an
/// optional remote refresh of check-in counts.
class ClubInsightsService {
  ClubInsightsData compute(Club club) {
    final clubEvents = events.where((e) => e.clubId == club.id).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final clubPosts = newsPosts.where((p) => p.clubId == club.id).toList();

    final eventStats = [
      for (final event in clubEvents)
        EventAttendanceStat(
          event: event,
          rsvpCount: event.attendeeUserIds.length,
          checkinCount: checkinStore.countFor(event.id),
        ),
    ];

    final postStats =
        [
            for (final post in clubPosts)
              PostStat(
                post: post,
                likes: postLikeCount(post.id),
                views: viewTracker.viewCount(post.id),
              ),
          ]
          ..sort((a, b) => b.likes.compareTo(a.likes));

    return ClubInsightsData(
      followers: clubMemberCount(club.id),
      totalRsvps: eventStats.fold(0, (sum, s) => sum + s.rsvpCount),
      totalLikes: postStats.fold(0, (sum, s) => sum + s.likes),
      totalViews: postStats.fold(0, (sum, s) => sum + s.views),
      events: eventStats,
      topPosts: postStats.take(5).toList(),
    );
  }

  /// Pulls remote check-in counts into the local store so [compute] reflects
  /// scans made on other devices. Best-effort.
  Future<void> refreshRemote(Club club) async {
    final ids = events
        .where((e) => e.clubId == club.id)
        .map((e) => e.id)
        .toList();
    if (ids.isEmpty) return;
    try {
      await Future.wait([for (final id in ids) checkinStore.hydrate(id)]);
      await supabaseInteractionService.fetchCheckinCounts(ids);
    } catch (error) {
      debugPrint('Insights remote refresh failed: $error');
    }
  }
}

final clubInsightsService = ClubInsightsService();
