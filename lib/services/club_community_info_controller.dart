import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_presence_service.dart';
import 'mock_data.dart';
import 'supabase_config.dart';
import 'supabase_read_cache.dart';

/// Returns the number of unique authenticated online users who are members of
/// one club. Kept pure so the membership rule is shared and directly testable.
int onlineClubMemberCount({
  required Iterable<String> onlineUserIds,
  required Iterable<String> memberUserIds,
}) {
  final members = memberUserIds.toSet();
  return onlineUserIds.toSet().where(members.contains).length;
}

/// Live information for one opened club community.
///
/// Member totals use the existing aggregate view. A single filtered realtime
/// subscription maintains just this club's member-id set, which is intersected
/// with app-wide Supabase Presence for the online count.
class ClubCommunityInfoController extends ChangeNotifier {
  ClubCommunityInfoController({
    required this.clubId,
    required int fallbackMemberCount,
    AppPresenceService? presenceService,
    Iterable<String> fallbackMemberIds = const [],
  }) : _memberCount = fallbackMemberCount,
       _memberIds = fallbackMemberIds.toSet(),
       _presenceService = presenceService ?? appPresenceService {
    _onlineCount = onlineClubMemberCount(
      onlineUserIds: _presenceService.onlineUserIds,
      memberUserIds: _memberIds,
    );
    _presenceService.addListener(_handlePresenceChanged);
  }

  final String clubId;
  final AppPresenceService _presenceService;
  final Set<String> _memberIds;

  static const _snapshotTtl = Duration(seconds: 30);

  String get _memberCountCacheKey => 'club-community-count:$clubId';
  String get _memberIdsCacheKey => 'club-community-members:$clubId';

  SupabaseClient? _client;
  RealtimeChannel? _membershipChannel;
  Timer? _countRefreshDebounce;
  bool _started = false;
  bool _disposed = false;
  int _memberCount;
  int _onlineCount = 0;

  int get memberCount => _memberCount;
  int get onlineCount => _onlineCount;

  SupabaseClient? get _configuredClient {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> start() async {
    if (_started || _disposed || clubId.isEmpty) return;
    _started = true;
    final client = _configuredClient;
    if (client == null || client.auth.currentSession == null) return;
    _client = client;

    final channel = client
        .channel('club:$clubId:membership')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_followers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'club_id',
            value: clubId,
          ),
          callback: _handleMembershipChange,
        );
    _membershipChannel = channel;
    channel.subscribe((status, error) {
      if (_disposed || !identical(_membershipChannel, channel)) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Reconcile once after the subscription is live so no join/leave can
        // fall into the gap between the initial query and realtime delivery.
        unawaited(_refreshSnapshot(client));
      }
    });

    await _refreshSnapshot(client);
  }

  Future<void> _refreshSnapshot(SupabaseClient client) async {
    await Future.wait([_refreshMemberCount(client), _refreshMemberIds(client)]);
  }

  Future<void> _refreshMemberCount(SupabaseClient client) async {
    final next = await supabaseReadCache.getOrFetch<int?>(
      key: _memberCountCacheKey,
      ttl: _snapshotTtl,
      shouldCache: (value) => value != null,
      fetch: () async {
        try {
          final rows = await client
              .from('club_member_counts')
              .select('member_count')
              .eq('club_id', clubId)
              .limit(1);
          if (rows.isNotEmpty) {
            final count = int.tryParse(
              (rows.first as Map)['member_count']?.toString() ?? '',
            );
            if (count != null) return count;
          }
        } catch (_) {
          // Older environments may not have the aggregate view yet.
        }
        try {
          return await client
              .from('club_followers')
              .count(CountOption.exact)
              .eq('club_id', clubId);
        } catch (_) {
          return null;
        }
      },
    );
    if (next == null) return;
    if (_disposed || next == _memberCount) return;
    _memberCount = next;
    supabaseClubMemberCounts[clubId] = next;
    notifyListeners();
  }

  Future<void> _refreshMemberIds(SupabaseClient client) async {
    try {
      final nextIds = await supabaseReadCache.getOrFetch<Set<String>>(
        key: _memberIdsCacheKey,
        ttl: _snapshotTtl,
        fetch: () async {
          final rows = await client
              .from('club_followers')
              .select('profile_id')
              .eq('club_id', clubId);
          return rows
              .map((row) => (row as Map)['profile_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
        },
      );
      if (_disposed) return;
      _memberIds
        ..clear()
        ..addAll(nextIds);
      _recalculateOnlineCount();
    } catch (_) {
      // Preserve the last complete membership snapshot while offline.
    }
  }

  void _handleMembershipChange(PostgresChangePayload payload) {
    if (_disposed) return;
    final record = payload.eventType == PostgresChangeEvent.delete
        ? payload.oldRecord
        : payload.newRecord;
    final profileId = record['profile_id']?.toString() ?? '';
    if (profileId.isNotEmpty) {
      supabaseReadCache.invalidate(_memberCountCacheKey);
      supabaseReadCache.invalidate(_memberIdsCacheKey);
      if (payload.eventType == PostgresChangeEvent.delete) {
        _memberIds.remove(profileId);
      } else {
        _memberIds.add(profileId);
      }
      _recalculateOnlineCount();
    }

    // Coalesce bursts (for example an admin importing several members) into
    // one aggregate count read rather than one request per changed row.
    _countRefreshDebounce?.cancel();
    _countRefreshDebounce = Timer(const Duration(milliseconds: 150), () {
      final client = _client;
      if (!_disposed && client != null) unawaited(_refreshMemberCount(client));
    });
  }

  void _handlePresenceChanged() => _recalculateOnlineCount();

  void _recalculateOnlineCount() {
    final next = onlineClubMemberCount(
      onlineUserIds: _presenceService.onlineUserIds,
      memberUserIds: _memberIds,
    );
    if (_disposed || next == _onlineCount) return;
    _onlineCount = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _countRefreshDebounce?.cancel();
    _presenceService.removeListener(_handlePresenceChanged);
    final client = _client;
    final channel = _membershipChannel;
    _client = null;
    _membershipChannel = null;
    if (client != null && channel != null) {
      unawaited(client.removeChannel(channel));
    }
    super.dispose();
  }
}
