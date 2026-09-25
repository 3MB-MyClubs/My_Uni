import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Requests a holder-only signed ticket and opens Google's native save sheet.
class GoogleWalletTicketService {
  GoogleWalletTicketService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  static const _channel = MethodChannel('ku_app/google_wallet_ticket');

  bool get supportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> canAddPasses() async {
    if (!supportedPlatform) return false;
    return await _channel.invokeMethod<bool>('canAddPasses') ?? false;
  }

  Future<void> addTicket(String ticketId) async {
    if (!supportedPlatform) throw StateError('Google Wallet requires Android');
    final client = _client ?? Supabase.instance.client;
    final response = await client.functions.invoke(
      'google-wallet-ticket',
      body: {'ticketId': ticketId},
    );
    final jwt = (response.data as Map?)?['jwt'];
    if (jwt is! String || jwt.isEmpty) {
      throw StateError('The Google Wallet pass was empty');
    }
    await _channel.invokeMethod<void>('addPass', jwt);
  }
}

final googleWalletTicketService = GoogleWalletTicketService();
