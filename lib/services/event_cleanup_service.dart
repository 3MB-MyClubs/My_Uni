import 'dart:async';

import '../models/event.dart';
import 'content_store.dart';
import 'mock_data.dart';
import 'supabase_event_service.dart';

class EventCleanupService {
  static const Duration retentionAfterEnd = Duration(hours: 24);

  bool _running = false;

  bool isExpired(Event event, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(retentionAfterEnd);
    return event.endTime.isBefore(cutoff);
  }

  Future<void> cleanupExpiredEvents() async {
    if (_running) return;
    _running = true;
    try {
      final expired = events.where(isExpired).toList();
      if (expired.isEmpty) return;

      await Future.wait(
        expired.map((event) async {
          try {
            await supabaseEventService.deleteEvent(event);
          } catch (_) {
            // Keep cleanup best-effort. The event is still hidden locally; a
            // backend scheduled cleanup handles rows this client cannot delete.
          }
        }),
      );

      final expiredIds = expired.map((event) => event.id).toSet();
      events.removeWhere((event) => expiredIds.contains(event.id));
      await contentStore.saveEvents();
    } finally {
      _running = false;
    }
  }
}

final eventCleanupService = EventCleanupService();
