import 'package:flutter/material.dart';
import '../models/weekly_density_bucket.dart';
import '../screens/event_detail_screen.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/campus_pulse_service.dart';
import '../services/location_permission_service.dart';
import '../services/mock_data.dart';
import '../screens/campus_pulse_consent_sheet.dart';
import 'weekly_heatmap.dart';

/// Feed card that shows the "Campus Pulse" weekly heatmap.
///
/// Shows:
///  • Summary sentence
///  • 7 × 4 heatmap grid
///  • Expandable day-detail panel when a column is tapped
///  • "Share location" prompt if not yet opted in and explainer not shown
class CampusPulseCard extends StatefulWidget {
  const CampusPulseCard({super.key});

  @override
  State<CampusPulseCard> createState() => _CampusPulseCardState();
}

class _CampusPulseCardState extends State<CampusPulseCard> {
  WeeklyDensityData? _densityData;
  int? _selectedWeekday;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Try a passive location sample if already opted in.
    campusPulseService.maybeSample().then((_) {
      if (mounted) {
        setState(
          () => _densityData = campusPulseService.computeWeeklyDensity(),
        );
      }
    });
  }

  void _refresh() {
    setState(() {
      _densityData = campusPulseService.computeWeeklyDensity();
    });
  }

  String get _userId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  bool get _showLocationNudge =>
      !campusPulseService.optedIn &&
      !locationPermissionService.wasExplainerShown(_userId);

  Future<void> _onLocationNudge() async {
    await showCampusPulseConsentSheet(context);
    if (mounted) _refresh();
  }

  void _onDayTapped(int weekday) {
    setState(() {
      _selectedWeekday = _selectedWeekday == weekday ? null : weekday;
    });
  }

  @override
  Widget build(BuildContext context) {
    final density = _densityData;
    if (density == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 13,
                        color: AppColors.primaryRed,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Campus Pulse',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'This Week',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),

          // ── Summary sentence ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Text(
              density.summary,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.text,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),

          // ── Heatmap grid ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: WeeklyHeatmap(
              data: density,
              accent: AppColors.primaryRed,
              selectedWeekday: _selectedWeekday,
              onDayTapped: _onDayTapped,
            ),
          ),

          // ── Expanded day detail ───────────────────────────────────────────
          if (_selectedWeekday != null)
            _DayDetailPanel(
              weekday: _selectedWeekday!,
              density: density,
              accent: AppColors.primaryRed,
            ),

          // ── Location nudge ────────────────────────────────────────────────
          if (_showLocationNudge) _LocationNudge(onTap: _onLocationNudge),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Day detail panel ──────────────────────────────────────────────────────────

class _DayDetailPanel extends StatelessWidget {
  final int weekday;
  final WeeklyDensityData density;
  final Color accent;

  static const _dayNames = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  const _DayDetailPanel({
    required this.weekday,
    required this.density,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final dayBuckets = density.buckets
        .where((b) => b.weekday == weekday)
        .toList();

    final peak = dayBuckets.reduce(
      (a, b) => a.intensity >= b.intensity ? a : b,
    );

    final totalEvents = dayBuckets.fold<int>(0, (sum, b) => sum + b.eventCount);

    final hasLive = dayBuckets.any((b) => b.isLiveNow);

    // Events for this day
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final dayDate = weekStart.add(Duration(days: weekday - 1));
    final dayEvents =
        events
            .where(
              (e) =>
                  e.dateTime.year == dayDate.year &&
                  e.dateTime.month == dayDate.month &&
                  e.dateTime.day == dayDate.day,
            )
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Row(
            children: [
              Text(
                _dayNames[weekday],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.text,
                ),
              ),
              if (hasLive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Live now',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Stats row
          Row(
            children: [
              _StatChip(
                icon: Icons.schedule_rounded,
                label: 'Busiest: ${peak.timeBlock.label}',
                accent: accent,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.event_rounded,
                label: '$totalEvents event${totalEvents == 1 ? '' : 's'}',
                accent: accent,
              ),
            ],
          ),

          // Event list (up to 3)
          if (dayEvents.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...dayEvents.take(3).map((e) {
              final isLive = !e.dateTime.isAfter(now) && e.endTime.isAfter(now);
              final h = e.dateTime.hour;
              final m = e.dateTime.minute.toString().padLeft(2, '0');
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(event: e, color: accent),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isLive ? Colors.red : accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        '$h:$m · ${e.title}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 4),
          Text(
            peak.sourceLabel,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.secondaryText.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Location nudge banner ─────────────────────────────────────────────────────

class _LocationNudge extends StatelessWidget {
  final VoidCallback onTap;
  const _LocationNudge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 15,
              color: AppColors.secondaryText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Share anonymous location to improve this heatmap',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Learn more',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
