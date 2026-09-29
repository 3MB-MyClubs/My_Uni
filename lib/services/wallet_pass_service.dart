import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches the holder's signed .pkpass for Apple Wallet or compatible pass apps.
class WalletPassService {
  WalletPassService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<Uint8List> downloadTicket(String ticketId) async {
    final client = _client ?? Supabase.instance.client;
    final response = await client.functions.invoke(
      'apple-wallet-ticket',
      body: {'ticketId': ticketId},
    );
    final bytes = response.data;
    if (bytes is! Uint8List || bytes.isEmpty) {
      throw StateError('The wallet pass was empty');
    }
    return bytes;
  }
}
