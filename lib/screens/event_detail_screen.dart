import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/calendar/widgets/add_to_calendar_button.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
import '../services/view_tracker.dart';
import '../widgets/club_avatar.dart';
import '../widgets/rsvp_button.dart';
import 'club_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Event detail — recreation of the "Event Information" design handoff.
// Full-bleed hero photo, ticket-style date/time/location card, host card,
// registration link, about, tags, programme timeline, speakers and a sticky
// register / add-to-calendar CTA.
// ─────────────────────────────────────────────────────────────────────────────

class EventDetailScreen extends StatefulWidget {
  final Event event;
  final Color color;

  const EventDetailScreen({super.key, required this.event, required this.color});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _saved = false;

  String get _loggedInId =>
      authService.currentAdmin?.id ?? authService.currentUser?.id ?? '';

  bool get _isOwner =>
      widget.event.createdByUserId != null &&
      widget.event.createdByUserId == _loggedInId;

  bool get _isLive {
    final now = DateTime.now();
    return !widget.event.dateTime.isAfter(now) &&
        widget.event.endTime.isAfter(now);
  }

  bool get _isPast => !widget.event.endTime.isAfter(DateTime.now());

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

  Color get _accent => widget.event.accentColorHex != null
      ? Color(int.parse('FF${widget.event.accentColorHex}', radix: 16))
      : widget.color;

