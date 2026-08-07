import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/checkin_store.dart';
import '../services/rsvp_store.dart';
import '../services/student_activity_service.dart';
import '../widgets/student_activity_section.dart';
import '../widgets/student_campus_profile.dart';
import 'event_detail_screen.dart';
import 'this_week_screen.dart';

/// The full "Events & activities" history for one student — everything they
/// are going to and everything they have already been to, newest first inside
/// each academic year.
class StudentActivityScreen extends StatefulWidget {
  final String userId;
  final String studentName;
  final bool isOwnProfile;

  const StudentActivityScreen({
    super.key,
    required this.userId,
    required this.studentName,
    required this.isOwnProfile,
  });

  @override
  State<StudentActivityScreen> createState() => _StudentActivityScreenState();
}

class _StudentActivityScreenState extends State<StudentActivityScreen> {
  StudentActivityFilter _filter = StudentActivityFilter.all;

  @override
  void initState() {
    super.initState();
    // Door scans made on another device only reach this list after a remote
    // read, so refresh them once the history is actually being looked at.
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateAttendance());
  }

  Future<void> _hydrateAttendance() async {
    final summary = studentActivityService.summaryFor(widget.userId);
    if (summary.past.isEmpty) return;
    await studentActivityService.hydrateAttendance(summary.past);
  }

  void _openEvent(StudentActivityEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EventDetailScreen(event: entry.event, color: entry.color),
      ),
    );
  }

  void _browseEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ThisWeekScreen()),
    );
  }

  void _shareSummary(StudentActivitySummary summary) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(
      ClipboardData(
        text: l10n.activityShareSummary(
          widget.studentName,
          summary.attendedCount,
          summary.upcoming.length,
        ),
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.activitySummaryCopied),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: StudentCampusPalette.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([rsvpStore, checkinStore]),
          builder: (context, _) {
            final summary = studentActivityService.summaryFor(widget.userId);
            final entries = summary.forFilter(_filter);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _ActivityHeader(
                    title: widget.isOwnProfile
                        ? l10n.eventsAndActivities
                        : l10n.activityOtherTitle(widget.studentName),
                    subtitle: widget.isOwnProfile
                        ? l10n.activityOwnerSubtitle
                        : l10n.activityVisitorSubtitle(widget.studentName),
                    onBack: () => Navigator.maybePop(context),
                    onShare: summary.isEmpty
                        ? null
                        : () => _shareSummary(summary),
                  ),
                ),
                if (summary.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: _ActivityStatsStrip(summary: summary),
                    ),
                  ),
                if (summary.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _ActivityFilterBar(
                        selected: _filter,
                        counts: {
                          StudentActivityFilter.all: summary.total,
                          StudentActivityFilter.upcoming:
                              summary.upcoming.length,
                          StudentActivityFilter.past: summary.past.length,
                        },
                        onChanged: (value) => setState(() => _filter = value),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: entries.isEmpty
                        ? StudentActivityCard(
                            child: _emptyState(context, summary),
                          )
                        : _ActivityGroupedList(
                            entries: entries,
                            onEntryTap: _openEvent,
                          ),
                  ),
                ),
                if (entries.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Text(
                        l10n.activityCheckinFootnote,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: StudentCampusPalette.secondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: bottomInset + 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, StudentActivitySummary summary) {
    final l10n = AppLocalizations.of(context)!;

    // No record at all is a different message from "this tab happens to be
    // empty" — the first invites the student in, the second just explains.
    if (summary.isEmpty) {
      return StudentActivityEmpty(
        title: l10n.activityEmptyTitle,
        body: widget.isOwnProfile
            ? l10n.activityEmptyBody
            : l10n.activityEmptyBodyVisitor(widget.studentName),
        actionLabel: widget.isOwnProfile ? l10n.activityBrowseEvents : null,
        onAction: widget.isOwnProfile ? _browseEvents : null,
      );
    }

    if (_filter == StudentActivityFilter.upcoming) {
      return StudentActivityEmpty(
        title: l10n.activityNoUpcoming,
        body: l10n.activityNoUpcomingBody,
        icon: Icons.event_available_outlined,
        actionLabel: widget.isOwnProfile ? l10n.activityBrowseEvents : null,
        onAction: widget.isOwnProfile ? _browseEvents : null,
      );
    }

    return StudentActivityEmpty(
      title: l10n.activityNoPast,
      body: l10n.activityNoPastBody,
      icon: Icons.history_rounded,
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onShare;

  const _ActivityHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudentProfileIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: l10n.backTooltip,
                onTap: onBack,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.activityTitle,
                  style: TextStyle(
                    color: StudentCampusPalette.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onShare != null)
                StudentProfileIconButton(
                  icon: Icons.ios_share_outlined,
                  tooltip: l10n.activityShareTooltip,
                  onTap: onShare,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: StudentCampusPalette.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 13,
                color: StudentCampusPalette.secondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: StudentCampusPalette.secondary,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _ActivityStatsStrip extends StatelessWidget {
  final StudentActivitySummary summary;

  const _ActivityStatsStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: StudentCampusPalette.card,
        border: Border.all(color: StudentCampusPalette.border),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: [
          _ActivityStat(
            value: summary.attendedCount,
            label: l10n.activityStatAttended,
          ),
          _ActivityStat(
            value: summary.upcoming.length,
            label: l10n.activityStatUpcoming,
          ),
          _ActivityStat(
            value: summary.clubCount,
            label: l10n.activityStatClubs,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  final int value;
  final String label;
  final bool showDivider;

  const _ActivityStat({
    required this.value,
    required this.label,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(right: BorderSide(color: StudentCampusPalette.border))
              : null,
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: StudentCampusPalette.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: StudentCampusPalette.secondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityFilterBar extends StatelessWidget {
  final StudentActivityFilter selected;
  final Map<StudentActivityFilter, int> counts;
  final ValueChanged<StudentActivityFilter> onChanged;

  const _ActivityFilterBar({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      StudentActivityFilter.all: l10n.activityFilterAll,
      StudentActivityFilter.upcoming: l10n.activityFilterUpcoming,
      StudentActivityFilter.past: l10n.activityFilterPast,
    };

    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: StudentCampusPalette.card,
        border: Border.all(color: StudentCampusPalette.border),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: switch (selected) {
              StudentActivityFilter.all => Alignment.centerLeft,
              StudentActivityFilter.upcoming => Alignment.center,
              StudentActivityFilter.past => Alignment.centerRight,
            },
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: StudentCampusPalette.burgundy,
                  borderRadius: const BorderRadius.all(Radius.circular(11)),
                  boxShadow: [
                    BoxShadow(
                      color: StudentCampusPalette.burgundy.withValues(
                        alpha: 0.22,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final filter in StudentActivityFilter.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: filter == selected,
                    label: labels[filter],
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onChanged(filter),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(11),
                        ),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              color: filter == selected
                                  ? Colors.white
                                  : StudentCampusPalette.textSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            child: Text(
                              '${labels[filter]} ${counts[filter] ?? 0}',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Groups a flat, already-sorted list into academic years so a multi-year
/// record stays readable ("2025–26 academic year").
class _ActivityGroupedList extends StatelessWidget {
  final List<StudentActivityEntry> entries;
  final ValueChanged<StudentActivityEntry> onEntryTap;

  const _ActivityGroupedList({required this.entries, required this.onEntryTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = <String, List<StudentActivityEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(academicYearLabel(entry.start), () => []).add(entry);
    }

    final labels = groups.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // newest academic year first

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var g = 0; g < labels.length; g++) ...[
          if (g > 0) const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                Expanded(
                  child: StudentProfileSectionLabel(
                    l10n.activityAcademicYear(labels[g]),
                  ),
                ),
                Text(
                  l10n.activityEventCount(groups[labels[g]]!.length),
                  style: TextStyle(
                    color: StudentCampusPalette.secondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          StudentActivityCard(
            child: Column(
              children: [
                for (var i = 0; i < groups[labels[g]]!.length; i++)
                  StudentActivityRow(
                    entry: groups[labels[g]]![i],
                    onTap: () => onEntryTap(groups[labels[g]]![i]),
                    showDivider: i < groups[labels[g]]!.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
