import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/club.dart';
import '../models/event.dart';
import '../models/news_post.dart';
import 'mock_data.dart';
import 'supabase_config.dart';
import 'user_state.dart';

class SupabaseContentService {
  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<void> refreshPublicContent() async {
    final client = _client;
    if (client == null) return;

    final results = await Future.wait([
      client.from('clubs').select('*, club_categories(name)'),
      client.from('events').select().order('starts_at', ascending: true),
      client.from('club_posts').select().order('created_at', ascending: false),
    ]);

    final nextClubs = (results[0] as List)
        .map((row) => _clubFromRow(Map<String, dynamic>.from(row as Map)))
        .where((club) => club.id.isNotEmpty)
        .toList();
    final nextEvents = (results[1] as List)
        .map((row) => _eventFromRow(Map<String, dynamic>.from(row as Map)))
        .where((event) => event.id.isNotEmpty && event.clubId.isNotEmpty)
        .toList();
    final nextPosts = (results[2] as List)
        .map((row) => _postFromRow(Map<String, dynamic>.from(row as Map)))
        .where((post) => post.id.isNotEmpty && post.clubId.isNotEmpty)
        .toList();

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
    final nextEventRsvpCounts = <String, int>{};

    try {
      final rows = await client
          .from('club_member_counts')
          .select('club_id, member_count');
      for (final row in rows) {
        final raw = row as Map;
        final clubId = raw['club_id']?.toString() ?? '';
        final count = int.tryParse(raw['member_count']?.toString() ?? '') ?? 0;
        if (clubId.isNotEmpty) nextMemberCounts[clubId] = count;
      }
    } catch (_) {
      nextMemberCounts.addAll(supabaseClubMemberCounts);
    }

    for (final clubId in userState.followedClubIds) {
      final current = nextMemberCounts[clubId] ?? 0;
      if (current < 1) nextMemberCounts[clubId] = 1;
    }

    try {
      final rows = await client
          .from('post_like_counts')
          .select('post_id, like_count');
      for (final row in rows) {
        final raw = row as Map;
        final postId = raw['post_id']?.toString() ?? '';
        final count = int.tryParse(raw['like_count']?.toString() ?? '') ?? 0;
        if (postId.isNotEmpty) nextPostLikeCounts[postId] = count;
      }
    } catch (_) {
      nextPostLikeCounts.addAll(supabasePostLikeCounts);
    }

    try {
      final rows = await client
          .from('event_rsvp_counts')
          .select('event_id, rsvp_count');
      for (final row in rows) {
        final raw = row as Map;
        final eventId = raw['event_id']?.toString() ?? '';
        final count = int.tryParse(raw['rsvp_count']?.toString() ?? '') ?? 0;
        if (eventId.isNotEmpty) nextEventRsvpCounts[eventId] = count;
      }
    } catch (_) {
      // Keep existing event attendee counts if the view has not been created.
    }

    for (final event in events) {
      final count = nextEventRsvpCounts[event.id];
      if (count == null) continue;
      event.attendeeUserIds
        ..clear()
        ..addAll(List.generate(count, (index) => 'rsvp_count_$index'));
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
      name: _string(row, ['name', 'title'], fallback: 'Club'),
      shortName: _nullableString(row, ['short_name', 'shortName']),
      description: _string(row, ['description', 'bio']),
      logoUrl: _nullableString(row, ['logo_url', 'logoUrl']),
      categoryId: _nullableString(row, ['category_id', 'categoryId']),
      categoryName: _categoryName(row),
      email: _nullableString(row, ['email']),
      adminUserIds: adminIds,
      boardMemberIds: _stringList(
        row['board_member_ids'] ?? row['boardMemberIds'],
      ),
    );
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
      title: _string(row, ['title', 'name'], fallback: 'Event'),
      description: _string(row, ['description']),
      location: _string(row, ['location'], fallback: 'Campus'),
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
    );
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
    return value == null ? null : DateTime.tryParse(value);
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
