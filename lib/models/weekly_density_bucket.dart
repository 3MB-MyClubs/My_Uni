/// Time segments used by Campus Pulse heatmap cells.
enum TimeBlock {
  morning, // 06:00–12:00
  afternoon, // 12:00–17:00
  evening, // 17:00–22:00
  night, // 22:00–06:00
}

extension TimeBlockExt on TimeBlock {
  String get label {
    switch (this) {
      case TimeBlock.morning:
        return 'Morning';
      case TimeBlock.afternoon:
        return 'Afternoon';
      case TimeBlock.evening:
        return 'Evening';
      case TimeBlock.night:
        return 'Night';
    }
  }

  String get shortLabel {
    switch (this) {
      case TimeBlock.morning:
        return 'Morn';
      case TimeBlock.afternoon:
        return 'Aftn';
      case TimeBlock.evening:
        return 'Evng';
      case TimeBlock.night:
        return 'Night';
    }
  }

  /// Starting hour (inclusive) for this block.
  int get startHour {
    switch (this) {
      case TimeBlock.morning:
        return 6;
      case TimeBlock.afternoon:
        return 12;
      case TimeBlock.evening:
        return 17;
      case TimeBlock.night:
        return 22;
    }
  }
}

/// Returns the [TimeBlock] that contains [hour] (0–23).
TimeBlock timeBlockForHour(int hour) {
  if (hour >= 6 && hour < 12) return TimeBlock.morning;
  if (hour >= 12 && hour < 17) return TimeBlock.afternoon;
  if (hour >= 17 && hour < 22) return TimeBlock.evening;
  return TimeBlock.night;
}

/// A single cell in the 7-day × 4-time-block heatmap.
///
/// **Backend note**: This model is local-only for v1.
/// `locationScore` comes from the device owner's own opted-in contributions,
/// NOT from aggregated cross-user crowd data (no backend exists).
/// When a backend is added, replace [HeatmapRepository.fetchWeekBuckets]
/// with a remote fetch and populate [locationScore] from server aggregates.
class WeeklyDensityBucket {
  /// Day of week: 1 = Monday … 7 = Sunday (ISO 8601).
  final int weekday;

  final TimeBlock timeBlock;

  /// Score derived solely from scheduled events (RSVP counts, live status).
  /// Always available; this is the honest fallback when no location data exists.
  final double eventScore;

  /// Score derived from the device owner's opted-in campus location samples.
  /// 0.0 means no local contribution has been recorded yet.
  ///
  /// NOTE (v1): This is single-device data, not multi-user crowd data.
  final double locationScore;

  /// Final display intensity in [0.0, 4.0] — the value used to colour cells.
  final double intensity;

  /// Number of events scheduled in this cell during the current week.
  final int eventCount;

  /// True if a live event is happening right now in this cell.
  final bool isLiveNow;

  /// Whether any local location contribution was available for this cell.
  final bool hasLocationData;

  /// Human-readable source attribution shown to the user.
  /// e.g. "Based on scheduled events" or "Based on events + your activity"
  final String sourceLabel;

  const WeeklyDensityBucket({
    required this.weekday,
    required this.timeBlock,
    required this.eventScore,
    required this.locationScore,
    required this.intensity,
    required this.eventCount,
    required this.isLiveNow,
    required this.hasLocationData,
    required this.sourceLabel,
  });
}

/// All 28 cells for a week, plus a natural-language summary.
class WeeklyDensityData {
  /// 28 buckets in weekday-major order: all Monday cells first, then Tuesday, etc.
  final List<WeeklyDensityBucket> buckets;

  /// e.g. "Thursday evening looks busiest this week"
  final String summary;

  /// Whether any bucket has location-sourced data.
  final bool hasLocationData;

  const WeeklyDensityData({
    required this.buckets,
    required this.summary,
    required this.hasLocationData,
  });

  WeeklyDensityBucket bucketFor(int weekday, TimeBlock block) =>
      buckets.firstWhere((b) => b.weekday == weekday && b.timeBlock == block);
}
