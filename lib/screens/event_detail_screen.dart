import 'dart:io';
import 'package:flutter/material.dart';
import '../features/calendar/widgets/add_to_calendar_button.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/content_store.dart';
import '../services/event_access.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
import '../services/view_tracker.dart';
import '../widgets/club_avatar.dart';
import '../widgets/club_follow_button.dart';
import '../widgets/rsvp_button.dart';

// ─────────────────────────────────────────────────────────────────────────────

class EventDetailScreen extends StatefulWidget {
  final Event event;
  final Color color;

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.color,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _programmeExpanded = false;

  String get _loggedInId =>
      authService.currentAdmin?.id ?? authService.currentUser?.id ?? '';

  bool get _isOwner =>
      widget.event.createdByUserId != null &&
      widget.event.createdByUserId == _loggedInId;

  bool get _canViewAttendance => canViewEventAttendance(widget.event);

  bool get _isLive {
    final now = DateTime.now();
    return !widget.event.dateTime.isAfter(now) &&
        widget.event.endTime.isAfter(now);
  }

  @override
  void initState() {
    super.initState();
    final userId = authService.currentUser?.id ?? '';
    rsvpStore.seed(
      widget.event.id,
      widget.event.attendeeUserIds.contains(userId),
    );
    final viewerId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    viewTracker.recordView(widget.event.id, viewerId);
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete event?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: Text(
          'This event will be permanently removed.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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

  String _countdownLabel() {
    if (_isLive) return 'Happening now';
    final diff = widget.event.dateTime.difference(DateTime.now());
    if (diff.isNegative) return 'Ended';
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    return 'In ${diff.inDays} days';
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    // Use creator-chosen accent color if set, otherwise fall back to club color
    final color = event.accentColorHex != null
        ? Color(int.parse('FF${event.accentColorHex}', radix: 16))
        : widget.color;
    final club = clubs.firstWhere(
      (c) => c.id == event.clubId,
      orElse: () => clubs.first,
    );
    final isPast = event.endTime.isBefore(DateTime.now());
    final hasImage = event.imagePath != null && event.imagePath!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero ──────────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: color,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            expandedHeight: 280,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            actions: [
              if (_isOwner)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: _confirmDelete,
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image or gradient background
                  if (hasImage)
                    Image.file(
                      File(event.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, s) => _GradientHero(color: color),
                    )
                  else
                    _GradientHero(color: color),

                  // Bottom scrim for text legibility
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 180,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Hero content: countdown chip + title + club badge
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status chip row
                        Row(
                          children: [
                            _HeroChip(
                              label: _countdownLabel(),
                              isLive: _isLive,
                              color: color,
                            ),
                            if (event.tags.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              ...event.tags
                                  .take(2)
                                  .map(
                                    (t) => Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: _HeroTagPill(label: t),
                                    ),
                                  ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Title
                        Text(
                          event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.15,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Club badge
                        Row(
                          children: [
                            ClubAvatar(
                              clubId: club.id,
                              clubName: club.name,
                              color: color,
                              size: 26,
                              fontSize: 11,
                              borderRadius: 8,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                club.name,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Quick info card ──────────────────────────────────────
                  _QuickInfoCard(
                    event: event,
                    color: color,
                    showAttendance: _canViewAttendance,
                  ),

                  const SizedBox(height: 10),

                  // ── About ────────────────────────────────────────────────
                  _SectionLabel('About this event'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                        height: 1.65,
                      ),
                    ),
                  ),

                  // ── Tags ─────────────────────────────────────────────────
                  if (event.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: event.tags
                            .map(
                              (tag) => Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],

                  // ── Guest speaker ─────────────────────────────────────────
                  if (event.guestSpeaker != null) ...[
                    const SizedBox(height: 20),
                    _SectionLabel('Featured Guest'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.accentGold.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.mic_rounded,
                              color: AppColors.accentGold,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Guest Speaker',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondaryText,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  event.guestSpeaker!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.star_rounded,
                            color: AppColors.accentGold,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Programme ─────────────────────────────────────────────
                  if (event.schedule != null && event.schedule!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionLabel('Programme'),
                    const SizedBox(height: 8),
                    _ProgrammeCard(
                      event: event,
                      color: color,
                      expanded: _programmeExpanded,
                      onToggle: () => setState(
                        () => _programmeExpanded = !_programmeExpanded,
                      ),
                    ),
                  ],

                  // ── Organised by ──────────────────────────────────────────
                  const SizedBox(height: 20),
                  _SectionLabel('Organised by'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        ClubAvatar(
                          clubId: club.id,
                          clubName: club.name,
                          color: color,
                          size: 52,
                          fontSize: 22,
                          borderRadius: 14,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                club.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                club.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ClubFollowButton(clubId: club.id, size: 'small'),
                      ],
                    ),
                  ),

                  // ── Attending count (admin only) ───────────────────────────
                  if (_canViewAttendance) ...[
                    const SizedBox(height: 16),
                    ListenableBuilder(
                      listenable: rsvpStore,
                      builder: (_, child) => _AttendeeBar(
                        count: event.attendeeUserIds.length,
                        color: color,
                      ),
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── RSVP bottom panel ────────────────────────────────────────────────
      bottomNavigationBar: _RsvpPanel(
        event: event,
        color: color,
        isPast: isPast,
        showAttendance: _canViewAttendance,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero background gradient
// ─────────────────────────────────────────────────────────────────────────────

class _GradientHero extends StatelessWidget {
  final Color color;
  const _GradientHero({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 80,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero chips
// ─────────────────────────────────────────────────────────────────────────────

class _HeroChip extends StatelessWidget {
  final String label;
  final bool isLive;
  final Color color;
  const _HeroChip({
    required this.label,
    required this.isLive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isLive
            ? const Color(0xFFEF5350).withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive
              ? const Color(0xFFEF5350).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            _PulseDot(color: const Color(0xFFEF5350)),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isLive ? const Color(0xFFEF5350) : Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTagPill extends StatelessWidget {
  final String label;
  const _HeroTagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick info card (date · time · location in one card)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickInfoCard extends StatelessWidget {
  final Event event;
  final Color color;
  final bool showAttendance;
  const _QuickInfoCard({
    required this.event,
    required this.color,
    required this.showAttendance,
  });

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmtTime(DateTime dt) => '${_pad(dt.hour)}:${_pad(dt.minute)}';

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _wdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_wdays[event.dateTime.weekday]}, ${_months[event.dateTime.month]} ${event.dateTime.day}';
    final timeStr = '${_fmtTime(event.dateTime)} – ${_fmtTime(event.endTime)}';
    final attendeeCount = event.attendeeUserIds.toSet().length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: dateStr,
            color: color,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.divider,
          ),
          _InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Time',
            value: timeStr,
            color: color,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.divider,
          ),
          _InfoRow(
            icon: Icons.location_on_rounded,
            label: 'Location',
            value: event.location,
            color: color,
          ),
          if (showAttendance) ...[
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: AppColors.divider,
            ),
            _InfoRow(
              icon: Icons.people_outline_rounded,
              label: 'Attending',
              value:
                  '$attendeeCount ${attendeeCount == 1 ? 'person' : 'people'} going',
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendee bar (admin view)
// ─────────────────────────────────────────────────────────────────────────────

class _AttendeeBar extends StatelessWidget {
  final int count;
  final Color color;
  const _AttendeeBar({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.people_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            '$count ${count == 1 ? 'person has' : 'people have'} RSVP\'d',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.secondaryText,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RSVP bottom panel
// ─────────────────────────────────────────────────────────────────────────────

class _RsvpPanel extends StatelessWidget {
  final Event event;
  final Color color;
  final bool isPast;
  final bool showAttendance;

  const _RsvpPanel({
    required this.event,
    required this.color,
    required this.isPast,
    required this.showAttendance,
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
              top: BorderSide(color: AppColors.divider, width: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showAttendance && !isPast && count > 0) ...[
                    Row(
                      children: [
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
                                    color: HSLColor.fromAHSL(
                                      1,
                                      hue,
                                      0.55,
                                      0.42,
                                    ).toColor(),
                                    border: Border.all(
                                      color: AppColors.card,
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    String.fromCharCode(65 + i),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  RsvpButton(eventId: event.id, color: color, isPast: isPast),
                  if (!isPast) ...[
                    const SizedBox(height: 8),
                    AddToCalendarButton(event: event, color: color),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Programme card
// ─────────────────────────────────────────────────────────────────────────────

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
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          if (!expanded || locked)
            InkWell(
              onTap: locked ? null : onToggle,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: locked
                    ? Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'RSVP to unlock the full programme',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                              ),
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
                          Icon(
                            Icons.format_list_bulleted_rounded,
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${schedule.length} sessions',
                            style: TextStyle(
                              fontSize: 13,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Show programme',
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: color,
                          ),
                        ],
                      ),
              ),
            ),
          if (expanded && !locked) ...[
            GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${schedule.length} sessions',
                      style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Hide',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 18,
                      color: color,
                    ),
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
                  color: AppColors.divider,
                ),
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

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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
          Container(
            width: 3,
            height: slot.subtitle != null ? 36 : 18,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: slot.isHighlighted ? color : color.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
                authService.currentUser?.id ??
                authService.currentAdmin?.id ??
                '';
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

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing dot (live indicator)
// ─────────────────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
