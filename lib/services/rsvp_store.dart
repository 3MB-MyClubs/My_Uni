import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/event.dart';
import 'auth_service.dart';
import 'calendar_sync_service.dart';
import 'club_notification_service.dart';
import 'content_store.dart';
import 'mock_data.dart';
import 'notification_service.dart';
import 'student_activity_service.dart';
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
  RsvpStore({
    SupabaseInteractionService? interactionService,
    StudentActivityService? activityService,
  }) : _interactionService = interactionService ?? supabaseInteractionService,
       _activityService = activityService ?? studentActivityService;

  final SupabaseInteractionService _interactionService;
  final StudentActivityService _activityService;
  final Map<String, _Entry> _map = {};
  final Map<String, Future<void>> _inFlight = {};

  // debugPrint alone isn't stripped in release/profile builds, so gate it
  // behind kDebugMode to avoid string-building/log I/O on every RSVP tap.
  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  bool isAttending(String eventId) => _map[eventId]?.attending ?? false;

  // Kept for existing widgets, but RSVP no longer has a loading UI.
  bool isPending(String eventId) => _inFlight.containsKey(eventId);

  void seed(String eventId, bool attending) {
    if (eventId.isEmpty || _map.containsKey(eventId) || isPending(eventId)) {
      return;
    }
    _map[eventId] = _Entry(attending: attending);
  }

  void seedAll(List<Event> eventList, String userId) {
    for (final e in eventList) {
      seed(e.id, e.attendeeUserIds.contains(userId));
    }
  }

  void replaceForUser(Iterable<String> eventIds, String userId) {
    final attendingIds = eventIds.toSet();
    for (var i = 0; i < events.length; i++) {
      if (isPending(events[i].id)) continue;
      final event = _mutableEventAt(i);
      events[i] = event;
      final attending = attendingIds.contains(event.id);
      _map[event.id] = _Entry(attending: attending);
      if (attending) {
        if (!event.attendeeUserIds.contains(userId)) {
          event.attendeeUserIds.add(userId);
        }
        _ignore(notificationService.scheduleEventReminders(event));
      } else {
        event.attendeeUserIds.remove(userId);
        _ignore(notificationService.cancelEventReminders(event.id));
      }
    }
    notifyListeners();
  }

  Future<void> toggle(String eventId, String userId, {Event? event}) {
    final existing = _inFlight[eventId];
    if (existing != null) return existing;

    late final Future<void> task;
    task = _toggle(eventId, userId, event: event).whenComplete(() {
      if (identical(_inFlight[eventId], task)) _inFlight.remove(eventId);
      notifyListeners();
    });
    _inFlight[eventId] = task;
    notifyListeners();
    return task;
  }

  Future<void> _toggle(String eventId, String userId, {Event? event}) async {
    if (userId.isEmpty || eventId.isEmpty) return;
    if (!authService.isStudentSession ||
        authService.currentUser?.id != userId) {
      _log(
        'RSVP toggle skipped: current session is not a student '
        'eventId=$eventId userId=$userId',
      );
      return;
    }

    final idx = events.indexWhere((e) => e.id == eventId);
    final sourceEvent = idx == -1 ? event : events[idx];
    if (sourceEvent == null) {
      _log('RSVP toggle skipped: event not found eventId=$eventId');
      return;
    }

    if (!_map.containsKey(eventId)) {
      seed(eventId, sourceEvent.attendeeUserIds.contains(userId));
    }
    final wasAttending = isAttending(eventId);
    final mutableEvent = _copyEvent(sourceEvent);
    if (idx == -1) {
      events.add(mutableEvent);
    } else {
      events[idx] = mutableEvent;
    }
    final previousTimestamp = mutableEvent.rsvpTimestamps[userId];
    final previousRemoteCount = supabaseEventRsvpCounts[eventId];
    _log(
      'RSVP toggle local start: eventId=$eventId userId=$userId '
      'wasAttending=$wasAttending next=${!wasAttending}',
    );

    if (previousRemoteCount != null) {
      supabaseEventRsvpCounts[eventId] = wasAttending
          ? (previousRemoteCount - 1).clamp(0, previousRemoteCount)
          : previousRemoteCount + 1;
    }
    _setLocalRsvp(
      event: mutableEvent,
      userId: userId,
      attending: !wasAttending,
    );
    _activityService.applyLocalRsvpUpdate(
      userId: userId,
      eventId: eventId,
      attending: !wasAttending,
    );
    contentStore.scheduleSave('events');

    if (wasAttending) {
      _ignore(
        calendarSyncService.removeEventFromDeviceCalendar(mutableEvent, userId),
      );
      _ignore(notificationService.cancelEventReminders(mutableEvent.id));
    } else {
      _ignore(
        calendarSyncService.syncEventsToDeviceCalendar([mutableEvent], userId),
      );
      _ignore(notificationService.scheduleEventReminders(mutableEvent));
    }

    try {
      final studentUserId = authService.currentUser?.id;
      if (studentUserId != null && studentUserId.isNotEmpty) {
        _log(
          'RSVP supabase write start: eventId=$eventId '
          'profileId=$studentUserId attending=${!wasAttending}',
        );
        await _interactionService.setEventRsvp(
          profileId: studentUserId,
          eventId: eventId,
          attending: !wasAttending,
        );
        _log(
          'RSVP supabase write success: eventId=$eventId '
          'profileId=$studentUserId attending=${!wasAttending}',
        );
      } else {
        _log(
          'RSVP supabase write skipped: no current student user '
          'eventId=$eventId userId=$userId',
        );
      }
      if (!wasAttending) {
        clubNotificationService.notifyClubAboutEventRsvp(
          event: mutableEvent,
          actorUserId: userId,
        );
      }
    } catch (error, stackTrace) {
      _log(
        'RSVP supabase write failed: eventId=$eventId userId=$userId '
        'error=$error',
      );
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
      if (previousRemoteCount != null) {
        supabaseEventRsvpCounts[eventId] = previousRemoteCount;
      }
      _setLocalRsvp(
        event: mutableEvent,
        userId: userId,
        attending: wasAttending,
        timestamp: previousTimestamp,
      );
      _activityService.applyLocalRsvpUpdate(
        userId: userId,
        eventId: eventId,
        attending: wasAttending,
      );
      if (wasAttending) {
        _ignore(notificationService.scheduleEventReminders(mutableEvent));
      } else {
        _ignore(notificationService.cancelEventReminders(mutableEvent.id));
      }
      contentStore.scheduleSave('events');
      _log(
        'RSVP local rollback complete: eventId=$eventId '
        'restoredAttending=$wasAttending',
      );
    }
  }

  void clear() {
    _map.clear();
    _inFlight.clear();
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

  Event _mutableEventAt(int index) => _copyEvent(events[index]);

  Event _copyEvent(Event event) {
    return Event(
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
  }
}

final rsvpStore = RsvpStore();
