import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/weekly_density_bucket.dart';
import 'heatmap_repository.dart';
import 'location_contribution_service.dart';
import 'mock_data.dart';

/// Central service for the Campus Pulse feature.
///
/// Responsibilities:
///  • Persist user opt-in / consent preferences (per userId, via Hive).
///  • Compute weekly density buckets from:
///      1. Scheduled events (always available — honest fallback).
///      2. Local device contributions (only when opted in + permission granted).
///  • Drive [LocationContributionService] on/off based on opt-in state.
///
/// BACKEND NOTE:
/// Cross-user live crowd data requires a shared backend.
/// This implementation is fully local for v1.  To add backend support:
///   1. Implement RemoteHeatmapRepository (see heatmap_repository.dart).
///   2. Inject it here instead of [localHeatmapRepository].
///   3. Call a remote fetch inside [computeWeeklyDensity].
class CampusPulseService extends ChangeNotifier {
  static const _prefBox = 'campus_pulse_prefs';

  Box<dynamic>? _box;
  final HeatmapRepository _repo;
  late final LocationContributionService _locationService;

  bool _optedIn = false;
  bool get optedIn => _optedIn;

  CampusPulseService(this._repo) {
    _locationService = LocationContributionService(_repo);
  }

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_prefBox);
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  String _optKey(String userId) => 'opted_in_$userId';

  void load(String userId) {
    _optedIn =
        (_box?.get(_optKey(userId), defaultValue: false) as bool?) ?? false;
    _locationService.isActive = _optedIn;
    notifyListeners();
  }

  Future<void> save(String userId) async =>
      _box?.put(_optKey(userId), _optedIn);

  Future<void> setOptIn(String userId, bool value) async {
    _optedIn = value;
    _locationService.isActive = value;
    await save(userId);
    notifyListeners();
  }

  Future<void> clearContributions() async {
    await _repo.clearContributions();
    notifyListeners();
  }

  // ── Location sampling ─────────────────────────────────────────────────────

  /// Call whenever the app enters foreground and the user is on a relevant
  /// screen.  Internally throttled — safe to call frequently.
  Future<void> maybeSample() => _locationService.maybeSample();

  // ── Density computation ───────────────────────────────────────────────────

  /// Computes the full 7 × 4 weekly density data.
  ///
  /// Scoring algorithm:
  ///  Event score (per cell):
  ///    +1.0  per scheduled event starting in that (weekday, timeBlock)
  ///    +0.15 per attendee on the event
  ///    +0.50 bonus if the event is happening live right now
  ///
  ///  Location score (per cell, local only):
  ///    localHits / 10 → clamped to [0, 1]
  ///
  ///  Final intensity = blended(eventNorm, locationNorm) * 4
  ///    blended = 0.7 × eventNorm + 0.3 × locationNorm  (when location > 0)
  ///    blended = eventNorm                               (fallback, no location)
  WeeklyDensityData computeWeeklyDensity() {
    final now = DateTime.now();

    // Current-week Monday midnight
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    // ── Step 1: raw event scores per cell ─────────────────────────────────
    final rawEvent = <String, double>{};
    final cellEventCount = <String, int>{};
    final cellIsLive = <String, bool>{};

    for (final event in events) {
      final dt = event.dateTime;
      if (dt.isBefore(weekStart) || dt.isAfter(weekEnd)) continue;

      final key = _cellKey(dt.weekday, timeBlockForHour(dt.hour));
      final isLive = !dt.isAfter(now) && event.endTime.isAfter(now);

      rawEvent[key] =
          (rawEvent[key] ?? 0) +
          1.0 +
          event.attendeeUserIds.length * 0.15 +
          (isLive ? 0.5 : 0);
      cellEventCount[key] = (cellEventCount[key] ?? 0) + 1;
      if (isLive) cellIsLive[key] = true;
    }

    // Normalise event scores to [0, 1]
    final maxEvent = rawEvent.values.fold(0.0, max);

    // ── Step 2: build 28 buckets ───────────────────────────────────────────
    final buckets = <WeeklyDensityBucket>[];
    bool anyLocation = false;

    for (int wd = 1; wd <= 7; wd++) {
      for (final block in TimeBlock.values) {
        final key = _cellKey(wd, block);

        final eventNorm = maxEvent > 0 ? (rawEvent[key] ?? 0) / maxEvent : 0.0;
        final locHits = _repo.getContribution(wd, block);
        final locationNorm = (locHits / 10.0).clamp(0.0, 1.0);
        final hasLoc = locHits > 0;
        if (hasLoc) anyLocation = true;

        final blended = hasLoc
            ? 0.7 * eventNorm + 0.3 * locationNorm
            : eventNorm;
        final intensity = (blended * 4).clamp(0.0, 4.0);

        final evCount = cellEventCount[key] ?? 0;
        final isLive = cellIsLive[key] ?? false;

        buckets.add(
          WeeklyDensityBucket(
            weekday: wd,
            timeBlock: block,
            eventScore: eventNorm,
            locationScore: locationNorm,
            intensity: intensity,
            eventCount: evCount,
            isLiveNow: isLive,
            hasLocationData: hasLoc,
            sourceLabel: hasLoc
                ? 'Based on events + your activity'
                : 'Based on scheduled events',
          ),
        );
      }
    }

    // ── Step 3: natural-language summary ──────────────────────────────────
    final summary = _buildSummary(buckets, now);

    return WeeklyDensityData(
      buckets: buckets,
      summary: summary,
      hasLocationData: anyLocation,
    );
  }

  // ── Summary helpers ───────────────────────────────────────────────────────

  String _buildSummary(List<WeeklyDensityBucket> buckets, DateTime now) {
    if (buckets.every((b) => b.intensity < 0.5)) {
      return 'A quiet week on campus — a great time to get things done.';
    }

    // Find peak cell
    final peak = buckets.reduce((a, b) => a.intensity >= b.intensity ? a : b);

    // Check for live event right now
    final liveBlock = buckets.firstWhere(
      (b) => b.isLiveNow,
      orElse: () => buckets.first,
    );
    if (liveBlock.isLiveNow) {
      return 'Something\'s live on campus right now — check the events strip above.';
    }

    final dayName = _dayName(peak.weekday);
    final blockName = peak.timeBlock.label.toLowerCase();

    // Check if peak is very near now
    final peakDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - peak.weekday));
    final daysAway = peakDate
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    if (daysAway == 0 && peak.timeBlock == timeBlockForHour(now.hour)) {
      return 'Right now looks like the busiest moment this week.';
    }

    if (peak.intensity >= 3.0) {
      return '$dayName $blockName looks busiest this week.';
    }
    return 'Campus is most active around $dayName $blockName.';
  }

  static String _dayName(int weekday) {
    const names = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday];
  }

  static String _cellKey(int wd, TimeBlock block) => '${wd}_${block.index}';
}

final campusPulseService = CampusPulseService(localHeatmapRepository);
