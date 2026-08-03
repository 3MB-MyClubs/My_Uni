import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Maintains one authenticated, app-wide Supabase Presence connection.
///
/// Club screens project [onlineUserIds] through their own membership set. This
/// keeps presence accurate while a student is anywhere in the foreground app
/// without subscribing that student to every club they have joined.
class AppPresenceService extends ChangeNotifier {
  static const _topic = 'app:presence';
  static const _backgroundGracePeriod = Duration(seconds: 5);
  static const _retryDelay = Duration(seconds: 5);
  static const _lastSeenHeartbeatPeriod = Duration(minutes: 1);

  SupabaseClient? _client;
  RealtimeChannel? _channel;
  Timer? _backgroundTimer;
  Timer? _retryTimer;
  Timer? _lastSeenHeartbeat;
  String? _presenceUserId;
  bool _desiredActive = false;
  bool _foreground = true;
  bool _subscribed = false;
  bool _tracking = false;
  Set<String> _onlineUserIds = const {};
  final Map<String, DateTime> _lastSeenByUserId = {};
  final Set<String> _loadedLastSeenUserIds = {};
  final Set<String> _loadingLastSeenUserIds = {};

  Set<String> get onlineUserIds => Set.unmodifiable(_onlineUserIds);

  bool get isConnected => _subscribed;

  DateTime? lastSeenAtFor(String userId) => _lastSeenByUserId[userId];

