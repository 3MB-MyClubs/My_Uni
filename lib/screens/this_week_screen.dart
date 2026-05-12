import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
import '../services/theme_service.dart';
import '../services/user_state.dart';
import '../widgets/rsvp_button.dart';
import 'campus_map_screen.dart';
import 'event_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

bool _isDateToday(DateTime dt) {
  final now = DateTime.now();
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

bool _isDateTomorrow(DateTime dt) {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  return dt.year == tomorrow.year &&
      dt.month == tomorrow.month &&
      dt.day == tomorrow.day;
}

bool _isLive(Event e) {
  final now = DateTime.now();
  return !e.dateTime.isAfter(now) && e.endTime.isAfter(now);
}

Color _clubColor(String clubId) {
  const colors = [
    Color(0xFFB41C18), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
    Color(0xFF558B2F), Color(0xFF283593), Color(0xFF6D4C41),
    Color(0xFF00695C), Color(0xFF4527A0), Color(0xFFC62828),
  ];
  final idx = clubs.indexWhere((c) => c.id == clubId);
  return colors[(idx < 0 ? 0 : idx) % colors.length];
}

String _fmt2(int n) => n.toString().padLeft(2, '0');
String _timeStr(DateTime dt) => '${_fmt2(dt.hour)}:${_fmt2(dt.minute)}';

const _kMonths = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class ThisWeekScreen extends StatefulWidget {
  const ThisWeekScreen({super.key});

  @override
  State<ThisWeekScreen> createState() => _ThisWeekScreenState();
}

class _ThisWeekScreenState extends State<ThisWeekScreen> {
  int _dayIdx = 0;
  bool _followedOnly = false;
  late List<DateTime> _weekDays;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

    // Seed RSVP store for all non-past events
    for (final e in events.where((e) => e.endTime.isAfter(now))) {
      rsvpStore.seed(e.id, e.attendeeUserIds.contains(userId));
    }

    // Build this week: Monday → Sunday
    final monday = today.subtract(Duration(days: today.weekday - 1));
    _weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));

    // Select today's pill
    final todayIdx = _weekDays.indexWhere((d) => d == today);
    _dayIdx = todayIdx >= 0 ? todayIdx : 0;
  }

  List<Event> _eventsForDay(DateTime day, {bool applyFilter = true}) {
    final followed = userState.followedClubIds;
    return events
        .where((e) {
          final d =
              DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
          if (d != day) return false;
          if (applyFilter && _followedOnly &&
              !followed.contains(e.clubId)) {
            return false;
          }
          return true;
        })
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  String _pillLabel(DateTime day) {
    if (_isDateToday(day)) return 'Today';
    if (_isDateTomorrow(day)) return 'Tmrw';
    const abbr = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return abbr[day.weekday];
  }

  ({String text, Color color}) _countdown(Event e, DateTime selectedDay) {
    final now = DateTime.now();
    if (_isDateToday(selectedDay)) {
      if (_isLive(e)) {
        return (text: 'Now', color: const Color(0xFFEF5350));
      }
      final diff = e.dateTime.difference(now);
      if (diff.isNegative || diff.inSeconds <= 0) {
        return (text: 'Now', color: const Color(0xFFEF5350));
      }
      final mins = diff.inMinutes;
      final hrs = mins ~/ 60;
      final rem = mins % 60;
      if (hrs > 0) {
        return (text: '${hrs}h ${rem}m', color: AppColors.secondaryText);
      }
      return (text: '${mins}m', color: AppColors.primaryRed);
    }
    const ls = ['today', 'tmrw', '2d', '3d', '4d', '5d', '6d'];
    final today = DateTime(now.year, now.month, now.day);
    final daysFromToday = selectedDay.difference(today).inDays.clamp(0, 6);
    return (text: ls[daysFromToday], color: AppColors.secondaryText);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totalEvents =
        events.where((e) => e.endTime.isAfter(now)).length;
    final selectedDay = _weekDays[_dayIdx];
    final dayEvents = _eventsForDay(selectedDay);

    // Week range label: "May 11 – 17" or "Apr 28 – May 4"
    final ws = _weekDays.first;
    final we = _weekDays.last;
    final weekLabel = ws.month == we.month
        ? '${_kMonths[ws.month]} ${ws.day} – ${we.day}'
        : '${_kMonths[ws.month]} ${ws.day} – ${_kMonths[we.month]} ${we.day}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, MediaQuery.of(context).padding.top + 14, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weekLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'This Week',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                              letterSpacing: -1,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '$totalEvents events',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Day pills
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_weekDays.length, (i) {
                        final day = _weekDays[i];
                        final active = i == _dayIdx;
                        final hasEv = _eventsForDay(day).isNotEmpty;
                        return Padding(
                          padding: EdgeInsets.only(
                              right: i < _weekDays.length - 1 ? 6 : 0),
                          child: GestureDetector(
                            onTap: () => setState(() => _dayIdx = i),
                            child: AnimatedOpacity(
                              opacity: (!hasEv && !active) ? 0.4 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.primaryRed
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: active
                                        ? AppColors.primaryRed
                                        : AppColors.divider,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _pillLabel(day),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: active
                                            ? Colors.white
                                            : AppColors.secondaryText,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: active
                                            ? Colors.white
                                                .withValues(alpha: 0.65)
                                            : hasEv
                                                ? AppColors.primaryRed
                                                : Colors.transparent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),

              // Filter pills: All / Following
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'All',
                        icon: Icons.apps_rounded,
                        active: !_followedOnly,
                        onTap: () => setState(() => _followedOnly = false),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Following',
                        icon: Icons.favorite_rounded,
                        active: _followedOnly,
                        onTap: () => setState(() => _followedOnly = true),
                      ),
                    ],
                  ),
                ),
              ),

              // Day label + divider
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        _pillLabel(selectedDay).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondaryText,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Divider(
                            color: AppColors.divider, height: 1),
                      ),
                      if (dayEvents.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          '${dayEvents.length} event${dayEvents.length > 1 ? 's' : ''}',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryText),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Empty state or event list
              if (dayEvents.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 52, horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            size: 22,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Nothing here',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _followedOnly
                              ? 'No events from clubs you follow.'
                              : 'No events scheduled for this day.',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final e = dayEvents[i];
                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: i < dayEvents.length - 1 ? 8 : 0),
                          child: _EventRow(
                            event: e,
                            color: _clubColor(e.clubId),
                            countdown: _countdown(e, selectedDay),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventDetailScreen(
                                  event: e,
                                  color: _clubColor(e.clubId),
                                ),
                              ),
                            ).then((_) => setState(() {})),
                          ),
                        );
                      },
                      childCount: dayEvents.length,
                    ),
                  ),
                ),
            ],
          ),
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event row widget
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Filter pill
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryRed : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primaryRed : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? Colors.white : AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event row widget
// ─────────────────────────────────────────────────────────────────────────────

