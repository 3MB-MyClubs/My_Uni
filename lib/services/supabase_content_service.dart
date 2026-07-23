import 'package:flutter/widgets.dart' show Locale;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../models/event.dart';
import '../models/news_post.dart';
import 'locale_service.dart';
import 'mock_data.dart';
import 'poll_store.dart';
import 'supabase_config.dart';
import 'supabase_club_service.dart';
import 'user_state.dart';

class SupabaseContentService {
  // No BuildContext is available this deep in the service layer; these
  // fallback labels are resolved here via the current locale.
  AppLocalizations get _l10n =>
      lookupAppLocalizations(Locale(localeService.languageCode));

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<void> refreshPublicContent() async {
    final client = _client;
    if (client == null) return;

    // Events older than EventCleanupService's 24h-past-end retention window
    // are already permanently deleted, so this cutoff (with margin for
    // long-running events) doesn't hide anything the app doesn't already
    // intend to remove — it just avoids re-downloading it every refresh.
    final eventsCutoff = DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String();
    final results = await Future.wait([
      client.from('clubs').select('*, club_categories(name)'),
      client
          .from('events')
          .select()
          .gte('starts_at', eventsCutoff)
          .order('starts_at', ascending: true)
          .limit(500),
      client
          .from('club_posts')
          .select()
          .order('created_at', ascending: false)
          .limit(500),
    ]);

    final nextClubs = (results[0] as List)
        .map((row) => _clubFromRow(Map<String, dynamic>.from(row as Map)))
        .where((club) => club.id.isNotEmpty)
        .toList();
    await _hydrateBoardMembers(client, nextClubs);
    final nextEvents = (results[1] as List)
        .map((row) => _eventFromRow(Map<String, dynamic>.from(row as Map)))
        .where((event) => event.id.isNotEmpty && event.clubId.isNotEmpty)
        .toList();
    var nextPosts = (results[2] as List)
        .map((row) => _postFromRow(Map<String, dynamic>.from(row as Map)))
        .where((post) => post.id.isNotEmpty && post.clubId.isNotEmpty)
        .toList();
    nextPosts = await _attachPolls(client, nextPosts);

    if (nextClubs.isNotEmpty) {
      clubs
        ..clear()
        ..addAll(nextClubs);
    }
    if (nextEvents.isNotEmpty) {
      events
        ..clear()
        ..addAll(nextEvents);
    }
    if (nextPosts.isNotEmpty) {
      newsPosts
        ..clear()
        ..addAll(nextPosts);
    }
  }