  // ── Actions ─────────────────────────────────────────────────────────────────
  void _toggleSaved() {
    setState(() => _saved = !_saved);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_saved ? 'Saved to your events' : 'Removed from saved'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _saved ? _accent : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  void _shareEvent() {
    Clipboard.setData(ClipboardData(text: 'kuclubs://event/${widget.event.id}'));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Event link copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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

  void _openClub() {
    final club = clubs.firstWhere(
      (c) => c.id == widget.event.clubId,
      orElse: () => clubs.first,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubProfileScreen(club: club, color: _accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final accent = _accent;
    final hasReg =
        event.registrationUrl != null &&
        event.registrationUrl!.trim().isNotEmpty;
    final hasProgramme = event.schedule != null && event.schedule!.isNotEmpty;
    final hasSpeakers = event.speakers.isNotEmpty;
    final hasCapacity = event.capacity != null && event.capacity! > 0;
    final showCta = !_isPast;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────────
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: showCta ? 168 : 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero photo + nav + status + title
                  _Hero(
                    event: event,
                    accent: accent,
                    isLive: _isLive,
                    isPast: _isPast,
                    saved: _saved,
                    isOwner: _isOwner,
                    onBack: () => Navigator.pop(context),
                    onToggleSaved: _toggleSaved,
                    onShare: _shareEvent,
                    onDelete: _confirmDelete,
                  ),

                  // Ticket-style date / time / location (+ capacity)
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: ListenableBuilder(
                        listenable: rsvpStore,
                        builder: (_, _) => _TicketCard(
                          event: event,
                          accent: accent,
                          countdown: _countdownLabel(),
                          showCapacity: hasCapacity,
                          takenSeats:
                              event.attendeeUserIds.length +
                              (rsvpStore.isAttending(event.id) &&
                                      !event.attendeeUserIds.contains(
                                        _loggedInId,
                                      )
                                  ? 1
                                  : 0),
                        ),
                      ),
                    ),
                  ),

                  // Host
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _HostCard(
                      event: event,
                      accent: accent,
                      onView: _openClub,
                    ),
                  ),

                  // Registration link
                  if (hasReg)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _RegistrationCard(
                        url: event.registrationUrl!.trim(),
                        accent: accent,
                      ),
                    ),

                  // About
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SecHead('About this event'),
                        const SizedBox(height: 12),
                        Text(
                          event.description,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.65,
                            color: AppColors.text.withValues(alpha: 0.86),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tags
                  if (event.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SecHead('Tags'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in event.tags)
                                _Tag(label: tag, accent: accent),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Programme
                  if (hasProgramme)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SecHead('Programme'),
                          const SizedBox(height: 12),
                          _ProgrammeTimeline(
                            slots: event.schedule!,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),

                  // Speakers
                  if (hasSpeakers) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: _SecHead('Speakers'),
                    ),
                    const SizedBox(height: 12),
                    _SpeakersRow(speakers: event.speakers),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Sticky CTA ──────────────────────────────────────────────────
          if (showCta)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyCta(event: event, accent: accent),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final Event event;
  final Color accent;
  final bool isLive;
  final bool isPast;
  final bool saved;
  final bool isOwner;
  final VoidCallback onBack;
  final VoidCallback onToggleSaved;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _Hero({
    required this.event,
    required this.accent,
    required this.isLive,
    required this.isPast,
    required this.saved,
    required this.isOwner,
    required this.onBack,
    required this.onToggleSaved,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background;
    final hasImage = event.imagePath != null && event.imagePath!.isNotEmpty;
    final topInset = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 360,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo / gradient
          if (hasImage)
            Image.file(
              File(event.imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _GradientHero(color: accent),
            )
          else
            _GradientHero(color: accent),

          // Scrim — dark at top for buttons, fades into the page bg at bottom
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.24, 0.5, 0.86, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.transparent,
                      bg.withValues(alpha: 0.86),
                      bg,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Nav row
          Positioned(
            top: topInset + 8,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlassButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
                Row(
                  children: [
                    if (isOwner) ...[
                      _GlassButton(
                        icon: Icons.delete_outline_rounded,
                        onTap: onDelete,
                      ),
                      const SizedBox(width: 9),
                    ],
                    _GlassButton(
                      icon: saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      active: saved,
                      activeColor: accent,
                      onTap: onToggleSaved,
                    ),
                    const SizedBox(width: 9),
                    _GlassButton(icon: Icons.ios_share_rounded, onTap: onShare),
                  ],
                ),
              ],
            ),
          ),

          // Status pill + title
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusPill(isLive: isLive, isPast: isPast, accent: accent),
                const SizedBox(height: 11),
                Text(
                  event.title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.12,
                    shadows: const [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ],
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

class _StatusPill extends StatelessWidget {
  final bool isLive;
  final bool isPast;
  final Color accent;
  const _StatusPill({
    required this.isLive,
    required this.isPast,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFD43A3A),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _PulseDot(color: Colors.white),
            SizedBox(width: 6),
            Text(
              'HAPPENING NOW',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
    }
    final label = isPast ? 'PAST' : 'UPCOMING';
    final bg = isPast ? Colors.black.withValues(alpha: 0.55) : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;
  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? (activeColor ?? Colors.white)
                  : Colors.black.withValues(alpha: 0.42),
              border: Border.all(
                color: active
                    ? (activeColor ?? Colors.white)
                    : Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _GradientHero extends StatelessWidget {
  final Color color;
  const _GradientHero({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.4)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: _circle(180, 0.07),
          ),
          Positioned(bottom: 30, left: -30, child: _circle(120, 0.05)),
          Positioned(top: 80, left: 90, child: _circle(60, 0.04)),
        ],
      ),
    );
  }

  Widget _circle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Ticket-style date / time / location card (+ capacity)
// ─────────────────────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final Event event;
  final Color accent;
  final String countdown;
  final bool showCapacity;
  final int takenSeats;

  const _TicketCard({
    required this.event,
    required this.accent,
    required this.countdown,
    required this.showCapacity,
    required this.takenSeats,
  });

  static const _months = [
    '',
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  static const _wdays = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dt = event.dateTime;
    final bg = AppColors.background;
    final hairB = AppColors.divider.withValues(alpha: isDark ? 1 : 0.9);
    final timeStr =
        '${_two(dt.hour)}:${_two(dt.minute)} – '
        '${_two(event.endTime.hour)}:${_two(event.endTime.minute)}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        children: [
          // Date stub + info, with vertical tear + perforations
          Stack(
            clipBehavior: Clip.none,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Date block
                    SizedBox(
                      width: 90,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _months[dt.month],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${dt.day}',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: AppColors.text,
                                height: 1,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _wdays[dt.weekday],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Tear line
                    CustomPaint(
                      size: const Size(1, double.infinity),
                      painter: _DashedVLinePainter(color: hairB),
                    ),
                    // Time + location
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IconLine(
                              icon: Icons.schedule_rounded,
                              accent: accent,
                              title: timeStr,
                              subtitle: '$countdown · ${dt.year}',
                            ),
                            const SizedBox(height: 12),
                            _IconLine(
                              icon: Icons.place_outlined,
                              accent: accent,
                              title: event.location,
                              subtitle: null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Perforation notches on the tear line
              Positioned(left: 81, top: -9, child: _Notch(color: bg)),
              Positioned(left: 81, bottom: -9, child: _Notch(color: bg)),
            ],
          ),

          // Capacity
          if (showCapacity) ...[
            Divider(height: 1, color: AppColors.divider),
            _CapacityBar(
              taken: takenSeats,
              capacity: event.capacity!,
              accent: accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  const _IconLine({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: subtitle == null ? 13.5 : 15,
                  fontWeight: subtitle == null
                      ? FontWeight.w700
                      : FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Notch extends StatelessWidget {
  final Color color;
  const _Notch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DashedVLinePainter extends CustomPainter {
  final Color color;
  _DashedVLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const dash = 4.0, gap = 4.0;
    double y = 6;
    while (y < size.height - 6) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedVLinePainter old) => old.color != color;
}

class _CapacityBar extends StatelessWidget {
  final int taken;
  final int capacity;
  final Color accent;
  const _CapacityBar({
    required this.taken,
    required this.capacity,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (capacity == 0 ? 0 : (taken / capacity * 100))
        .clamp(0, 100)
        .round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.text.withValues(alpha: 0.8),
                  ),
                  children: [
                    TextSpan(
                      text: '$taken',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    TextSpan(text: ' of $capacity seats taken'),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '$pct% full',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: AppColors.divider.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Host card
// ─────────────────────────────────────────────────────────────────────────────

class _HostCard extends StatelessWidget {
  final Event event;
  final Color accent;
  final VoidCallback onView;
  const _HostCard({
    required this.event,
    required this.accent,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere(
      (c) => c.id == event.clubId,
      orElse: () => clubs.first,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          ClubAvatar(
            clubId: club.id,
            clubName: club.name,
            color: accent,
            size: 46,
            fontSize: 16,
            borderRadius: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HOSTED BY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(Icons.verified_rounded, size: 13, color: accent),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onView,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: AppColors.divider.withValues(alpha: 0.9),
                  width: 1.5,
                ),
              ),
              child: Text(
                'View',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Registration link card
// ─────────────────────────────────────────────────────────────────────────────

class _RegistrationCard extends StatelessWidget {
  final String url;
  final Color accent;
  const _RegistrationCard({required this.url, required this.accent});

  String get _pretty => url.replaceFirst(RegExp(r'^https?://'), '');

  Uri? _uri() {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final withScheme = trimmed.startsWith(RegExp(r'https?://'))
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) return null;
    return uri;
  }

  Future<void> _open(BuildContext context) async {
    final uri = _uri();
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text("Couldn't open the registration form"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.link_rounded, color: accent, size: 19),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Registration',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 12,
                        color: AppColors.secondaryText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Sign up on the club's form · $_pretty",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SecHead extends StatelessWidget {
  final String text;
  const _SecHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.secondaryText,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color accent;
  const _Tag({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Programme timeline
// ─────────────────────────────────────────────────────────────────────────────

class _ProgrammeTimeline extends StatelessWidget {
  final List<EventSlot> slots;
  final Color accent;
  const _ProgrammeTimeline({required this.slots, required this.accent});

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Stack(
        children: [
          // Vertical rail
          Positioned(
            left: 5,
            top: 10,
            bottom: 16,
            child: Container(width: 2, color: AppColors.divider),
          ),
          Column(
            children: [
              for (final slot in slots)
                _SlotRow(slot: slot, accent: accent, fmt: _fmt),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final EventSlot slot;
  final Color accent;
  final String Function(DateTime) fmt;
  const _SlotRow({required this.slot, required this.accent, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final key = slot.isHighlighted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot
          SizedBox(
            width: 12,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Center(
                child: Container(
                  width: key ? 12 : 9,
                  height: key ? 12 : 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: key ? accent : AppColors.background,
                    border: Border.all(
                      color: key
                          ? accent
                          : AppColors.divider.withValues(alpha: 0.9),
                      width: 2,
                    ),
                    boxShadow: key
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.13),
                              blurRadius: 0,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 40,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                fmt(slot.time),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: key ? accent : AppColors.secondaryText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: key ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
                if (slot.subtitle != null && slot.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    slot.subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.secondaryText,
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

// ─────────────────────────────────────────────────────────────────────────────
// Speakers row
// ─────────────────────────────────────────────────────────────────────────────

class _SpeakersRow extends StatelessWidget {
  final List<EventSpeaker> speakers;
  const _SpeakersRow({required this.speakers});

  static const List<int> _hues = [220, 300, 35, 155, 265, 10];

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return parts.take(2).map((w) => w[0].toUpperCase()).join();
  }

  Uri? _linkedinUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final withScheme = trimmed.startsWith(RegExp(r'https?://'))
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) return null;
    return uri;
  }

  Future<void> _openLinkedIn(BuildContext context, EventSpeaker s) async {
    final uri = _linkedinUri(s.linkedin ?? '');
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text("Couldn't open ${s.name}'s LinkedIn"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        itemCount: speakers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = speakers[i];
          final hue = _hues[i % _hues.length].toDouble();
          final avatarBg = HSLColor.fromAHSL(1, hue, 0.45, 0.9).toColor();
          final avatarFg = HSLColor.fromAHSL(1, hue, 0.5, 0.38).toColor();
          final hasLink = s.linkedin != null && s.linkedin!.trim().isNotEmpty;
          return GestureDetector(
            onTap: hasLink ? () => _openLinkedIn(context, s) : null,
            child: Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: avatarBg,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(s.name),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: avatarFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    s.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      height: 1.2,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (s.role.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      s.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky CTA — reminder bell + RSVP + add to calendar
// ─────────────────────────────────────────────────────────────────────────────

class _StickyCta extends StatefulWidget {
  final Event event;
  final Color accent;
  const _StickyCta({required this.event, required this.accent});

  @override
  State<_StickyCta> createState() => _StickyCtaState();
}

class _StickyCtaState extends State<_StickyCta> {
  bool _remind = false;

  void _toggleRemind() {
    setState(() => _remind = !_remind);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _remind
                ? "Reminder set — we'll alert you before it starts"
                : 'Reminder removed',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _remind ? widget.accent : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background;
    final accent = widget.accent;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.32],
          colors: [bg.withValues(alpha: 0.0), bg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _toggleRemind,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _remind
                            ? accent.withValues(alpha: 0.14)
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _remind
                              ? accent
                              : AppColors.divider.withValues(alpha: 0.9),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _remind
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: _remind ? accent : AppColors.text,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RsvpButton(
                      eventId: widget.event.id,
                      color: accent,
                      isPast: false,
                      event: widget.event,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              AddToCalendarButton(event: widget.event, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing dot (live status indicator)
// ─────────────────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Animation<double> _anim = Tween<double>(
    begin: 0.35,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
