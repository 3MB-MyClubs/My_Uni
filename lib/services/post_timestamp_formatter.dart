import '../l10n/app_localizations.dart';

/// Formats the compact relative timestamp shown on post cards.
String formatPostTimestamp(
  AppLocalizations l10n,
  DateTime postedAt, {
  DateTime? now,
}) {
  final difference = (now ?? DateTime.now()).difference(postedAt);

  if (difference.inMinutes < 60) {
    return l10n.minutesAgoSuffix(difference.inMinutes);
  }
  if (difference.inHours < 24) {
    return l10n.hoursAgoSuffix(difference.inHours);
  }
  if (difference.inDays < 7) {
    return l10n.daysAgoSuffix(difference.inDays);
  }
  if (difference.inDays < 30) {
    return l10n.weeksAgo(difference.inDays ~/ 7);
  }
  return l10n.monthsAgoSuffix(difference.inDays ~/ 30);
}
