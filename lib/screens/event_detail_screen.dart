import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
import '../widgets/rsvp_button.dart';
import 'campus_map_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;
  final Color color;

  const EventDetailScreen({super.key, required this.event, required this.color});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  static const List<String> _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _weekdays = [
    '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  String get _loggedInId =>
      authService.currentAdmin?.id ?? authService.currentUser?.id ?? '';

  bool get _isOwner =>
      widget.event.createdByUserId != null &&
      widget.event.createdByUserId == _loggedInId;

  bool get _isEventOwnerClub {
    final admin = authService.currentAdmin;
    if (admin == null) return false;
    try {
      return clubs.firstWhere((c) => c.adminUserIds.contains(admin.id)).id ==
          widget.event.clubId;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Seed global RSVP store from current data model state
    final userId = authService.currentUser?.id ?? '';
    rsvpStore.seed(
      widget.event.id,
      widget.event.attendeeUserIds.contains(userId),
    );
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete event?',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
        content: const Text('This event will be permanently removed.',
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true || !mounted) return;
      final ok = contentStore.deleteEvent(widget.event.id, _loggedInId);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        Navigator.popUntil(context, (r) => r.isFirst);
      }
    });
  }

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
    final event = widget.event;
    final color = widget.color;
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
            actions: [
              if (_isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: _confirmDelete,
                ),
            ],
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
                      // Attending count — only shown to the owner club admin,
                      // rebuilds when RSVP changes
                      if (_isEventOwnerClub) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ListenableBuilder(
                            listenable: rsvpStore,
                            builder: (context, _) => _InfoCard(
                              icon: Icons.people_rounded,
                              label: 'Attending',
                              value: '${event.attendeeUserIds.length} people',
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── View on Map button ─────────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CampusMapScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.map_outlined, color: color, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            'View on Campus Map',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color.withValues(alpha: 0.7)),
                        ],
                      ),
                    ),
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

      // ── RSVP button — reads from global store, identical on every screen ────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: RsvpButton(
            eventId: event.id,
            color: color,
            isPast: isPast,
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
