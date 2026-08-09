import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';
import '../services/student_activity_service.dart';
import 'student_campus_profile.dart';

/// Shared building blocks for the "Events & activities" area on a student
/// profile: the row, the badges, the empty state and the profile-embedded
/// preview card. The full-history screen composes the same pieces.

String _monthAbbr(BuildContext context, DateTime date) {
  return DateFormat.MMM(
    Localizations.localeOf(context).languageCode,
  ).format(date).toUpperCase();
}

String _timeLabel(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: true);
}

/// `Mon · 18:30 · Sevgi Gönül Hall` — the supporting line under a row title.
String activityMetaLine(BuildContext context, StudentActivityEntry entry) {
  final language = Localizations.localeOf(context).languageCode;
  final parts = <String>[
    if (entry.club != null && entry.club!.name.trim().isNotEmpty)
      entry.club!.name.trim(),
    DateFormat.E(language).format(entry.start),
    _timeLabel(context, entry.start),
    if (entry.event.location.trim().isNotEmpty) entry.event.location.trim(),
  ];
  return parts.join(' · ');
}

/// The small square date chip on the left of every activity row.
class StudentActivityDateChip extends StatelessWidget {
  final DateTime date;
  final Color accent;
  final bool highlighted;

  const StudentActivityDateChip({
    super.key,
    required this.date,
    required this.accent,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? accent.withValues(alpha: 0.16)
            : StudentCampusPalette.solid,
        border: Border.all(
          color: highlighted
              ? accent.withValues(alpha: 0.42)
              : StudentCampusPalette.border,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              color: highlighted ? accent : StudentCampusPalette.textSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            _monthAbbr(context, date),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: highlighted
                  ? accent.withValues(alpha: 0.9)
                  : StudentCampusPalette.secondary,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Going / Happening now / Attended / Not scanned.
class StudentActivityBadge extends StatelessWidget {
  final StudentActivityEntry entry;

  const StudentActivityBadge({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    late final String label;
    late final IconData icon;
    late final Color foreground;
    late final Color background;
    late final Color border;

    if (entry.isLive) {
      label = l10n.activityLiveBadge;
      icon = Icons.sensors_rounded;
      foreground = isDark ? const Color(0xFFFF9E9E) : const Color(0xFFB3261E);
      background = isDark ? const Color(0x33FF5252) : const Color(0xFFFCE8E6);
      border = isDark ? const Color(0x66FF5252) : const Color(0xFFE9A19A);
    } else if (entry.isUpcoming) {
      label = l10n.activityGoingBadge;
      icon = Icons.event_available_rounded;
      foreground = isDark ? const Color(0xFFFFB3C8) : const Color(0xFF7A1638);
      background = isDark ? const Color(0x478C1D40) : const Color(0xFFF9E4EB);
      border = isDark ? const Color(0x73D96A8B) : const Color(0xFFC65C7D);
    } else if (entry.checkedIn) {
      label = l10n.activityAttendedBadge;
      icon = Icons.verified_rounded;
      foreground = isDark ? const Color(0xFF8FE0A8) : const Color(0xFF1B5E20);
      background = isDark ? const Color(0x2E4CAF50) : const Color(0xFFE6F4E9);
      border = isDark ? const Color(0x664CAF50) : const Color(0xFF9CC9A6);
    } else {
      label = l10n.activityUnconfirmedBadge;
      icon = Icons.radio_button_unchecked_rounded;
      foreground = StudentCampusPalette.secondary;
      background = Colors.transparent;
      border = StudentCampusPalette.borderStrong;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// One event on the record. Used identically in the profile preview and the
/// full-history screen so a row never looks different depending on where the
/// student is reading it.
class StudentActivityRow extends StatelessWidget {
  final StudentActivityEntry entry;
  final VoidCallback? onTap;
  final bool showDivider;

  const StudentActivityRow({
    super.key,
    required this.entry,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            decoration: BoxDecoration(
              border: showDivider
                  ? Border(
                      bottom: BorderSide(color: StudentCampusPalette.border),
                    )
                  : null,
            ),
            child: Row(
              children: [
                StudentActivityDateChip(
                  date: entry.start,
                  accent: entry.color,
                  highlighted: entry.isUpcoming,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: StudentCampusPalette.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: entry.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              activityMetaLine(context, entry),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: StudentCampusPalette.secondary,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      StudentActivityBadge(entry: entry),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: StudentCampusPalette.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The card shell shared by the preview and the full screen.
class StudentActivityCard extends StatelessWidget {
  final Widget child;

  const StudentActivityCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: StudentCampusPalette.card,
        border: Border.all(color: StudentCampusPalette.border),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
      ),
      child: child,
    );
  }
}

/// A quiet group heading inside an activity card ("Going · 2").
class StudentActivityGroupLabel extends StatelessWidget {
  final String label;

  const StudentActivityGroupLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
      color: StudentCampusPalette.solid.withValues(alpha: 0.45),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: StudentCampusPalette.secondary,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// First-year / no-record state. Matches the reference design's ticket icon,
/// explanation and call to action.
class StudentActivityEmpty extends StatelessWidget {
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  const StudentActivityEmpty({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.confirmation_number_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 34),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: StudentCampusPalette.burgundy.withValues(alpha: 0.18),
              border: Border.all(
                color: StudentCampusPalette.burgundy.withValues(alpha: 0.27),
              ),
              borderRadius: const BorderRadius.all(Radius.circular(22)),
            ),
            child: Icon(icon, size: 28, color: StudentCampusPalette.accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: StudentCampusPalette.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: StudentCampusPalette.secondary,
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                elevation: 0,
                backgroundColor: StudentCampusPalette.burgundy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(13)),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// The "Events & Activities" block embedded in a student profile: what they
/// are going to next, what they have already been to, and a way into the full
/// history.
class StudentActivityPreview extends StatelessWidget {
  final StudentActivitySummary summary;
  final bool isOwnProfile;
  final String studentName;
  final int upcomingLimit;
  final int pastLimit;
  final ValueChanged<StudentActivityEntry>? onEntryTap;
  final VoidCallback? onSeeAll;
  final VoidCallback? onBrowseEvents;

  const StudentActivityPreview({
    super.key,
    required this.summary,
    required this.isOwnProfile,
    required this.studentName,
    this.upcomingLimit = 2,
    this.pastLimit = 3,
    this.onEntryTap,
    this.onSeeAll,
    this.onBrowseEvents,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final upcoming = summary.upcoming.take(upcomingLimit).toList();
    final past = summary.past.take(pastLimit).toList();
    final hasMore = summary.total > upcoming.length + past.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: StudentProfileSectionLabel(l10n.eventsAndActivities),
              ),
              if (summary.isNotEmpty)
                StudentProfileTextButton(
                  label: l10n.activitySeeAllCount(summary.total),
                  onTap: onSeeAll,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StudentActivityCard(
            child: summary.isEmpty
                ? StudentActivityEmpty(
                    title: l10n.activityEmptyTitle,
                    body: isOwnProfile
                        ? l10n.activityEmptyBody
                        : l10n.activityEmptyBodyVisitor(studentName),
                    actionLabel: isOwnProfile && onBrowseEvents != null
                        ? l10n.activityBrowseEvents
                        : null,
                    onAction: isOwnProfile ? onBrowseEvents : null,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        StudentActivityGroupLabel(
                          l10n.activityGoingSection(summary.upcoming.length),
                        ),
                        for (var i = 0; i < upcoming.length; i++)
                          StudentActivityRow(
                            entry: upcoming[i],
                            onTap: onEntryTap == null
                                ? null
                                : () => onEntryTap!(upcoming[i]),
                            showDivider: i < upcoming.length - 1 || past.isNotEmpty,
                          ),
                      ],
                      if (past.isNotEmpty) ...[
                        StudentActivityGroupLabel(
                          l10n.activityPastSection(summary.past.length),
                        ),
                        for (var i = 0; i < past.length; i++)
                          StudentActivityRow(
                            entry: past[i],
                            onTap: onEntryTap == null
                                ? null
                                : () => onEntryTap!(past[i]),
                            showDivider: i < past.length - 1,
                          ),
                      ],
                      if (hasMore || onSeeAll != null)
                        _ViewHistoryFooter(
                          label: l10n.activityViewFullHistory,
                          onTap: onSeeAll,
                        ),
                    ],
                  ),
          ),
        ),
        if (summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l10n.activityCheckinFootnote,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: StudentCampusPalette.secondary,
                fontSize: 10.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _ViewHistoryFooter extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ViewHistoryFooter({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: StudentCampusPalette.border)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: StudentCampusPalette.accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kept for callers that need the locale-aware month/year heading used by the
/// full-history screen's group separators.
String activityMonthHeading(BuildContext context, DateTime date) {
  return DateFormat.yMMMM(
    Localizations.localeOf(context).languageCode,
  ).format(date);
}

/// Falls back to the app's own locale when no [BuildContext] is at hand.
String activityMonthHeadingForLocale(DateTime date) {
  return DateFormat.yMMMM(localeService.languageCode).format(date);
}
