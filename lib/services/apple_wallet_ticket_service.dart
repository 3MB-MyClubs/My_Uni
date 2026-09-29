import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'wallet_pass_service.dart';

/// Opens an authenticated, freshly signed pass in Apple's native add sheet.
class AppleWalletTicketService {
  AppleWalletTicketService({SupabaseClient? client})
    : _passes = WalletPassService(client: client);

  final WalletPassService _passes;
  static const _channel = MethodChannel('ku_app/apple_wallet_ticket');

  bool get supportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<bool> canAddPasses() async {
    if (!supportedPlatform) return false;
    return await _channel.invokeMethod<bool>('canAddPasses') ?? false;
  }

  Future<void> addTicket(String ticketId) async {
    if (!supportedPlatform) throw StateError('Apple Wallet requires iOS');
    final bytes = await _passes.downloadTicket(ticketId);
    await _channel.invokeMethod<void>('addPass', bytes);
  }
}

final appleWalletTicketService = AppleWalletTicketService();
