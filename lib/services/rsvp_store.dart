import 'package:flutter/foundation.dart';
import '../models/event.dart';
import 'content_store.dart';
import 'mock_data.dart';

class _Entry {
  bool attending;
  bool pending;
  _Entry({required this.attending, this.pending = false});
}

/// Central RSVP state store.
///
/// Single source of truth for every screen that shows an event.
/// All reads go through [isAttending] / [isPending].
/// All writes go through [toggle] or [seed] / [seedAll].
/// Call [clear] on logout.
class RsvpStore extends ChangeNotifier {
  final Map<String, _Entry> _map = {};

  // ── Read ──────────────────────────────────────────────────────────────────

  bool isAttending(String eventId) => _map[eventId]?.attending ?? false;
  bool isPending(String eventId) => _map[eventId]?.pending ?? false;

  // ── Seed (from any event fetch — does not overwrite in-flight state) ──────

  void seed(String eventId, bool attending) {
    if (_map[eventId]?.pending == true) return;
    _map[eventId] = _Entry(attending: attending);
    // No notifyListeners — seeding happens during initState / build,
    // not as a user action.
  }

  void seedAll(List<Event> eventList, String userId) {
    for (final e in eventList) {
      if (_map[e.id]?.pending == true) continue;
      _map[e.id] = _Entry(attending: e.attendeeUserIds.contains(userId));
    }
  }

  // ── Toggle ────────────────────────────────────────────────────────────────

  /// Optimistically flips attending state then persists to the data model.
  /// No-ops if [userId] is empty or a request is already in flight for this
  /// event (prevents duplicate taps).
  void toggle(String eventId, String userId) {
    if (userId.isEmpty) return;
    if (_map[eventId]?.pending == true) return;

    final wasAttending = _map[eventId]?.attending ?? false;

    // 1. Optimistic update — rebuild all listeners immediately
    _map[eventId] = _Entry(attending: !wasAttending, pending: true);
    notifyListeners();

    // 2. Mutate data model (synchronous, in-memory)
    final idx = events.indexWhere((e) => e.id == eventId);
    if (idx == -1) {
      // Event not found — revert
      _map[eventId] = _Entry(attending: wasAttending);
      notifyListeners();
      return;
    }

    final event = events[idx];
    if (wasAttending) {
      event.attendeeUserIds.remove(userId);
      event.rsvpTimestamps.remove(userId);
    } else {
      if (!event.attendeeUserIds.contains(userId)) {
        event.attendeeUserIds.add(userId);
      }
      event.rsvpTimestamps[userId] = DateTime.now().toIso8601String();
    }

    // 3. Persist asynchronously (fire-and-forget, same as existing pattern)
    contentStore.saveEvents();

    // 4. Clear pending — another notifyListeners so isPending consumers update
    _map[eventId] = _Entry(attending: !wasAttending);
    notifyListeners();
  }

  // ── Clear (logout) ────────────────────────────────────────────────────────

  void clear() {
    _map.clear();
    notifyListeners();
  }
}

final rsvpStore = RsvpStore();
