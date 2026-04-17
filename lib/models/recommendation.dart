enum RecType { happeningNow, bestThisWeek, suggestFollow }

enum RecTargetType { event, club, person }

/// A single personalised recommendation surfaced in the "Your KU Day" section.
class Recommendation {
  final RecType type;
  final RecTargetType targetType;

  /// The ID of the underlying object (event/club/user id).
  final String id;

  /// Primary display title.
  final String title;

  /// Supporting line — club name + time-label for events, member count for
  /// clubs, shared clubs for people.
  final String subtitle;

  /// One-line explanation of why this appeared ("Because you follow KÜMK").
  final String reason;

  /// The actual Event / Club / User object.
  final dynamic data;

  const Recommendation({
    required this.type,
    required this.targetType,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.reason,
    required this.data,
  });
}
