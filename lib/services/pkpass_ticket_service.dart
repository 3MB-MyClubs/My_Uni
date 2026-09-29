import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'wallet_pass_service.dart';

/// Opens a signed .pkpass in an Android pass app, or lets the holder save it.
class PkpassTicketService {
  PkpassTicketService({SupabaseClient? client})
    : _passes = WalletPassService(client: client);

  final WalletPassService _passes;
  static const _channel = MethodChannel('ku_app/pkpass_ticket');

  bool get supportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> addTicket(String ticketId) async {
    if (!supportedPlatform) {
      throw StateError('Pass file export requires Android');
    }
    final bytes = await _passes.downloadTicket(ticketId);
    await _channel.invokeMethod<void>('addPass', bytes);
  }
}

final pkpassTicketService = PkpassTicketService();
