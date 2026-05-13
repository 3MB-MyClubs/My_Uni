import 'dart:io';
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
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
  final t = DateTime.now().add(const Duration(days: 1));
  return dt.year == t.year && dt.month == t.month && dt.day == t.day;
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

const _kWeekdays = [
  '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

// ─────────────────────────────────────────────────────────────────────────────
// Main screen  —  Variant C: Agenda Scroll + All / Following filter
// ─────────────────────────────────────────────────────────────────────────────

class ThisWeekScreen extends StatefulWidget {
  const ThisWeekScreen({super.key});

  @override
  State<ThisWeekScreen> createState() => _ThisWeekScreenState();
}

class _ThisWeekScreenState extends State<ThisWeekScreen> {
  bool _followedOnly = false;
  late List<DateTime> _weekDays;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

    for (final e in events.where((e) => e.endTime.isAfter(now))) {
      rsvpStore.seed(e.id, e.attendeeUserIds.contains(userId));
    }

    // Monday → Sunday of the current week
    final monday = today.subtract(Duration(days: today.weekday - 1));
    _weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  List<Event> _eventsForDay(DateTime day) {
    final followed = userState.followedClubIds;
    return events
        .where((e) {
          final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
          if (d != day) return false;
          if (_followedOnly && !followed.contains(e.clubId)) return false;
          return true;
        })
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // Build the per-day sliver pairs and collect them into a flat list.
  List<Widget> _buildAgendaSlivers(BuildContext context) {
    final slivers = <Widget>[];

    for (final day in _weekDays) {
      final dayEvts = _eventsForDay(day);
      if (dayEvts.isEmpty) continue;

      final isToday = _isDateToday(day);
      final dayLabel = isToday
          ? 'Today'
          : _isDateTomorrow(day)
              ? 'Tomorrow'
              : _kWeekdays[day.weekday];
      final dateLabel = isToday
          ? '${_kMonths[day.month]} ${day.day} · this week'
          : '${_kMonths[day.month]} ${day.day}';

      // Sticky day header
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _DayHeaderDelegate(
            dateNum: day.day,
            dayLabel: dayLabel,
            dateLabel: dateLabel,
            isToday: isToday,
            eventCount: dayEvts.length,
          ),
        ),
      );

      // Event cards
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final ev = dayEvts[i];
                return Padding(
                  padding:
                      EdgeInsets.only(bottom: i < dayEvts.length - 1 ? 10 : 0),
                  child: _EventCardFull(
                    event: ev,
                    color: _clubColor(ev.clubId),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailScreen(
                          event: ev,
                          color: _clubColor(ev.clubId),
                        ),
                      ),
                    ).then((_) => setState(() {})),
                  ),
                );
              },
              childCount: dayEvts.length,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final agendaSlivers = _buildAgendaSlivers(context);
    final isEmpty = agendaSlivers.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, topPad + 14, 16, 8),
              child: Row(
                children: [
                  Text(
                    'This Week',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const Spacer(),
                  _HeaderIconBtn(icon: Icons.search_rounded),
                  const SizedBox(width: 6),
                  _HeaderIconBtn(icon: Icons.notifications_outlined),
                ],
              ),
            ),
          ),

          // ── All Clubs / Following toggle ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Container(
                height: 42,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    _SegTab(
                      label: 'All Clubs',
                      active: !_followedOnly,
                      onTap: () => setState(() => _followedOnly = false),
                    ),
                    _SegTab(
                      label: 'Following',
                      active: _followedOnly,
                      onTap: () => setState(() => _followedOnly = true),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Agenda (day header + cards per day) ───────────────────────
          if (!isEmpty) ...agendaSlivers,

          // ── Empty state ────────────────────────────────────────────────
          if (isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Icon(Icons.calendar_today_rounded,
                          size: 24, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No events this week',
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
                          : 'Nothing scheduled this week.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 80),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky day header delegate
// ─────────────────────────────────────────────────────────────────────────────

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int dateNum;
  final String dayLabel;
  final String dateLabel;
  final bool isToday;
  final int eventCount;

  const _DayHeaderDelegate({
    required this.dateNum,
    required this.dayLabel,
    required this.dateLabel,
    required this.isToday,
    required this.eventCount,
  });

  static const double _h = 52.0;

  @override
  double get minExtent => _h;
  @override
  double get maxExtent => _h;

  @override
  bool shouldRebuild(_DayHeaderDelegate old) =>
      old.dateNum != dateNum ||
      old.isToday != isToday ||
      old.eventCount != eventCount;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: _h,
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primaryRed.withValues(alpha: 0.10)
            : AppColors.background,
        border: Border(
          top: BorderSide(
            color: isToday
                ? AppColors.primaryRed.withValues(alpha: 0.44)
                : AppColors.divider,
          ),
          bottom: BorderSide(
            color: isToday
                ? AppColors.primaryRed.withValues(alpha: 0.28)
                : AppColors.divider,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          // Date badge
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isToday ? AppColors.primaryRed : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              dateNum.toString(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isToday ? Colors.white : AppColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Day name + date string
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isToday ? AppColors.text : AppColors.secondaryText,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          // Event count
          Text(
            '$eventCount event${eventCount > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full event card
// ─────────────────────────────────────────────────────────────────────────────

class _EventCardFull extends StatelessWidget {
  final Event event;
  final Color color;
  final VoidCallback onTap;

  const _EventCardFull({
    required this.event,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final club =
        clubs.firstWhere((c) => c.id == event.clubId, orElse: () => clubs.first);
    final live = _isLive(event);
    final timeStr = _timeStr(event.dateTime);
    final attendees = event.attendeeUserIds.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: live
                ? AppColors.primaryRed.withValues(alpha: 0.55)
                : AppColors.divider,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo / color area (152 px) ──────────────────────────────
            SizedBox(
              height: 152,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Event photo if available, otherwise club-colour gradient
                  if (event.imagePath != null && event.imagePath!.isNotEmpty)
                    Image.file(
                      File(event.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, err, stack) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: 0.60),
                              color.withValues(alpha: 0.28),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.60),
                            color.withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                  // Bottom-up dark gradient for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0.0, 0.52, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Club pill — top-left
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 17,
                            height: 17,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              club.name.isNotEmpty
                                  ? club.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            club.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Time + LIVE pip — bottom
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                            height: 1,
                          ),
                        ),
                        const Spacer(),
                        if (live) const _LivePip(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Info area ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -0.4,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 9),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 11,
                                    color: AppColors.secondaryText),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.location,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.secondaryText,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.people_outline,
                                    size: 11,
                                    color: AppColors.secondaryText),
                                const SizedBox(width: 4),
                                Text(
                                  '$attendees going',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ListenableBuilder(
                        listenable: rsvpStore,
                        builder: (ctx, _) => _InlineRsvpBtn(
                          eventId: event.id,
                          isPast: event.endTime.isBefore(DateTime.now()),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline RSVP button
// ─────────────────────────────────────────────────────────────────────────────

class _InlineRsvpBtn extends StatelessWidget {
  final String eventId;
  final bool isPast;

  const _InlineRsvpBtn({required this.eventId, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final attending = rsvpStore.isAttending(eventId);
    final pending = rsvpStore.isPending(eventId);

    return GestureDetector(
      onTap: isPast || pending || userId.isEmpty
          ? null
          : () => rsvpStore.toggle(eventId, userId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: attending ? Colors.transparent : AppColors.primaryRed,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: attending
                ? AppColors.divider
                : AppColors.primaryRed,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pending)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color:
                      attending ? AppColors.secondaryText : Colors.white,
                ),
              )
            else ...[
              if (attending) ...[
                Icon(Icons.check_rounded,
                    size: 11, color: AppColors.secondaryText),
                const SizedBox(width: 4),
              ],
              Text(
                attending ? 'Going' : 'RSVP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      attending ? AppColors.secondaryText : Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live pip (pulsing dot + LIVE label)
// ─────────────────────────────────────────────────────────────────────────────

class _LivePip extends StatefulWidget {
  const _LivePip();

  @override
  State<_LivePip> createState() => _LivePipState();
}

class _LivePipState extends State<_LivePip>
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
      builder: (ctx, child) => Container(
        padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
        decoration: BoxDecoration(
          color: AppColors.primaryRed.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color:
                    AppColors.primaryRed.withValues(alpha: _anim.value),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'LIVE',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryRed,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header icon button
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;

  const _HeaderIconBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Icon(icon, size: 17, color: AppColors.secondaryText),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented toggle tab
// ─────────────────────────────────────────────────────────────────────────────

class _SegTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SegTab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: double.infinity,
          decoration: BoxDecoration(
            color: active ? AppColors.primaryRed : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: active ? Colors.white : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WeekEventDetail — kept for any internal navigation
// ─────────────────────────────────────────────────────────────────────────────

class _WeekEventDetail extends StatefulWidget {
  final Event event;
  final Color color;
  final DateTime selectedDay;
  final VoidCallback onBack;

  const _WeekEventDetail({
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
    return (
      text: 'Starts ${ls[daysFromToday]}',
      color: AppColors.secondaryText
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final col = widget.color;
    final live = _isLive(e);
    final club =
        clubs.firstWhere((c) => c.id == e.clubId, orElse: () => clubs.first);
    final cd = _countdown();
    final dateStr =
        '${_kWeekdays[e.dateTime.weekday]}, ${_kMonths[e.dateTime.month]} ${e.dateTime.day}';
    final timeStr = '${_timeStr(e.dateTime)} – ${_timeStr(e.endTime)}';
    final attendingCount = e.attendeeUserIds.toSet().length;

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(1, 0),
      duration: const Duration(milliseconds: 260),
      curve: const Cubic(0.4, 0.0, 0.2, 1.0),
      child: Material(
        color: AppColors.background,
        child: Column(
          children: [
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
                            size: 22, color: AppColors.secondaryText),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Event',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText)),
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
                            _PulseDot(color: const Color(0xFFEF5350)),
                            const SizedBox(width: 5),
                            const Text('LIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFEF5350),
                                  letterSpacing: 0.5,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.of(context).padding.bottom + 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: col.withValues(alpha: 0.18)),
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
                          Text(club.name,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: col)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(e.title,
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                            letterSpacing: -0.8,
                            height: 1.15)),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: live
                            ? const Color(0xFFEF5350).withValues(alpha: 0.10)
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
                            _PulseDot(color: const Color(0xFFEF5350)),
                            const SizedBox(width: 6),
                          ],
                          Text(cd.text,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: cd.color)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
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
                                  builder: (_) => const CampusMapScreen()),
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
                                  Text('View on Campus Map',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: col)),
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
                                  color: col),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(club.name,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('RSVP',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondaryText,
                            letterSpacing: 1.0)),
                    const SizedBox(height: 10),
                    RsvpButton(eventId: e.id, color: col),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail card / row widgets
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
                letterSpacing: 1.0),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

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
              Text(label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryText,
                      letterSpacing: 1.0)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing dot
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
      builder: (ctx, child) => Container(
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
