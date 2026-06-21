import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/event.dart';
import 'auth_service.dart';
import 'calendar_sync_service.dart';
import 'content_store.dart';
import 'mock_data.dart';
import 'supabase_interaction_service.dart';

class _Entry {
  bool attending;
  _Entry({required this.attending});
}

/// Central RSVP state store.
///
/// Mirrors post-like behavior: optimistic local update first, Supabase write in
/// the background, and local rollback if the Supabase write fails.
class RsvpStore extends ChangeNotifier {
  final Map<String, _Entry> _map = {};

  bool isAttending(String eventId) => _map[eventId]?.attending ?? false;

  // Kept for existing widgets, but RSVP no longer has a loading UI.
  bool isPending(String eventId) => false;

  void seed(String eventId, bool attending) {
    _map[eventId] = _Entry(attending: attending);
  }

  void seedAll(List<Event> eventList, String userId) {
    for (final e in eventList) {
      _map[e.id] = _Entry(attending: e.attendeeUserIds.contains(userId));
    }
  }

  void replaceForUser(Iterable<String> eventIds, String userId) {
    final attendingIds = eventIds.toSet();
    for (var i = 0; i < events.length; i++) {
      final event = _mutableEventAt(i);
      final attending = attendingIds.contains(event.id);
      _map[event.id] = _Entry(attending: attending);
      if (attending) {
        if (!event.attendeeUserIds.contains(userId)) {
          event.attendeeUserIds.add(userId);
        }
      } else {
        event.attendeeUserIds.remove(userId);
      }
    }
    notifyListeners();
  }

  Future<void> toggle(String eventId, String userId) async {
    if (userId.isEmpty || eventId.isEmpty) return;

    final wasAttending = isAttending(eventId);
    final idx = events.indexWhere((e) => e.id == eventId);
    if (idx == -1) {
      debugPrint('RSVP toggle skipped: event not found eventId=$eventId');
      return;
    }

    final event = _mutableEventAt(idx);
    final previousTimestamp = event.rsvpTimestamps[userId];
    debugPrint(
      'RSVP toggle local start: eventId=$eventId userId=$userId '
      'wasAttending=$wasAttending next=${!wasAttending}',
    );

    _setLocalRsvp(event: event, userId: userId, attending: !wasAttending);
    unawaited(contentStore.saveEvents());

    if (wasAttending) {
      _ignore(calendarSyncService.removeEventFromDeviceCalendar(event, userId));
    } else {
      _ignore(calendarSyncService.syncEventsToDeviceCalendar([event], userId));
    }

    try {
      final studentUserId = authService.currentUser?.id;
      if (studentUserId != null && studentUserId.isNotEmpty) {
        debugPrint(
          'RSVP supabase write start: eventId=$eventId '
          'profileId=$studentUserId attending=${!wasAttending}',
        );
        await supabaseInteractionService.setEventRsvp(
          profileId: studentUserId,
          eventId: eventId,
          attending: !wasAttending,
        );
        debugPrint(
          'RSVP supabase write success: eventId=$eventId '
          'profileId=$studentUserId attending=${!wasAttending}',
        );
      } else {
        debugPrint(
          'RSVP supabase write skipped: no current student user '
          'eventId=$eventId userId=$userId',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'RSVP supabase write failed: eventId=$eventId userId=$userId '
        'error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _setLocalRsvp(
        event: event,
        userId: userId,
        attending: wasAttending,
        timestamp: previousTimestamp,
      );
      unawaited(contentStore.saveEvents());
      debugPrint(
        'RSVP local rollback complete: eventId=$eventId '
        'restoredAttending=$wasAttending',
      );
    }
  }

  void clear() {
    _map.clear();
    notifyListeners();
  }

  void _setLocalRsvp({
    required Event event,
    required String userId,
    required bool attending,
    String? timestamp,
  }) {
    _map[event.id] = _Entry(attending: attending);
    if (attending) {
      if (!event.attendeeUserIds.contains(userId)) {
        event.attendeeUserIds.add(userId);
      }
      event.rsvpTimestamps[userId] =
          timestamp ?? DateTime.now().toIso8601String();
    } else {
      event.attendeeUserIds.remove(userId);
      event.rsvpTimestamps.remove(userId);
    }
    notifyListeners();
  }

  void _ignore(Future<void> future) {
    unawaited(future.catchError((_) {}));
  }

  Event _mutableEventAt(int index) {
    final event = events[index];
    final mutable = Event(
      id: event.id,
      clubId: event.clubId,
      title: event.title,
      description: event.description,
      dateTime: event.dateTime,
      endTime: event.endTime,
      location: event.location,
      attendeeUserIds: List<String>.from(event.attendeeUserIds),
      rsvpTimestamps: Map<String, String>.from(event.rsvpTimestamps),
      imagePath: event.imagePath,
      createdByUserId: event.createdByUserId,
      tags: List<String>.from(event.tags),
      guestSpeaker: event.guestSpeaker,
      schedule: event.schedule,
      accentColorHex: event.accentColorHex,
      registrationUrl: event.registrationUrl,
      capacity: event.capacity,
      speakers: List<EventSpeaker>.from(event.speakers),
    );
    events[index] = mutable;
    return mutable;
  }
}

final rsvpStore = RsvpStore();
