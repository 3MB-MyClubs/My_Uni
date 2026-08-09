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

  const PostStat({
    required this.post,
    required this.likes,
    required this.views,
  });
}

class ClubInsightsData {
  final int followers;
  final int totalRsvps;
  final int totalLikes;
  final int totalViews;

  /// Every post the club has published — [topPosts] only carries the leaders,
  /// so the "across N posts" notes need the real total.
  final int postCount;

  /// The first day this club has any history: its creation date when known,
  /// otherwise its earliest post or event. Every number here counts from here.
  final DateTime since;

  final List<EventAttendanceStat> events;
  final List<PostStat> topPosts;

  const ClubInsightsData({
    required this.followers,
    required this.totalRsvps,
    required this.totalLikes,
    required this.totalViews,
    required this.postCount,
    required this.since,
    required this.events,
    required this.topPosts,
  });

  int get eventCount => events.length;

  int get daysSinceStart {
    final days = DateTime.now().difference(since).inDays;
    return days < 0 ? 0 : days;
  }

  /// A club whose totals are still explained by its age rather than by how it
  /// posts. Insights shows the "counts from day one" note while this holds.
  bool get isEarlyDays => daysSinceStart < 30 || totalViews == 0;
}

/// Aggregates a club's engagement numbers from the same caches the rest of
/// the app maintains (member counts, likes, views, RSVPs, check-ins), with an
/// optional remote refresh of check-in counts.
class ClubInsightsService {
  ClubInsightsData compute(Club club) {
    return _computeFrom(
      club,
      events.where((e) => e.clubId == club.id).toList(),
      newsPosts.where((p) => p.clubId == club.id).toList(),
    );
  }

  /// Computes insights for many clubs at once, grouping [events]/[newsPosts]
  /// by club id in a single pass instead of re-scanning both full lists once
  /// per club (what calling [compute] in a loop would do).
  Map<String, ClubInsightsData> computeAll(List<Club> clubsList) {
    final eventsByClub = <String, List<Event>>{};
    for (final e in events) {
      (eventsByClub[e.clubId] ??= []).add(e);
    }
    final postsByClub = <String, List<NewsPost>>{};
    for (final p in newsPosts) {
      (postsByClub[p.clubId] ??= []).add(p);
    }
    return {
      for (final club in clubsList)
        club.id: _computeFrom(
          club,
          eventsByClub[club.id] ?? const [],
          postsByClub[club.id] ?? const [],
        ),
    };
  }

  ClubInsightsData _computeFrom(
    Club club,
    List<Event> clubEvents,
    List<NewsPost> clubPosts,
  ) {
    final sortedEvents = [...clubEvents]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final eventStats = [
      for (final event in sortedEvents)
        EventAttendanceStat(
          event: event,
          rsvpCount: event.attendeeUserIds.length,
          checkinCount: checkinStore.countFor(event.id),
        ),
    ];

    // Ranked by reach, the way the Insights screen labels the list; likes then
    // recency break ties so the order never depends on list iteration order.
    final postStats = [
      for (final post in clubPosts)
        PostStat(
          post: post,
          likes: postLikeCount(post.id),
          views: viewTracker.viewCount(post.id),
        ),
    ]..sort((a, b) {
      final byViews = b.views.compareTo(a.views);
      if (byViews != 0) return byViews;
      final byLikes = b.likes.compareTo(a.likes);
      if (byLikes != 0) return byLikes;
      return b.post.createdAt.compareTo(a.post.createdAt);
    });

    return ClubInsightsData(
      followers: clubMemberCount(club.id),
      totalRsvps: eventStats.fold(0, (sum, s) => sum + s.rsvpCount),
      totalLikes: postStats.fold(0, (sum, s) => sum + s.likes),
      totalViews: postStats.fold(0, (sum, s) => sum + s.views),
      postCount: postStats.length,
      since: _sinceFor(club, clubEvents, clubPosts),
      events: eventStats,
      topPosts: postStats.take(5).toList(),
    );
  }

  /// The earliest date we can attribute to the club. Event dates can sit in the
  /// future, so the result is never later than today — "since tomorrow" would
  /// read as a bug and would make [ClubInsightsData.daysSinceStart] useless.
  DateTime _sinceFor(
    Club club,
    List<Event> clubEvents,
    List<NewsPost> clubPosts,
  ) {
    final now = DateTime.now();
    var earliest = club.createdAt ?? now;
    for (final post in clubPosts) {
      if (post.createdAt.isBefore(earliest)) earliest = post.createdAt;
    }
    for (final event in clubEvents) {
      if (event.dateTime.isBefore(earliest)) earliest = event.dateTime;
    }
    return earliest.isAfter(now) ? now : earliest;
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
