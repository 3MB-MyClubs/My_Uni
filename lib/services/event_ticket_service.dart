import 'package:supabase_flutter/supabase_flutter.dart';

import 'guest_session.dart';

/// A bearer credential. Never persist this model in Hive, analytics or logs.
class EventTicket {
  const EventTicket({
    required this.id,
    required this.token,
    this.revokedAt,
    this.usedAt,
  });
  factory EventTicket.fromJson(Map<String, dynamic> row) => EventTicket(
    id: row['id'] as String,
    token: row['token'] as String,
    revokedAt: DateTime.tryParse(row['revoked_at']?.toString() ?? ''),
    usedAt: DateTime.tryParse(row['used_at']?.toString() ?? ''),
  );
  final String id;
  final String token;
  final DateTime? revokedAt;
  final DateTime? usedAt;
  bool get isActive => revokedAt == null && usedAt == null;
  String get qrPayload => '${EventTicketService.qrPrefix}$token';
}

enum TicketScanStatus { checkedIn, alreadyUsed, revoked, wrongEvent, invalid }

class TicketScanResult {
  const TicketScanResult(this.status, {this.profileId});
  factory TicketScanResult.fromJson(Map<String, dynamic> json) =>
      TicketScanResult(switch (json['status']) {
        'checked_in' => TicketScanStatus.checkedIn,
        'already_used' => TicketScanStatus.alreadyUsed,
        'revoked' => TicketScanStatus.revoked,
        'wrong_event' => TicketScanStatus.wrongEvent,
        'invalid' => TicketScanStatus.invalid,
        _ => throw const FormatException('Unknown ticket result'),
      }, profileId: json['profile_id'] as String?);
  final TicketScanStatus status;
  final String? profileId;
}

class TicketPerson {
  const TicketPerson({
    required this.fullName,
    this.avatarUrl,
    this.usedAt,
    this.major,
  });

  final String fullName;
  final String? avatarUrl;
  final DateTime? usedAt;
  final String? major;
}

enum EventTicketState { active, used, revoked }

class EventTicketService {
  EventTicketService({SupabaseClient? client}) : _injectedClient = client;
  final SupabaseClient? _injectedClient;
  static const qrPrefix = 'clubup-ticket:v1:';
  static final _tokenPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _eventPattern = RegExp(r'^[0-9a-fA-F-]{36}$');

  SupabaseClient? get _client {
    if (guestSession.isActive) return null;
    if (_injectedClient != null) return _injectedClient;
    try {
      final client = Supabase.instance.client;
      return client.auth.currentSession == null ? null : client;
    } catch (_) {
      return null;
    }
  }

  bool availableFor(String eventId) =>
      _client != null && _eventPattern.hasMatch(eventId);
  SupabaseClient get _requiredClient =>
      _client ?? (throw StateError('Online sign-in required'));

  static String? tokenFromQr(String payload) {
    if (!payload.startsWith(qrPrefix)) return null;
    final token = payload.substring(qrPrefix.length);
    return _tokenPattern.hasMatch(token) ? token : null;
  }

  Future<bool> canManage(String eventId) async =>
      await _requiredClient.rpc(
        'can_manage_event_tickets',
        params: {'p_event_id': eventId},
      ) ==
      true;

  Future<EventTicket?> fetch(String eventId, String profileId) async {
    final rows = await _requiredClient
        .from('event_tickets')
        .select()
        .eq('event_id', eventId)
        .eq('profile_id', profileId)
        .order('issued_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : EventTicket.fromJson(rows.first);
  }

  Future<Set<String>> fetchIssuedProfileIds(String eventId) async {
    final rows = await _requiredClient
        .from('event_tickets')
        .select('profile_id')
        .eq('event_id', eventId)
        .isFilter('revoked_at', null);
    return rows.map((row) => row['profile_id'] as String).toSet();
  }

  Future<Map<String, EventTicketState>> fetchTicketStates(
    String eventId,
  ) async {
    final rows = await _requiredClient
        .from('event_tickets')
        .select('profile_id, used_at, revoked_at')
        .eq('event_id', eventId)
        .order('issued_at', ascending: false);
    final states = <String, EventTicketState>{};
    for (final row in rows) {
      final profileId = row['profile_id'] as String;
      states.putIfAbsent(
        profileId,
        () => row['revoked_at'] != null
            ? EventTicketState.revoked
            : row['used_at'] != null
            ? EventTicketState.used
            : EventTicketState.active,
      );
    }
    return states;
  }

  Future<EventTicket> issue(
    String eventId,
    String profileId, {
    bool reissue = false,
  }) async {
    final row = await _requiredClient
        .rpc(
          'issue_event_ticket',
          params: {
            'p_event_id': eventId,
            'p_profile_id': profileId,
            'p_reissue': reissue,
          },
        )
        .single();
    return EventTicket.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> revoke(String eventId, String ticketId) async {
    await _requiredClient.rpc(
      'revoke_event_ticket',
      params: {'p_event_id': eventId, 'p_ticket_id': ticketId},
    );
  }

  /// No optimistic result, offline fallback, or automatic retry: a lost response
  /// may have committed. A deliberate rescan safely returns already_used.
  Future<TicketScanResult> scan(String eventId, String payload) async {
    final token = tokenFromQr(payload);
    if (token == null) return const TicketScanResult(TicketScanStatus.invalid);
    final json = await _requiredClient.rpc(
      'scan_event_ticket',
      params: {'p_event_id': eventId, 'p_token': token},
    );
    return TicketScanResult.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Resolve the holder only for a ticket confirmed to belong to this event.
  /// The scan RPC intentionally omits identity for invalid and foreign codes.
  Future<TicketPerson?> personForScan(
    String eventId,
    String payload,
    TicketScanResult result,
  ) async {
    if (result.status == TicketScanStatus.invalid ||
        result.status == TicketScanStatus.wrongEvent) {
      return null;
    }
    final token = tokenFromQr(payload);
    if (token == null) return null;
    final ticket = await _requiredClient
        .from('event_tickets')
        .select('profile_id, used_at')
        .eq('event_id', eventId)
        .eq('token', token)
        .maybeSingle();
    final profileId = result.profileId ?? ticket?['profile_id'] as String?;
    if (profileId == null) return null;
    final profile = await _requiredClient
        .from('profiles')
        .select('full_name, avatar_url, majors(name)')
        .eq('id', profileId)
        .maybeSingle();
    if (profile == null) return null;
    return TicketPerson(
      fullName: (profile['full_name'] as String? ?? '').trim(),
      avatarUrl: profile['avatar_url'] as String?,
      usedAt: DateTime.tryParse(ticket?['used_at']?.toString() ?? ''),
      major: (profile['majors'] as Map?)?['name'] as String?,
    );
  }
}

final eventTicketService = EventTicketService();
