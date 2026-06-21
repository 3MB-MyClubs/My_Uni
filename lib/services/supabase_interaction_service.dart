import 'package:supabase_flutter/supabase_flutter.dart';

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