  Future<void> refreshEngagementCounts() async {
    final client = _client;
    if (client == null) return;

    final nextMemberCounts = <String, int>{};
    final nextPostLikeCounts = <String, int>{};
    final nextEventRsvpIds = <String, List<String>>{};

    // The three reads are independent — fire them together instead of one
    // after another. A null result stands in for the branch's old catch
    // fallback, so per-branch degradation is unchanged.
    final eventIds = events.map((e) => e.id).toList();
    final results = await Future.wait<List<dynamic>?>([
      client
          .from('club_member_counts')
          .select('club_id, member_count')
          .then<List<dynamic>?>((rows) => rows)
          .catchError((_) => null),
      client
          .from('post_like_counts')
          .select('post_id, like_count')
          .then<List<dynamic>?>((rows) => rows)
          .catchError((_) => null),
      if (eventIds.isEmpty)
        Future<List<dynamic>?>.value(const [])
      else
        client
            .from('event_rsvps')
            .select('event_id, profile_id')
            .inFilter('event_id', eventIds)
            .then<List<dynamic>?>((rows) => rows)
            .catchError((_) => null),
    ]);

    final memberRows = results[0];
    if (memberRows != null) {
      for (final row in memberRows) {
        final raw = row as Map;
        final clubId = raw['club_id']?.toString() ?? '';
        final count = int.tryParse(raw['member_count']?.toString() ?? '') ?? 0;
        if (clubId.isNotEmpty) nextMemberCounts[clubId] = count;
      }
    } else {
      nextMemberCounts.addAll(supabaseClubMemberCounts);
    }

    for (final clubId in userState.followedClubIds) {
      final current = nextMemberCounts[clubId] ?? 0;
      if (current < 1) nextMemberCounts[clubId] = 1;
    }

    final likeRows = results[1];
    if (likeRows != null) {
      for (final row in likeRows) {
        final raw = row as Map;
        final postId = raw['post_id']?.toString() ?? '';
        final count = int.tryParse(raw['like_count']?.toString() ?? '') ?? 0;
        if (postId.isNotEmpty) nextPostLikeCounts[postId] = count;
      }
    } else {
      nextPostLikeCounts.addAll(supabasePostLikeCounts);
    }

    // null (fetch failed) keeps existing event attendee ids, as before.
    final rsvpRows = results[2];
    if (rsvpRows != null) {
      for (final row in rsvpRows) {
        final raw = row as Map;
        final eventId = raw['event_id']?.toString() ?? '';
        final profileId = raw['profile_id']?.toString() ?? '';
        if (eventId.isEmpty || profileId.isEmpty) continue;
        (nextEventRsvpIds[eventId] ??= []).add(profileId);
      }
    }

    for (final event in events) {
      final attendeeIds = nextEventRsvpIds[event.id];
      if (attendeeIds == null) continue;
      event.attendeeUserIds
        ..clear()
        ..addAll(attendeeIds.toSet());
    }

    supabaseClubMemberCounts
      ..clear()
      ..addAll(nextMemberCounts);
    supabasePostLikeCounts
      ..clear()
      ..addAll(nextPostLikeCounts);
  }

  Club _clubFromRow(Map<String, dynamic> row) {
    final id = _string(row, ['id']);
    final adminIds = _stringList(row['admin_user_ids'] ?? row['adminUserIds']);
    if (adminIds.isEmpty && id.isNotEmpty) adminIds.add(id);
    return Club(
      id: id,
      name: _string(row, ['name', 'title'], fallback: _l10n.clubFallbackName),
      shortName: _nullableString(row, ['short_name', 'shortName']),
      description: _string(row, ['description', 'bio']),
      logoUrl: supabaseClubService.publicLogoUrl(
        _nullableString(row, ['logo_url', 'logoUrl']),
      ),
      categoryId: _nullableString(row, ['category_id', 'categoryId']),
      categoryName: _categoryName(row),
      email: _nullableString(row, ['email']),
      adminUserIds: adminIds,
      boardMemberIds: _stringList(
        row['board_member_ids'] ?? row['boardMemberIds'],
      ),
      boardMemberTitles: _stringMap(
        row['board_member_titles'] ?? row['boardMemberTitles'],
      ),
    );
  }

