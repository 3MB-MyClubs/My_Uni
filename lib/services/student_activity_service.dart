import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/event.dart';
import 'checkin_store.dart';
import 'mock_data.dart';

/// Where an event sits relative to "now" for a given student.
enum StudentActivityPhase { upcoming, live, past }

/// Which slice of a student's event history a list is showing.
enum StudentActivityFilter { all, upcoming, past }

/// The per-club accent used by the activity rows. Mirrors the palette the
/// profile and club screens already use so a club keeps one color app-wide.
const List<Color> studentActivityClubColors = [
  Color(0xFFC62828),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFFE65100),
  Color(0xFF00838F),
];

/// One event on a student's record, resolved against its club and the
/// student's RSVP / check-in state.
class StudentActivityEntry {
  final Event event;
  final Club? club;
  final Color color;
  final StudentActivityPhase phase;

  /// The student holds an RSVP for this event.
  final bool rsvped;

  /// Door check-in recorded — the only thing that *confirms* attendance.
  final bool checkedIn;

  const StudentActivityEntry({
    required this.event,
    required this.club,
    required this.color,
    required this.phase,
    required this.rsvped,
    required this.checkedIn,
  });

  String get eventId => event.id;
  DateTime get start => event.dateTime;
  DateTime get end => event.endTime;
  bool get isUpcoming => phase != StudentActivityPhase.past;
  bool get isPast => phase == StudentActivityPhase.past;
  bool get isLive => phase == StudentActivityPhase.live;

  /// A past RSVP with no scan against it — shown as unconfirmed rather than
  /// silently counted as attendance.
  bool get isUnconfirmed => isPast && !checkedIn;
}

/// A student's whole event record, split into what's ahead and what's done.
class StudentActivitySummary {
  /// Soonest first — live events sort ahead of everything else.
  final List<StudentActivityEntry> upcoming;

  /// Newest first.
  final List<StudentActivityEntry> past;

  const StudentActivitySummary({required this.upcoming, required this.past});

  static const empty = StudentActivitySummary(upcoming: [], past: []);

  List<StudentActivityEntry> get all => [...upcoming, ...past];

  List<StudentActivityEntry> forFilter(StudentActivityFilter filter) =>
      switch (filter) {
        StudentActivityFilter.all => all,
        StudentActivityFilter.upcoming => upcoming,
        StudentActivityFilter.past => past,
      };

  int get total => upcoming.length + past.length;
  bool get isEmpty => total == 0;
  bool get isNotEmpty => total > 0;

  /// Past events with a confirmed check-in.
  int get attendedCount => past.where((entry) => entry.checkedIn).length;

  /// Distinct clubs the student has taken part in, across both halves.
  int get clubCount =>
      all.map((entry) => entry.event.clubId).toSet().where((id) => id.isNotEmpty).length;

  /// Entries inside the academic year containing [reference], newest first.
  List<StudentActivityEntry> forAcademicYear(DateTime reference) {
    final label = academicYearLabel(reference);
    return all
        .where((entry) => academicYearLabel(entry.start) == label)
        .toList();
  }
}

/// Campus academic years run September → August, so a "year" label spans two
/// calendar years (e.g. `2025–26`).
String academicYearLabel(DateTime date) {
  final startYear = date.month >= 9 ? date.year : date.year - 1;
  final endShort = ((startYear + 1) % 100).toString().padLeft(2, '0');
  return '$startYear–$endShort';
}

/// Builds a student's event record from the loaded events, their RSVPs and the
/// check-in store. Pure read — safe to call from `build`.
class StudentActivityService {
  const StudentActivityService();

  Color colorForClubId(String clubId) {
    final ordinal = clubOrdinal(clubId);
    final index = ordinal < 0 ? 0 : ordinal;
    return studentActivityClubColors[index % studentActivityClubColors.length];
  }

  /// The event's own accent when its creator picked one, else the club color.
  Color colorForEvent(Event event) {
    final hex = event.accentColorHex;
    if (hex != null && hex.trim().length == 8) {
      final value = int.tryParse(hex.trim(), radix: 16);
      if (value != null) return Color(value);
    }
    return colorForClubId(event.clubId);
  }

  StudentActivitySummary summaryFor(String userId, {DateTime? now}) {
    if (userId.isEmpty) return StudentActivitySummary.empty;

    final moment = now ?? DateTime.now();
    final clubsById = {for (final club in clubs) club.id: club};

    final upcoming = <StudentActivityEntry>[];
    final past = <StudentActivityEntry>[];

    for (final event in events) {
      final rsvped = event.attendeeUserIds.contains(userId);
      final checkedIn = checkinStore.isCheckedIn(event.id, userId);
      // A door scan counts even without an RSVP — walk-ins are still
      // attendance, and they are the only record some events have.
      if (!rsvped && !checkedIn) continue;

      final phase = event.endTime.isBefore(moment)
          ? StudentActivityPhase.past
          : event.dateTime.isAfter(moment)
          ? StudentActivityPhase.upcoming
          : StudentActivityPhase.live;

      final entry = StudentActivityEntry(
        event: event,
        club: clubsById[event.clubId],
        color: colorForEvent(event),
        phase: phase,
        rsvped: rsvped,
        checkedIn: checkedIn,
      );

      if (phase == StudentActivityPhase.past) {
        past.add(entry);
      } else {
        upcoming.add(entry);
      }
    }

    upcoming.sort((a, b) {
      // Anything happening right now belongs at the very top.
      if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
      return a.start.compareTo(b.start);
    });
    past.sort((a, b) => b.start.compareTo(a.start));

    return StudentActivitySummary(upcoming: upcoming, past: past);
  }

  /// Pulls remote check-ins for the events already on a student's record so
  /// "Attended" reflects scans made on another device. Bounded so a long
  /// history can't fan out into an unbounded query burst.
  Future<void> hydrateAttendance(
    List<StudentActivityEntry> entries, {
    int limit = 30,
  }) async {
    final ids = entries
        .where((entry) => entry.isPast)
        .map((entry) => entry.eventId)
        .take(limit)
        .toList();
    if (ids.isEmpty) return;
    await Future.wait(ids.map((id) => checkinStore.hydrate(id)));
  }
}

const studentActivityService = StudentActivityService();
