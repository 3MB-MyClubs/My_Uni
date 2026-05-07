import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
import '../widgets/club_avatar.dart';
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
  bool _programmeExpanded = false;

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
                        ClubAvatar(
                          clubId: club.id,
                          clubName: club.name,
                          color: color,
                          size: 44,
                          fontSize: 20,
                          borderRadius: 12,
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

                  // ── Activity Tags ──────────────────────────────────────────
                  if (event.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: event.tags.map((tag) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],

                  // ── Featured Guest ─────────────────────────────────────────
                  if (event.guestSpeaker != null) ...[
                    const SizedBox(height: 20),
                    const Text('Featured Guest',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.mic_rounded, color: color, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              event.guestSpeaker!,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text),
                            ),
                          ),
                          const Icon(Icons.star_rounded,
                              color: AppColors.accentGold, size: 18),
                        ],
                      ),
                    ),
                  ],

                  // ── Programme ──────────────────────────────────────────────
                  if (event.schedule != null &&
                      event.schedule!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Programme',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _ProgrammeCard(
                      event: event,
                      color: color,
                      expanded: _programmeExpanded,
                      onToggle: () =>
                          setState(() => _programmeExpanded = !_programmeExpanded),
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── RSVP bottom panel ────────────────────────────────────────────────────
      bottomNavigationBar: _RsvpPanel(
        event: event,
        color: color,
        isPast: isPast,
      ),
    );
  }
}

// ─── RSVP Bottom Panel ────────────────────────────────────────────────────────

class _RsvpPanel extends StatelessWidget {
  final Event event;
  final Color color;
  final bool isPast;

  const _RsvpPanel({
    required this.event,
    required this.color,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rsvpStore,
      builder: (context, _) {
        final attending = rsvpStore.isAttending(event.id);
        final count = event.attendeeUserIds.length;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Attendee social proof row ──────────────────────────────
                  if (!isPast && count > 0) ...[
                    Row(
                      children: [
                        // Stacked avatar circles
                        SizedBox(
                          width: (count.clamp(1, 4) * 20 + 12).toDouble(),
                          height: 26,
                          child: Stack(
                            children: List.generate(count.clamp(1, 4), (i) {
                              final hue = (i * 60.0) % 360;
                              return Positioned(
                                left: i * 20.0,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor(),
                                    border: Border.all(color: AppColors.card, width: 2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + i),
                                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            attending
                                ? 'You + ${count - 1} ${count - 1 == 1 ? 'other' : 'others'} going'
                                : '$count ${count == 1 ? 'person' : 'people'} going — join them!',
                            style: TextStyle(
                              fontSize: 12,
                              color: attending
                                  ? color.withValues(alpha: 0.9)
                                  : AppColors.secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Add to calendar — compact icon
                        GestureDetector(
                          onTap: () {
                            cal.Add2Calendar.addEvent2Cal(cal.Event(
                              title: event.title,
                              description: event.description,
                              location: event.location,
                              startDate: event.dateTime,
                              endDate: event.endTime,
                              allDay: false,
                            ));
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withValues(alpha: 0.2)),
                            ),
                            child: Icon(Icons.calendar_month_outlined, size: 18, color: color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── RSVP button ────────────────────────────────────────────
                  RsvpButton(
                    eventId: event.id,
                    color: color,
                    isPast: isPast,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Programme Card ───────────────────────────────────────────────────────────

class _ProgrammeCard extends StatelessWidget {
  final Event event;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;

  const _ProgrammeCard({
    required this.event,
    required this.color,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = event.schedule!;
    final isRsvpd = rsvpStore.isAttending(event.id);
    final locked = event.scheduleGated && !isRsvpd;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Collapsed / locked header
          if (!expanded || locked)
            InkWell(
              onTap: locked ? null : onToggle,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: locked
                    ? Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 18, color: AppColors.secondaryText),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'RSVP to unlock the full programme',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ListenableBuilder(
                            listenable: rsvpStore,
                            builder: (ctx, _) => _InlineRsvpButton(
                              eventId: event.id,
                              color: color,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(Icons.format_list_bulleted_rounded,
                              size: 16, color: color),
                          const SizedBox(width: 8),
                          Text(
                            '${schedule.length} sessions',
                            style: TextStyle(
                                fontSize: 13,
                                color: color,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text('Show programme',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: color,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: color),
                        ],
                      ),
              ),
            ),

          // Expanded slots
          if (expanded && !locked) ...[
            GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    Icon(Icons.format_list_bulleted_rounded,
                        size: 16, color: color),
                    const SizedBox(width: 8),
                    Text('${schedule.length} sessions',
                        style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('Hide',
                        style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_up_rounded,
                        size: 18, color: color),
                  ],
                ),
              ),
            ),
            for (int i = 0; i < schedule.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.divider),
              _SlotRow(slot: schedule[i], color: color),
            ],
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final EventSlot slot;
  final Color color;
  const _SlotRow({required this.slot, required this.color});

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: slot.isHighlighted
          ? color.withValues(alpha: 0.06)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          SizedBox(
            width: 44,
            child: Text(
              _fmtTime(slot.time),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: slot.isHighlighted ? color : AppColors.secondaryText,
              ),
            ),
          ),
          // Accent bar
          Container(
            width: 3,
            height: slot.subtitle != null ? 36 : 18,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: slot.isHighlighted
                  ? color
                  : color.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: slot.isHighlighted
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                if (slot.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    slot.subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: slot.isHighlighted
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: slot.isHighlighted
                          ? color
                          : AppColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineRsvpButton extends StatelessWidget {
  final String eventId;
  final Color color;
  const _InlineRsvpButton({required this.eventId, required this.color});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rsvpStore,
      builder: (ctx, _) {
        final attending = rsvpStore.isAttending(eventId);
        return GestureDetector(
          onTap: () {
            final userId =
                authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
            rsvpStore.toggle(eventId, userId);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: attending ? Colors.transparent : color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: attending
                    ? AppColors.secondaryText.withValues(alpha: 0.4)
                    : color,
              ),
            ),
            child: Text(
              attending ? 'Going ✓' : 'RSVP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: attending ? AppColors.secondaryText : Colors.white,
              ),
            ),
          ),
        );
      },
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