  Future<void> _hydrateBoardMembers(
    SupabaseClient client,
    List<Club> targetClubs,
  ) async {
    if (targetClubs.isEmpty) return;

    List rows;
    try {
      rows = await client
          .from('club_followers')
          .select('club_id, profile_id, role, role_title')
          .eq('role', 'board_member');
    } catch (_) {
      try {
        rows = await client
            .from('club_followers')
            .select('club_id, profile_id, role')
            .eq('role', 'board_member');
      } catch (_) {
        return;
      }
    }

    final byClub = {for (final club in targetClubs) club.id: club};
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw as Map);
      final club = byClub[row['club_id']?.toString() ?? ''];
      final profileId = row['profile_id']?.toString() ?? '';
      if (club == null || profileId.isEmpty) continue;
      if (!club.boardMemberIds.contains(profileId)) {
        club.boardMemberIds.add(profileId);
      }
      final title = row['role_title']?.toString().trim() ?? '';
      if (title.isNotEmpty) club.boardMemberTitles[profileId] = title;
    }
  }

  String? _categoryName(Map<String, dynamic> row) {
    final direct = _nullableString(row, ['category_name', 'categoryName']);
    if (direct != null) return direct;

    final category = row['club_categories'] ?? row['category'];
    if (category is Map) {
      return _nullableString(Map<String, dynamic>.from(category), ['name']);
    }
    return null;
  }

  Event _eventFromRow(Map<String, dynamic> row) {
    final start = _date(row, ['starts_at', 'date_time', 'dateTime']);
    final end =
        _date(row, ['ends_at', 'end_time', 'endTime']) ??
        start?.add(const Duration(hours: 2));

    return Event(
      id: _string(row, ['id']),
      clubId: _string(row, ['club_id', 'clubId']),
      title: _string(row, ['title', 'name'], fallback: _l10n.eventFallbackTitle),
      description: _string(row, ['description']),
      location: _string(
        row,
        ['location'],
        fallback: _l10n.campusFallbackLocation,
      ),
      dateTime: start ?? DateTime.now(),
      endTime: end ?? DateTime.now().add(const Duration(hours: 2)),
      attendeeUserIds: _stringList(
        row['attendee_user_ids'] ?? row['attendeeUserIds'],
      ),
      rsvpTimestamps: _stringMap(
        row['rsvp_timestamps'] ?? row['rsvpTimestamps'],
      ),
      imagePath: _eventImagePath(row),
      createdByUserId: _nullableString(row, [
        'created_by_user_id',
        'createdByUserId',
        'created_by',
      ]),
      tags: _stringList(row['tags']),
      guestSpeaker: _nullableString(row, ['guest_speaker', 'guestSpeaker']),
      accentColorHex: _nullableString(row, [
        'accent_color_hex',
        'accentColorHex',
      ]),
      registrationUrl: _nullableString(row, [
        'registration_url',
        'registrationUrl',
      ]),
      capacity: row['capacity'] is int
          ? row['capacity'] as int
          : int.tryParse(row['capacity']?.toString() ?? ''),
      schedule: _eventSchedule(row['schedule']),
      speakers: _eventSpeakers(row['speakers']),
    );
  }

  String? _eventImagePath(Map<String, dynamic> row) {
    final imageUrl = _nullableString(row, ['image_url', 'imageUrl']);
    if (imageUrl != null) return imageUrl;

    final imagePath = _nullableString(row, ['image_path', 'imagePath']);
    final client = _client;
    if (client == null || imagePath == null) return imagePath;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    return client.storage.from('event-images').getPublicUrl(imagePath);
  }

  List<EventSlot>? _eventSchedule(dynamic raw) {
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((slot) => EventSlot.fromMap(Map<String, dynamic>.from(slot)))
        .toList();
  }

  List<EventSpeaker> _eventSpeakers(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (speaker) => EventSpeaker.fromMap(Map<String, dynamic>.from(speaker)),
        )
        .toList();
  }

  NewsPost _postFromRow(Map<String, dynamic> row) {
    return NewsPost(
      id: _string(row, ['id']),
      clubId: _string(row, ['club_id', 'clubId']),
      authorId: _string(row, ['author_id', 'authorId'], fallback: ''),
      content: _string(row, ['content', 'body', 'caption']),
      createdAt:
          _date(row, ['created_at', 'createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title: _string(row, ['title']),
      taggedClubIds: _stringList(
        row['tagged_club_ids'] ?? row['taggedClubIds'],
      ),
      taggedUserIds: _stringList(
        row['tagged_user_ids'] ?? row['taggedUserIds'],
      ),
      imagePath: _postImagePath(row),
      isAnnouncement:
          row['is_announcement'] == true || row['isAnnouncement'] == true,
    );
  }

  /// Attaches polls to their posts in one query. Missing polls table (older
  /// Supabase project) degrades gracefully to poll-less posts.
  Future<List<NewsPost>> _attachPolls(
    SupabaseClient client,
    List<NewsPost> posts,
  ) async {
    if (posts.isEmpty) return posts;
    try {
      final rows = await client
          .from('polls')
          .select('id, post_id, question, options')
          .inFilter('post_id', posts.map((p) => p.id).toList());

      final pollsByPostId = <String, PollData>{};
      for (final row in rows) {
        final map = row as Map;
        final postId = map['post_id']?.toString() ?? '';
        final options = map['options'];
        if (postId.isEmpty || options is! List) continue;
        pollsByPostId[postId] = PollData(
          question: map['question']?.toString() ?? '',
          options: options.map((o) => o.toString()).toList(),
          pollId: map['id']?.toString(),
        );
      }
      if (pollsByPostId.isEmpty) return posts;

      // One batched poll_votes query for every poll on the feed, instead of
      // two queries per poll card at render time.
      await _seedPollVotes(client, pollsByPostId);

      return [
        for (final post in posts)
          pollsByPostId.containsKey(post.id)
              ? NewsPost(
                  id: post.id,
                  clubId: post.clubId,
                  authorId: post.authorId,
                  content: post.content,
                  createdAt: post.createdAt,
                  title: post.title,
                  taggedClubIds: post.taggedClubIds,
                  taggedUserIds: post.taggedUserIds,
                  imagePath: post.imagePath,
                  poll: pollsByPostId[post.id],
                  isAnnouncement: post.isAnnouncement,
                )
              : post,
      ];
    } catch (_) {
      return posts;
    }
  }

  /// Batch-fetches every feed poll's votes in one query and seeds them into
  /// [pollStore], so poll cards render without issuing their own per-card
  /// hydrate queries. Degrades independently of poll attachment.
  Future<void> _seedPollVotes(
    SupabaseClient client,
    Map<String, PollData> pollsByPostId,
  ) async {
    try {
      final postIdByPollId = <String, String>{
        for (final entry in pollsByPostId.entries)
          if (entry.value.pollId != null) entry.value.pollId!: entry.key,
      };
      if (postIdByPollId.isEmpty) return;

      final rows = await client
          .from('poll_votes')
          .select('poll_id, profile_id, option_index')
          .inFilter('poll_id', postIdByPollId.keys.toList());

      final votesByPostId = <String, Map<String, int>>{
        for (final postId in pollsByPostId.keys) postId: {},
      };
      for (final row in rows) {
        final map = row as Map;
        final postId = postIdByPollId[map['poll_id']?.toString() ?? ''];
        final profileId = map['profile_id']?.toString() ?? '';
        final optionIndex = map['option_index'];
        if (postId == null || profileId.isEmpty || optionIndex is! int) {
          continue;
        }
        votesByPostId[postId]![profileId] = optionIndex;
      }
      pollStore.seedRemoteVotes(votesByPostId);
    } catch (_) {
      // Poll cards fall back to their own lazy hydrate.
    }
  }

  String? _postImagePath(Map<String, dynamic> row) {
    final imageUrl = _nullableString(row, ['image_url', 'imageUrl']);
    if (imageUrl != null) return imageUrl;

    final imagePath = _nullableString(row, ['image_path', 'imagePath']);
    final client = _client;
    if (client == null || imagePath == null) return imagePath;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    return client.storage.from('post-images').getPublicUrl(imagePath);
  }

  String _string(
    Map<String, dynamic> row,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  String? _nullableString(Map<String, dynamic> row, List<String> keys) {
    final value = _string(row, keys);
    return value.isEmpty ? null : value;
  }

  DateTime? _date(Map<String, dynamic> row, List<String> keys) {
    final value = _nullableString(row, keys);
    return tryParseEventDateTime(value);
  }

  List<String> _stringList(dynamic raw) {
    if (raw == null) return <String>[];
    if (raw is List) return raw.map((value) => value.toString()).toList();
    return raw
        .toString()
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) return <String, String>{};
    return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
  }
}

final supabaseContentService = SupabaseContentService();
