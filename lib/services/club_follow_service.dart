import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class ClubFollowService {
  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<Set<String>> fetchFollowedClubIds(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return const {};

    final rows = await client
        .from('club_followers')
        .select('club_id')
        .eq('profile_id', userId);

    return rows
        .map((row) => (row as Map)['club_id']?.toString() ?? '')
        .where((clubId) => clubId.isNotEmpty)
        .toSet();
  }

  Future<void> followClub({
    required String userId,
    required String clubId,
  }) async {
    final client = _client;
    if (client == null || userId.isEmpty || clubId.isEmpty) return;

    // Insert-ignoring-duplicate: one round trip instead of check-then-insert,
    // and an existing row (e.g. a board_member role) is left untouched.
    try {
      await client.from('club_followers').insert({
        'profile_id': userId,
        'club_id': clubId,
        'role': 'member',
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') return;
      rethrow;
    }
  }

  Future<void> unfollowClub({
    required String userId,
    required String clubId,
  }) async {
    final client = _client;
    if (client == null || userId.isEmpty || clubId.isEmpty) return;

    await client
        .from('club_followers')
        .delete()
        .eq('profile_id', userId)
        .eq('club_id', clubId);
  }

  Future<void> setFollowedClubIds({
    required String userId,
    required Iterable<String> clubIds,
  }) async {
    final client = _client;
    if (client == null || userId.isEmpty) return;

    await client.from('club_followers').delete().eq('profile_id', userId);
    final rows = clubIds
        .where((clubId) => clubId.isNotEmpty)
        .map(
          (clubId) => {
            'profile_id': userId,
            'club_id': clubId,
            'role': 'member',
          },
        )
        .toList();
    if (rows.isNotEmpty) {
      await client.from('club_followers').insert(rows);
    }
  }
}

final clubFollowService = ClubFollowService();
