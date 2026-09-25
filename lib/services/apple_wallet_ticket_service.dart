import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Opens an authenticated, freshly signed pass in Apple's native add sheet.
class AppleWalletTicketService {
  AppleWalletTicketService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  static const _channel = MethodChannel('ku_app/apple_wallet_ticket');

  bool get supportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<bool> canAddPasses() async {
    if (!supportedPlatform) return false;
    return await _channel.invokeMethod<bool>('canAddPasses') ?? false;
  }

  Future<void> addTicket(String ticketId) async {
    if (!supportedPlatform) throw StateError('Apple Wallet requires iOS');
    final client = _client ?? Supabase.instance.client;
    final response = await client.functions.invoke(
      'apple-wallet-ticket',
      body: {'ticketId': ticketId},
    );
    final bytes = response.data;
    if (bytes is! Uint8List || bytes.isEmpty) {
      throw StateError('The Apple Wallet pass was empty');
    }
    await _channel.invokeMethod<void>('addPass', bytes);
  }
}

final appleWalletTicketService = AppleWalletTicketService();
