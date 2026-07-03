import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';
import 'supabase_config.dart';

/// Supabase backing for 1-on-1 DMs (`direct_messages` table + realtime).
///
/// Only conversations between real profiles (UUID ids) touch the network;
/// seed-data conversations stay in Hive via MessageService. Incoming rows are
/// delivered through a realtime channel filtered to the logged-in receiver.
class SupabaseMessageService {
  RealtimeChannel? _channel;

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  static final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool looksLikeUuid(String value) => _uuidRe.hasMatch(value);

  Message _fromRow(Map<String, dynamic> row) => Message(
    id: row['id']?.toString() ?? '',
    senderId: row['sender_id']?.toString() ?? '',
    receiverId: row['receiver_id']?.toString() ?? '',
    content: row['content']?.toString() ?? '',
    sentAt:
        DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
  );

  /// Every message where [myId] is sender or receiver.
  Future<List<Message>> fetchAllForUser(String myId) async {
    final client = _client;
    if (client == null || !looksLikeUuid(myId)) return const [];

    final rows = await client
        .from('direct_messages')
        .select('id, sender_id, receiver_id, content, created_at')
        .or('sender_id.eq.$myId,receiver_id.eq.$myId')
        .order('created_at', ascending: true);

    return [
      for (final row in rows) _fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }

  /// Inserts a message; returns the stored row (server id + timestamp) or
  /// null when Supabase is unavailable / ids aren't real profiles.
  Future<Message?> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    final client = _client;
    if (client == null ||
        !looksLikeUuid(senderId) ||
        !looksLikeUuid(receiverId) ||
        content.isEmpty) {
      return null;
    }

    final row = await client
        .from('direct_messages')
        .insert({
          'sender_id': senderId,
          'receiver_id': receiverId,
          'content': content,
        })
        .select('id, sender_id, receiver_id, content, created_at')
        .single();
    return _fromRow(Map<String, dynamic>.from(row));
  }

  /// Subscribes to incoming messages for [myId]. Re-calling replaces the
  /// previous subscription.
  void startRealtime(String myId, void Function(Message) onMessage) {
    final client = _client;
    if (client == null || !looksLikeUuid(myId)) return;

    stopRealtime();
    _channel = client
        .channel('dm_$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: myId,
          ),
          callback: (payload) {
            try {
              onMessage(_fromRow(payload.newRecord));
            } catch (error) {
              debugPrint('DM realtime payload failed: $error');
            }
          },
        )
        .subscribe();
  }

  void stopRealtime() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        channel.unsubscribe();
      } catch (_) {}
    }
  }
}

final supabaseMessageService = SupabaseMessageService();
