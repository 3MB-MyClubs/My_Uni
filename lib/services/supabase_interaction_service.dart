import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/comment.dart';
import '../models/user.dart';
import 'people_service.dart';
import 'supabase_config.dart';

class SupabaseInteractionService {
  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<Set<String>> fetchLikedPostIds(String profileId) async {
    final client = _client;
    if (client == null || profileId.isEmpty) return const {};

    final rows = await client
        .from('post_likes')
        .select('post_id')
        .eq('profile_id', profileId);

    return rows
        .map((row) => (row as Map)['post_id']?.toString() ?? '')
        .where((postId) => postId.isNotEmpty)
        .toSet();
  }

  Future<void> setPostLiked({
    required String profileId,
    required String postId,
    required bool liked,
  }) async {
    final client = _client;
    if (client == null || profileId.isEmpty || postId.isEmpty) return;

    if (liked) {
      await _insertIgnoringDuplicate(client, 'post_likes', {
        'profile_id': profileId,
        'post_id': postId,
      });
    } else {
      await client
          .from('post_likes')
          .delete()
          .eq('profile_id', profileId)
          .eq('post_id', postId);
    }
  }

  Future<List<User>> fetchPostLikers(String postId) async {
    final client = _client;
    if (client == null || postId.isEmpty) return const [];

    final rows = await client
        .from('post_likes')
        .select(
          'profiles(id, email, full_name, role, avatar_url, bio, major_id, academic_year_id)',
        )
        .eq('post_id', postId);

    final users = <User>[];
    for (final row in rows) {
      final profile = (row as Map)['profiles'];
      if (profile is! Map) continue;
      users.add(await peopleService.userFromProfileMap(profile));
    }
    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  Future<List<User>> fetchPostViewers(String postId) async {
    final client = _client;
    if (client == null || postId.isEmpty) return const [];

    final rows = await client
        .from('post_views')
        .select(
          'profiles(id, email, full_name, role, avatar_url, bio, major_id, academic_year_id)',
        )
        .eq('post_id', postId);

    final users = <User>[];
    for (final row in rows) {
      final profile = (row as Map)['profiles'];
      if (profile is! Map) continue;
      users.add(await peopleService.userFromProfileMap(profile));
    }
    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  Future<Set<String>> fetchRsvpEventIds(String profileId) async {
    final client = _client;
    if (client == null || profileId.isEmpty) return const {};

    final rows = await client
        .from('event_rsvps')
        .select('event_id')
        .eq('profile_id', profileId);

    return rows
        .map((row) => (row as Map)['event_id']?.toString() ?? '')
        .where((eventId) => eventId.isNotEmpty)
        .toSet();
  }

  Future<List<User>> fetchEventAttendees(String eventId) async {
    final client = _client;
    if (client == null || eventId.isEmpty) return const [];

    final rows = await client
        .from('event_rsvps')
        .select(
          'profiles(id, email, full_name, role, avatar_url, bio, major_id, academic_year_id)',
        )
        .eq('event_id', eventId);

    final users = <User>[];
    for (final row in rows) {
      final profile = (row as Map)['profiles'];
      if (profile is! Map) continue;
      users.add(await peopleService.userFromProfileMap(profile));
    }
    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  Future<void> setEventRsvp({
    required String profileId,
    required String eventId,
    required bool attending,
  }) async {
    final client = _client;
    if (client == null || profileId.isEmpty || eventId.isEmpty) return;

    if (attending) {
      await _insertIgnoringDuplicate(client, 'event_rsvps', {
        'profile_id': profileId,
        'event_id': eventId,
      });
    } else {
      await client
          .from('event_rsvps')
          .delete()
          .eq('profile_id', profileId)
          .eq('event_id', eventId);
    }
  }

  // ── Event check-ins ─────────────────────────────────────────────────────────

  /// Profile ids already checked in to [eventId].
  Future<Set<String>> fetchEventCheckinIds(String eventId) async {
    final client = _client;
    if (client == null || eventId.isEmpty) return const {};

    final rows = await client
        .from('event_checkins')
        .select('profile_id')
        .eq('event_id', eventId);

    return rows
        .map((row) => (row as Map)['profile_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  /// Check-in counts for many events in one query (insights).
  Future<Map<String, int>> fetchCheckinCounts(List<String> eventIds) async {
    final client = _client;
    if (client == null || eventIds.isEmpty) return const {};

    final rows = await client
        .from('event_checkins')
        .select('event_id')
        .inFilter('event_id', eventIds);

    final counts = <String, int>{};
    for (final row in rows) {
      final eventId = (row as Map)['event_id']?.toString() ?? '';
      if (eventId.isEmpty) continue;
      counts[eventId] = (counts[eventId] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> setEventCheckin({
    required String eventId,
    required String profileId,
    required bool checkedIn,
    String? checkedInBy,
    String method = 'manual',
  }) async {
    final client = _client;
    if (client == null || eventId.isEmpty || profileId.isEmpty) return;

    if (checkedIn) {
      await _insertIgnoringDuplicate(client, 'event_checkins', {
        'event_id': eventId,
        'profile_id': profileId,
        'checked_in_by': checkedInBy,
        'method': method,
      });
    } else {
      await client
          .from('event_checkins')
          .delete()
          .eq('event_id', eventId)
          .eq('profile_id', profileId);
    }
  }

  // ── Polls ───────────────────────────────────────────────────────────────────

  Future<String?> _pollIdForPost(SupabaseClient client, String postId) async {
    final row = await client
        .from('polls')
        .select('id')
        .eq('post_id', postId)
        .maybeSingle();
    return row?['id']?.toString();
  }

  /// Remote votes for the poll attached to [postId]: profileId → optionIndex.
  Future<Map<String, int>> fetchPollVotes(String postId) async {
    final client = _client;
    if (client == null || postId.isEmpty) return const {};

    final pollId = await _pollIdForPost(client, postId);
    if (pollId == null) return const {};

    final rows = await client
        .from('poll_votes')
        .select('profile_id, option_index')
        .eq('poll_id', pollId);

    final votes = <String, int>{};
    for (final row in rows) {
      final map = row as Map;
      final profileId = map['profile_id']?.toString() ?? '';
      final optionIndex = map['option_index'];
      if (profileId.isEmpty || optionIndex is! int) continue;
      votes[profileId] = optionIndex;
    }
    return votes;
  }

  /// Records (or changes) a vote on the poll attached to [postId].
  Future<void> upsertPollVote({
    required String postId,
    required String profileId,
    required int optionIndex,
  }) async {
    final client = _client;
    if (client == null || postId.isEmpty || profileId.isEmpty) return;

    final pollId = await _pollIdForPost(client, postId);
    if (pollId == null) return;

    await client.from('poll_votes').upsert({
      'poll_id': pollId,
      'profile_id': profileId,
      'option_index': optionIndex,
    }, onConflict: 'poll_id,profile_id');
  }

  // ── Comments ────────────────────────────────────────────────────────────────

  Comment _commentFromRow(Map row) => Comment(
    id: row['id']?.toString() ?? '',
    postId: row['post_id']?.toString() ?? '',
    userId: row['profile_id']?.toString() ?? '',
    content: row['content']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now(),
    parentCommentId: row['parent_comment_id']?.toString(),
  );

  /// Fetches comments for [postId], oldest first. Commenter profiles are
  /// hydrated into the people cache so names/avatars resolve in the UI.
  Future<List<Comment>> fetchComments(String postId) async {
    final client = _client;
    if (client == null || postId.isEmpty) return const [];

    final rows = await client
        .from('post_comments')
        .select(
          'id, post_id, profile_id, content, parent_comment_id, created_at, '
          'profiles(id, email, full_name, role, avatar_url, bio, major_id, academic_year_id)',
        )
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    final result = <Comment>[];
    for (final row in rows) {
      final map = row as Map;
      final profile = map['profiles'];
      if (profile is Map) {
        await peopleService.userFromProfileMap(profile);
      }
      result.add(_commentFromRow(map));
    }
    return result;
  }

  /// Comment counts for many posts in one query (feed badges).
  Future<Map<String, int>> fetchCommentCounts(List<String> postIds) async {
    final client = _client;
    if (client == null || postIds.isEmpty) return const {};

    final rows = await client
        .from('post_comments')
        .select('post_id')
        .inFilter('post_id', postIds);

    final counts = <String, int>{};
    for (final row in rows) {
      final postId = (row as Map)['post_id']?.toString() ?? '';
      if (postId.isEmpty) continue;
      counts[postId] = (counts[postId] ?? 0) + 1;
    }
    return counts;
  }

  /// Inserts a comment and returns the created row, or null when Supabase is
  /// unavailable (caller keeps its local copy).
  Future<Comment?> addComment({
    required String postId,
    required String profileId,
    required String content,
  }) async {
    final client = _client;
    if (client == null ||
        postId.isEmpty ||
        profileId.isEmpty ||
        content.isEmpty) {
      return null;
    }

    final row = await client
        .from('post_comments')
        .insert({
          'post_id': postId,
          'profile_id': profileId,
          'content': content,
        })
        .select('id, post_id, profile_id, content, parent_comment_id, created_at')
        .single();
    return _commentFromRow(row);
  }

  Future<void> deleteComment(String commentId) async {
    final client = _client;
    if (client == null || commentId.isEmpty) return;
    await client.from('post_comments').delete().eq('id', commentId);
  }

  Future<void> _insertIgnoringDuplicate(
    SupabaseClient client,
    String table,
    Map<String, dynamic> values,
  ) async {
    try {
      await client.from(table).insert(values);
    } on PostgrestException catch (error) {
      if (error.code == '23505') return;
      rethrow;
    }
  }
}

final supabaseInteractionService = SupabaseInteractionService();