class _EventRow extends StatelessWidget {
  final Event event;
  final Color color;
  final ({String text, Color color}) countdown;
  final VoidCallback onTap;

  const _EventRow({
    required this.event,
    required this.color,
    required this.countdown,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == event.clubId,
        orElse: () => clubs.first);
    final live = _isLive(event);
    final timeRange =
        '${_timeStr(event.dateTime)} – ${_timeStr(event.endTime)}';
    final isDark = themeService.isDark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: live
              ? color.withValues(alpha: isDark ? 0x18 / 255.0 : 0x12 / 255.0)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: live
                ? color.withValues(
                    alpha: isDark ? 0x55 / 255.0 : 0x44 / 255.0)
                : AppColors.divider,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left color bar
            Container(
              width: 3,
              height: 52,
              margin: const EdgeInsets.only(left: 14, right: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    club.name,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    timeRange,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Right: countdown chip + chevron
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: live
                          ? const Color(0xFFEF5350).withValues(alpha: 0.12)
                          : color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      countdown.text,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: live
                            ? const Color(0xFFEF5350)
                            : countdown.color,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(Icons.chevron_right_rounded,
                      size: 14, color: AppColors.secondaryText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _WeekEventDetail extends StatefulWidget {
  final Event event;
  final Color color;
  final DateTime selectedDay;
  final VoidCallback onBack;

  const _WeekEventDetail({
    super.key,
    required this.event,
    required this.color,
    required this.selectedDay,
    required this.onBack,
  });

  @override
  State<_WeekEventDetail> createState() => _WeekEventDetailState();
}

class _WeekEventDetailState extends State<_WeekEventDetail> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  void _back() {
    setState(() => _visible = false);
    Future.delayed(const Duration(milliseconds: 260), widget.onBack);
  }

  ({String text, Color color}) _countdown() {
    final now = DateTime.now();
    final e = widget.event;
    final col = widget.color;
    if (_isDateToday(widget.selectedDay)) {
      if (_isLive(e)) {
        return (text: 'Happening now', color: const Color(0xFFEF5350));
      }
      final diff = e.dateTime.difference(now);
      if (diff.isNegative || diff.inSeconds <= 0) {
        return (text: 'Happening now', color: const Color(0xFFEF5350));
      }
      final mins = diff.inMinutes;
      final hrs = mins ~/ 60;
      final rem = mins % 60;
      if (hrs > 0) return (text: 'Starts in ${hrs}h ${rem}m', color: col);
      return (text: 'Starts in ${mins}m', color: col);
    }
    const ls = [
      'today', 'tomorrow', 'in 2 days', 'in 3 days',
      'in 4 days', 'in 5 days', 'in 6 days'
    ];
    final today = DateTime(now.year, now.month, now.day);
    final daysFromToday =
        widget.selectedDay.difference(today).inDays.clamp(0, 6);
    return (text: 'Starts ${ls[daysFromToday]}', color: AppColors.secondaryText);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final col = widget.color;
    final live = _isLive(e);
    final club =
        clubs.firstWhere((c) => c.id == e.clubId, orElse: () => clubs.first);
    final cd = _countdown();

    const weekdays = [
      '', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    final dateStr =
        '${weekdays[e.dateTime.weekday]}, ${_kMonths[e.dateTime.month]} ${e.dateTime.day}';
    final timeStr = '${_timeStr(e.dateTime)} – ${_timeStr(e.endTime)}';
    final attendingCount = e.attendeeUserIds.toSet().length;

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(1, 0),
      duration: const Duration(milliseconds: 260),
      curve: const Cubic(0.4, 0.0, 0.2, 1.0),
      child: Material(
        color: AppColors.background,
        child: Stack(
          children: [
            // Top bar + scrollable body
            Column(
              children: [
                // Top bar
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _back,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Icon(Icons.chevron_left_rounded,
                                size: 22,
                                color: AppColors.secondaryText),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Event',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        if (live) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF5350)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PulseDot(
                                    color: const Color(0xFFEF5350)),
                                const SizedBox(width: 5),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFEF5350),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Club badge
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
                          decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: col.withValues(alpha: 0.18)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: col,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  club.name.isNotEmpty
                                      ? club.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                club.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: col,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title
                        Text(
                          e.title,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                            letterSpacing: -0.8,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Countdown chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: live
                                ? const Color(0xFFEF5350)
                                    .withValues(alpha: 0.10)
                                : col.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: live
                                  ? const Color(0xFFEF5350)
                                      .withValues(alpha: 0.30)
                                  : col.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (live) ...[
                                _PulseDot(
                                    color: const Color(0xFFEF5350)),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                cd.text,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: cd.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Details card
                        _DetailCard(
                          title: 'Details',
                          child: Column(
                            children: [
                              _DetailRow(
                                icon: Icons.calendar_today_rounded,
                                label: 'Date & time',
                                value: '$dateStr · $timeStr',
                              ),
                              Divider(
                                  color: AppColors.divider,
                                  height: 24,
                                  thickness: 1),
                              _DetailRow(
                                icon: Icons.location_on_outlined,
                                label: 'Location',
                                value: e.location,
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CampusMapScreen(),
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: col.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.map_outlined,
                                          color: col, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'View on Campus Map',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: col,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.arrow_forward_ios_rounded,
                                          size: 12,
                                          color: col.withValues(alpha: 0.6)),
                                    ],
                                  ),
                                ),
                              ),
                              Divider(
                                  color: AppColors.divider,
                                  height: 24,
                                  thickness: 1),
                              _DetailRow(
                                icon: Icons.people_outline_rounded,
                                label: 'Attending',
                                value:
                                    '$attendingCount ${attendingCount == 1 ? 'person' : 'people'} going',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // About card
                        _DetailCard(
                          title: 'About this event',
                          child: Text(
                            e.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.secondaryText,
                              height: 1.65,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Organised by card
                        _DetailCard(
                          title: 'Organised by',
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: col.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: col.withValues(alpha: 0.20),
                                      width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  club.name.isNotEmpty
                                      ? club.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: col,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  club.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // RSVP section
                        Text(
                          'RSVP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondaryText,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        RsvpButton(eventId: e.id, color: col),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail card
// ─────────────────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryText,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail row (icon + label + value)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(icon, size: 17, color: AppColors.secondaryText),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryText,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing dot for live indicator
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
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
