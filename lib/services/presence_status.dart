enum LastSeenPeriod { unknown, justNow, minutes, hours, days }

class RelativeLastSeen {
  const RelativeLastSeen(this.period, [this.value = 0]);

  final LastSeenPeriod period;
  final int value;
}

/// Buckets a timestamp into the minute/hour/day labels used by chat surfaces.
RelativeLastSeen relativeLastSeen(DateTime? lastSeenAt, {DateTime? now}) {
  if (lastSeenAt == null) {
    return const RelativeLastSeen(LastSeenPeriod.unknown);
  }
  final elapsed = (now ?? DateTime.now()).toUtc().difference(
    lastSeenAt.toUtc(),
  );
  if (elapsed.isNegative || elapsed.inMinutes < 1) {
    return const RelativeLastSeen(LastSeenPeriod.justNow);
  }
  if (elapsed.inMinutes < 60) {
    return RelativeLastSeen(LastSeenPeriod.minutes, elapsed.inMinutes);
  }
  if (elapsed.inHours < 24) {
    return RelativeLastSeen(LastSeenPeriod.hours, elapsed.inHours);
  }
  return RelativeLastSeen(LastSeenPeriod.days, elapsed.inDays);
}