  SupabaseClient? get _configuredClient {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      // Widget tests and local previews do not always initialize Supabase.
      return null;
    }
  }

  /// Starts Presence only when Supabase has a valid authenticated session.
  Future<void> startForAuthenticatedSession() async {
    _desiredActive = true;
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    final client = _configuredClient;
    final session = client?.auth.currentSession;
    final authUserId = session?.user.id;
    if (client == null ||
        session == null ||
        authUserId == null ||
        authUserId.isEmpty) {
      await _disconnect(clearUsers: true);
      return;
    }
    if (_presenceUserId == authUserId && _channel != null) return;

    await _disconnect(clearUsers: true);
    if (!_desiredActive) return;

    _client = client;
    _presenceUserId = authUserId;
    // Private Realtime channels authorize at join time. Push the current JWT
    // explicitly so a freshly restored/refreshed session cannot race the
    // Supabase client's auth-state listener.
    try {
      await client.realtime.setAuth(session.accessToken);
    } catch (_) {
      // subscribe() below reports an authorization failure and enters the
      // normal retry path if the socket cannot accept this token yet.
    }
    final channel = client
        .channel(
          _topic,
          opts: RealtimeChannelConfig(
            key: authUserId,
            enabled: true,
            private: true,
          ),
        )
        .onPresenceSync((_) => _syncOnlineUsers())
        .onPresenceJoin((_) => _syncOnlineUsers())
        .onPresenceLeave((_) => _syncOnlineUsers());
    _channel = channel;

    channel.subscribe((status, error) {
      if (!identical(_channel, channel)) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        _subscribed = true;
        _retryTimer?.cancel();
        if (_foreground) unawaited(_track());
        return;
      }
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut ||
          status == RealtimeSubscribeStatus.closed) {
        _subscribed = false;
        _tracking = false;
        _setOnlineUsers(const {});
        _scheduleRetry(channel);
      }
    });
  }

  /// Applies foreground/background policy without repeatedly retracking
  /// Presence. A low-frequency database heartbeat keeps crash-time last-seen
  /// accuracy within roughly one minute.
  void handleLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _backgroundTimer?.cancel();
      if (_desiredActive) unawaited(_track());
      return;
    }

    if (state == AppLifecycleState.detached) {
      _foreground = false;
      _backgroundTimer?.cancel();
      unawaited(_untrack());
      return;
    }

    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }
    _foreground = false;
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer(_backgroundGracePeriod, () {
      if (!_foreground) unawaited(_untrack());
    });
  }

  Future<void> _track() async {
    final channel = _channel;
    final client = _client;
    final userId = _presenceUserId;
    if (!_desiredActive ||
        !_foreground ||
        !_subscribed ||
        _tracking ||
        channel == null ||
        userId == null ||
        client?.auth.currentSession?.user.id != userId) {
      return;
    }

    try {
      final response = await channel.track({
        'user_id': userId,
        'online_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!identical(_channel, channel)) return;
      _tracking = response == ChannelResponse.ok;
      if (_tracking) {
        unawaited(_touchOwnLastSeen());
        _startLastSeenHeartbeat();
      } else {
        _scheduleRetry(channel);
      }
    } catch (_) {
      if (identical(_channel, channel)) {
        _tracking = false;
        _scheduleRetry(channel);
      }
    }
  }

  Future<void> _untrack() async {
    final channel = _channel;
    if (!_tracking || channel == null) return;
    _lastSeenHeartbeat?.cancel();
    await _touchOwnLastSeen();
    _tracking = false;
    try {
      await channel.untrack();
    } catch (_) {
      // A disconnected socket automatically expires its Presence heartbeat.
    }
  }

  void _syncOnlineUsers() {
    final channel = _channel;
    if (channel == null) return;
    final next = <String>{};
    for (final state in channel.presenceState()) {
      final key = state.key.trim();
      if (key.isEmpty) continue;
      // Count only payloads produced by an authenticated client using its own
      // auth id as both the Presence key and payload identity.
      final hasMatchingIdentity = state.presences.any(
        (presence) => presence.payload['user_id']?.toString() == key,
      );
      if (hasMatchingIdentity) next.add(key);
    }
    final wentOffline = _onlineUserIds.difference(next);
    if (wentOffline.isNotEmpty) {
      final now = DateTime.now().toUtc();
      for (final userId in wentOffline) {
        _lastSeenByUserId[userId] = now;
      }
    }
    _setOnlineUsers(next);
  }

  void _startLastSeenHeartbeat() {
    _lastSeenHeartbeat?.cancel();
    _lastSeenHeartbeat = Timer.periodic(_lastSeenHeartbeatPeriod, (_) {
      unawaited(_touchOwnLastSeen());
    });
  }

  Future<void> _touchOwnLastSeen() async {
    final client = _client;
    final userId = _presenceUserId;
    if (client == null || userId == null || userId.isEmpty) return;
    if (client.auth.currentSession?.user.id != userId) return;

    final now = DateTime.now().toUtc();
    _lastSeenByUserId[userId] = now;
    notifyListeners();
    try {
      await client.from('user_presence_status').upsert({
        'user_id': userId,
        'last_seen_at': now.toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {
      // Presence remains usable while offline or before the migration lands.
    }
  }

  /// Loads persisted timestamps for chat peers not currently represented by
  /// an online Presence payload.
  Future<void> hydrateLastSeenForUsers(
    Iterable<String> userIds, {
    bool force = false,
  }) async {
    final client = _configuredClient;
    if (client == null || client.auth.currentSession == null) return;
    final requested = userIds
        .map((id) => id.trim())
        .where(
          (id) =>
              id.isNotEmpty &&
              !_loadingLastSeenUserIds.contains(id) &&
              (force || !_loadedLastSeenUserIds.contains(id)),
        )
        .toSet();
    if (requested.isEmpty) return;
    _loadingLastSeenUserIds.addAll(requested);
    try {
      final rows = await client
          .from('user_presence_status')
          .select('user_id, last_seen_at')
          .inFilter('user_id', requested.toList());
      var changed = false;
      for (final row in rows) {
        final userId = row['user_id']?.toString() ?? '';
        final timestamp = DateTime.tryParse(
          row['last_seen_at']?.toString() ?? '',
        )?.toUtc();
        if (userId.isEmpty || timestamp == null) continue;
        if (_lastSeenByUserId[userId] != timestamp) {
          _lastSeenByUserId[userId] = timestamp;
          changed = true;
        }
      }
      _loadedLastSeenUserIds.addAll(requested);
      if (changed) notifyListeners();
    } catch (_) {
      // Generic last-seen copy remains available offline.
    } finally {
      _loadingLastSeenUserIds.removeAll(requested);
    }
  }

  void _setOnlineUsers(Set<String> value) {
    if (setEquals(_onlineUserIds, value)) return;
    _onlineUserIds = Set.unmodifiable(value);
    notifyListeners();
  }

  void _scheduleRetry(RealtimeChannel failedChannel) {
    if (!_desiredActive || !identical(_channel, failedChannel)) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () async {
      if (!_desiredActive || !identical(_channel, failedChannel)) return;
      await _disconnect(clearUsers: true);
      if (_desiredActive) await startForAuthenticatedSession();
    });
  }

  /// Stops Presence immediately. Used for logout as well as app teardown.
  Future<void> stop() async {
    _desiredActive = false;
    _backgroundTimer?.cancel();
    _retryTimer?.cancel();
    _lastSeenHeartbeat?.cancel();
    await _disconnect(clearUsers: true);
  }

  Future<void> _disconnect({required bool clearUsers}) async {
    _backgroundTimer?.cancel();
    _retryTimer?.cancel();
    _lastSeenHeartbeat?.cancel();
    if (_tracking) await _touchOwnLastSeen();
    final channel = _channel;
    final client = _client;
    _channel = null;
    _client = null;
    _presenceUserId = null;
    _subscribed = false;
    if (_tracking && channel != null) {
      try {
        await channel.untrack();
      } catch (_) {
        // Removing the channel below is sufficient when already disconnected.
      }
    }
    _tracking = false;
    if (channel != null && client != null) {
      try {
        await client.removeChannel(channel);
      } catch (_) {
        // The socket may already have removed a failed channel.
      }
    }
    if (clearUsers) _setOnlineUsers(const {});
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}

final appPresenceService = AppPresenceService();
