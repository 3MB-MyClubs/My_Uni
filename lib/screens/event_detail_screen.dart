import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/mock_data.dart';

class EventDetailScreen extends StatelessWidget {
  final Event event;
  final Color color;

  const EventDetailScreen({super.key, required this.event, required this.color});

  static const List<String> _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _weekdays = [
    '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _formatTime(DateTime dt) =>
      '${_pad(dt.hour)}:${_pad(dt.minute)}';

  String _formatDate(DateTime dt) =>
      '${_weekdays[dt.weekday]}, ${dt.day} ${_months[dt.month]} ${dt.year}';

  String _daysLabel(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Passed';
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    return 'In ${diff.inDays} days';
  }

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == event.clubId, orElse: () => clubs.first);
    final diff = event.dateTime.difference(DateTime.now());
    final isPast = diff.isNegative;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: color,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            expandedHeight: 200,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _daysLabel(event.dateTime),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info cards row ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _InfoCard(
                        icon: Icons.calendar_today_rounded,
                        label: 'Date',
                        value: _formatDate(event.dateTime),
                        color: color,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _InfoCard(
                        icon: Icons.schedule_rounded,
                        label: 'Time',
                        value: '${_formatTime(event.dateTime)} – ${_formatTime(event.endTime)}',
                        color: color,
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _InfoCard(
                        icon: Icons.location_on_rounded,
                        label: 'Location',
                        value: event.location,
                        color: color,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _InfoCard(
                        icon: Icons.people_rounded,
                        label: 'Attending',
                        value: '${event.attendeeUserIds.length} people',
                        color: color,
                      )),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Organiser ──────────────────────────────────────────────
                  const Text('Organised by',
                      style: TextStyle(fontSize: 13, color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              club.name[0],
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            club.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Description ────────────────────────────────────────────
                  const Text('About this event',
                      style: TextStyle(fontSize: 13, color: AppColors.secondaryText, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      event.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Register / Passed button ─────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: isPast ? null : () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: isPast ? AppColors.surfaceAlt : color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.surfaceAlt,
                disabledForegroundColor: AppColors.secondaryText,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                isPast ? 'This event has passed' : 'Register for this event',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
