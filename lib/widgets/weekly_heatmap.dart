import 'package:flutter/material.dart';
import '../models/weekly_density_bucket.dart';
import '../services/app_colors.dart';

// ── Color scale: 5 steps from quiet (dim) to packed (vivid) ─────────────────
List<Color> _intensityColors(Color accent) => [
  Colors.transparent, // 0 = no data / truly empty
  accent.withValues(alpha: 0.18), // 1 = very quiet
  accent.withValues(alpha: 0.38), // 2 = light activity
  accent.withValues(alpha: 0.62), // 3 = busy
  accent.withValues(alpha: 0.88), // 4 = packed
];

const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Compact 7 × 4 weekly heatmap grid.
///
/// Columns = Mon–Sun, Rows = Morning / Afternoon / Evening / Night.
/// Tapping a day column calls [onDayTapped] with the ISO weekday (1–7).
class WeeklyHeatmap extends StatelessWidget {
  final WeeklyDensityData data;
  final Color accent;
  final int? selectedWeekday; // highlighted column (1–7), or null
  final ValueChanged<int>? onDayTapped;

  const WeeklyHeatmap({
    super.key,
    required this.data,
    required this.accent,
    this.selectedWeekday,
    this.onDayTapped,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _intensityColors(accent);
    final now = DateTime.now();
    final todayWd = now.weekday; // 1–7
    final currentBlock = timeBlockForHour(now.hour);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Grid ──────────────────────────────────────────────────────────
        Row(
          children: [
            // Row-label column
            _RowLabels(),
            const SizedBox(width: 4),
            // Day columns
            Expanded(
              child: Row(
                children: List.generate(7, (colIdx) {
                  final wd = colIdx + 1; // 1=Mon … 7=Sun
                  final isToday = wd == todayWd;
                  final isSelected = wd == selectedWeekday;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDayTapped?.call(wd),
                      child: Column(
                        children: [
                          // Day label
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent
                                  : isToday
                                  ? accent.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _dayLabels[colIdx],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                    ? accent
                                    : AppColors.secondaryText,
                              ),
                            ),
                          ),
                          // 4 time-block cells
                          ...TimeBlock.values.map((block) {
                            final bucket = data.bucketFor(wd, block);
                            final step = bucket.intensity.round().clamp(0, 4);
                            final cellColor = colors[step];
                            final isLive = bucket.isLiveNow;
                            final isCurrentCell =
                                isToday && block == currentBlock;

                            return Container(
                              height: 22,
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: cellColor,
                                borderRadius: BorderRadius.circular(5),
                                border: isLive
                                    ? Border.all(
                                        color: Colors.red.withValues(
                                          alpha: 0.7,
                                        ),
                                        width: 1.5,
                                      )
                                    : isCurrentCell
                                    ? Border.all(
                                        color: accent.withValues(alpha: 0.5),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: isLive
                                  ? Center(
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : null,
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── Legend + source label ──────────────────────────────────────────
        Row(
          children: [
            // Quiet → Packed gradient legend
            Text(
              'Quiet',
              style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
            ),
            const SizedBox(width: 4),
            ...List.generate(4, (i) {
              return Container(
                width: 14,
                height: 10,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: colors[i + 1],
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
            const SizedBox(width: 4),
            Text(
              'Packed',
              style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
            ),
            const Spacer(),
            if (data.hasLocationData)
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 10,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '+ your activity',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Based on events',
                style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Row labels (time blocks) ──────────────────────────────────────────────────

class _RowLabels extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24), // spacer matching day-label height
        ...TimeBlock.values.map(
          (b) => Container(
            height: 22,
            margin: const EdgeInsets.all(1.5),
            alignment: Alignment.centerRight,
            child: Text(
              b.shortLabel,
              style: TextStyle(fontSize: 9, color: AppColors.secondaryText),
            ),
          ),
        ),
      ],
    );
  }
}
