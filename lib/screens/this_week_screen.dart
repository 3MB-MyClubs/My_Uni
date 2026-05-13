import 'dart:io';
import 'package:flutter/foundation.dart';
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
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
    Color(0xFF558B2F),
    Color(0xFF283593),
    Color(0xFF6D4C41),
    Color(0xFF00695C),
    Color(0xFF4527A0),
    Color(0xFFC62828),
  ];
  final idx = clubs.indexWhere((c) => c.id == clubId);
  return colors[(idx < 0 ? 0 : idx) % colors.length];
}

String _fmt2(int n) => n.toString().padLeft(2, '0');
String _timeStr(DateTime dt) => '${_fmt2(dt.hour)}:${_fmt2(dt.minute)}';

const _kMonths = [
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

const _kWeekdays = [
  '',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
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
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDay = today;
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

    for (final e in events.where((e) => e.endTime.isAfter(now))) {
      rsvpStore.seed(e.id, e.attendeeUserIds.contains(userId));
    }
  }

  static DateTime _startOfDay(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  DateTime get _today => _startOfDay(DateTime.now());

  List<DateTime> get _visibleDays {
    final today = _today;
    return List.generate(7, (i) => today.add(Duration(days: i)));
  }

  void _syncSelectedDayToRollingWindow() {
    final today = _today;
    if (_selectedDay.isBefore(today)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedDay = today);
        }
      });
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _selectDay(DateTime day) {
    final value = _startOfDay(day);
    if (_sameDay(value, _selectedDay)) return;
    setState(() => _selectedDay = value);
  }

  void _shiftSelectedDay(int delta) {
    final days = _visibleDays;
    final idx = days.indexWhere((d) => _sameDay(d, _selectedDay));
    final base = idx < 0 ? 0 : idx;
    final next = (base + delta).clamp(0, days.length - 1);
    _selectDay(days[next]);
  }

  List<Event> _eventsForDay(DateTime day) {
    final followed = userState.followedClubIds;
    return events.where((e) {
      final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      if (!_sameDay(d, day)) return false;
      if (_followedOnly && !followed.contains(e.clubId)) return false;
      return true;
    }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<Event> _selectedEvents() => _eventsForDay(_selectedDay);

  int _selectedAttendeeCount(List<Event> selectedEvents) {
    return selectedEvents.fold<int>(
      0,
      (sum, event) => sum + event.attendeeUserIds.length,
    );
  }

  List<Event> _rsvpedEventsForDay(DateTime day) {
    return _eventsForDay(
      day,
    ).where((event) => rsvpStore.isAttending(event.id)).toList();
  }

  Map<String, int> _activityByLocation(List<Event> selectedEvents) {
    final buckets = <String, int>{};
    for (final event in selectedEvents) {
      final location = event.location.trim().isEmpty
          ? 'Campus'
          : event.location.trim();
      buckets[location] =
          (buckets[location] ?? 0) + event.attendeeUserIds.length + 1;
    }
    return Map.fromEntries(
      buckets.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncSelectedDayToRollingWindow();
    final topPad = MediaQuery.of(context).padding.top;
    final days = _visibleDays;
    final selectedEvents = _selectedEvents();
    final dayCounts = {for (final day in days) day: _eventsForDay(day).length};
    final isEmpty = selectedEvents.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -240) {
            _shiftSelectedDay(1);
          } else if (velocity > 240) {
            _shiftSelectedDay(-1);
          }
        },
        child: CustomScrollView(
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
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                        letterSpacing: -0.9,
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

            SliverPersistentHeader(
              pinned: true,
              delegate: _CalendarHeaderDelegate(
                days: days,
                selectedDay: _selectedDay,
                eventCounts: dayCounts,
                onSelect: _selectDay,
              ),
            ),

            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.03, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _DayOverview(
                  key: ValueKey(
                    '${_selectedDay.toIso8601String()}$_followedOnly',
                  ),
                  selectedDay: _selectedDay,
                  eventCount: selectedEvents.length,
                  attendeeCount: _selectedAttendeeCount(selectedEvents),
                  activityByLocation: _activityByLocation(selectedEvents),
                  rsvpsBuilder: () => _rsvpedEventsForDay(_selectedDay),
                  onOpenMap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CampusMapScreen(initialSelectedDay: _selectedDay),
                    ),
                  ),
                ),
              ),
            ),

            if (!isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, i) {
                    final ev = selectedEvents[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i < selectedEvents.length - 1 ? 10 : 0,
                      ),
                      child: _EventCardFull(
                        key: ValueKey(ev.id),
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
                  }, childCount: selectedEvents.length),
                ),
              ),

            if (isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyDayState(
                  selectedDay: _selectedDay,
                  followedOnly: _followedOnly,
                  onShowAll: _followedOnly
                      ? () => setState(() => _followedOnly = false)
                      : null,
                ),
              ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 80,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayOverview extends StatelessWidget {
  final DateTime selectedDay;
  final int eventCount;
  final int attendeeCount;
  final Map<String, int> activityByLocation;
  final List<Event> Function() rsvpsBuilder;
  final VoidCallback onOpenMap;

  const _DayOverview({
    super.key,
    required this.selectedDay,
    required this.eventCount,
    required this.attendeeCount,
    required this.activityByLocation,
    required this.rsvpsBuilder,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = _isDateToday(selectedDay)
        ? 'Today'
        : _isDateTomorrow(selectedDay)
        ? 'Tomorrow'
        : '${_kWeekdays[selectedDay.weekday]}, ${_kMonths[selectedDay.month]} ${selectedDay.day}';
    final peak = activityByLocation.values.isEmpty
        ? 1
        : activityByLocation.values.reduce((a, b) => a > b ? a : b);
    final locationEntries = activityByLocation.entries.take(4).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$eventCount event${eventCount == 1 ? '' : 's'} · $attendeeCount students going',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onOpenMap,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: AppColors.primaryRed.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 16,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Heat map',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (locationEntries.isEmpty)
                  _QuietActivityState()
                else
                  Column(
                    children: locationEntries
                        .map(
                          (entry) => _ActivityBar(
                            label: entry.key,
                            value: entry.value,
                            maxValue: peak,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: rsvpStore,
            builder: (context, _) {
              final rsvps = rsvpsBuilder();
              if (rsvps.isEmpty) return const SizedBox.shrink();
              return _RsvpStrip(events: rsvps);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky calendar navigation
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<DateTime> days;
  final DateTime selectedDay;
  final Map<DateTime, int> eventCounts;
  final ValueChanged<DateTime> onSelect;

  const _CalendarHeaderDelegate({
    required this.days,
    required this.selectedDay,
    required this.eventCounts,
    required this.onSelect,
  });

  static const double _height = 92.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_CalendarHeaderDelegate old) {
    return old.selectedDay != selectedDay ||
        old.days != days ||
        old.eventCounts != eventCounts;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final elevation = (shrinkOffset / 20).clamp(0.0, 1.0);
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.7)),
        ),
        boxShadow: [
          if (overlapsContent || elevation > 0)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05 * elevation),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: _HorizontalDateSelector(
        days: days,
        selectedDay: selectedDay,
        eventCounts: eventCounts,
        onSelect: onSelect,
      ),
    );
  }
}

class _HorizontalDateSelector extends StatelessWidget {
  final List<DateTime> days;
  final DateTime selectedDay;
  final Map<DateTime, int> eventCounts;
  final ValueChanged<DateTime> onSelect;

  const _HorizontalDateSelector({
    required this.days,
    required this.selectedDay,
    required this.eventCounts,
    required this.onSelect,
  });

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final day = days[index];
        return _DateChip(
          day: day,
          selected: _sameDay(day, selectedDay),
          isToday: _isDateToday(day),
          eventCount: eventCounts[day] ?? 0,
          onTap: () => onSelect(day),
        );
      },
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final bool isToday;
  final int eventCount;
  final VoidCallback onTap;

  const _DateChip({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.eventCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = isToday
        ? 'Today'
        : _isDateTomorrow(day)
        ? 'Tmrw'
        : _kWeekdays[day.weekday].substring(0, 3);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryRed : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primaryRed
                : isToday
                ? AppColors.primaryRed.withValues(alpha: 0.36)
                : AppColors.divider,
            width: isToday || selected ? 1.5 : 1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.20),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white70 : AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              day.day.toString(),
              style: TextStyle(
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
                color: selected ? Colors.white : AppColors.text,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 5,
              width: eventCount > 0 ? 18 : 5,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(
                        alpha: eventCount > 0 ? 0.95 : 0.36,
                      )
                    : eventCount > 0
                    ? AppColors.primaryRed
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selected day overview
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;

  const _ActivityBar({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final percent = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: percent),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryRed.withValues(alpha: 0.86),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietActivityState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.nights_stay_outlined,
            size: 16,
            color: AppColors.secondaryText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Campus looks quiet on this day.',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpStrip extends StatelessWidget {
  final List<Event> events;

  const _RsvpStrip({required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 15,
                color: AppColors.primaryRed,
              ),
              const SizedBox(width: 6),
              Text(
                'Your RSVPs',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final event = events[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primaryRed.withValues(alpha: 0.18),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${_timeStr(event.dateTime)} · ${event.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryRed,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDayState extends StatelessWidget {
  final DateTime selectedDay;
  final bool followedOnly;
  final VoidCallback? onShowAll;

  const _EmptyDayState({
    required this.selectedDay,
    required this.followedOnly,
    this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final label = _isDateToday(selectedDay)
        ? 'today'
        : '${_kMonths[selectedDay.month]} ${selectedDay.day}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.event_available_outlined,
                size: 32,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No events on $label',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              followedOnly
                  ? 'Try all clubs or swipe to another day.'
                  : 'Swipe across the calendar to discover another campus moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                height: 1.4,
              ),
            ),
            if (onShowAll != null) ...[
              const SizedBox(height: 18),
              TextButton(
                onPressed: onShowAll,
                child: Text(
                  'Show all clubs',
                  style: TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w800,
                  ),
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
// Full event card
// ─────────────────────────────────────────────────────────────────────────────

class _EventCardFull extends StatelessWidget {
  final Event event;
  final Color color;
  final VoidCallback onTap;

  const _EventCardFull({
    super.key,
    required this.event,
    required this.color,
    required this.onTap,
  });

  Widget _fallbackPhoto() {
    return Container(
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
    );
  }

  Widget _eventPhoto(String path) {
    final isRemote = path.startsWith('http') || path.startsWith('blob:');
    if (kIsWeb || isRemote) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackPhoto(),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _fallbackPhoto(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere(
      (c) => c.id == event.clubId,
      orElse: () => clubs.first,
    );
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
                    _eventPhoto(event.imagePath!)
                  else
                    _fallbackPhoto(),
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
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 11,
                                  color: AppColors.secondaryText,
                                ),
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
                                Icon(
                                  Icons.people_outline,
                                  size: 11,
                                  color: AppColors.secondaryText,
                                ),
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
            color: attending ? AppColors.divider : AppColors.primaryRed,
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
                  color: attending ? AppColors.secondaryText : Colors.white,
                ),
              )
            else ...[
              if (attending) ...[
                Icon(
                  Icons.check_rounded,
                  size: 11,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                attending ? 'Going' : 'RSVP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: attending ? AppColors.secondaryText : Colors.white,
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
                color: AppColors.primaryRed.withValues(alpha: _anim.value),
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

  const _SegTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

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
      'today',
      'tomorrow',
      'in 2 days',
      'in 3 days',
      'in 4 days',
      'in 5 days',
      'in 6 days',
    ];
    final today = DateTime(now.year, now.month, now.day);
    final daysFromToday = widget.selectedDay
        .difference(today)
        .inDays
        .clamp(0, 6);
    return (
      text: 'Starts ${ls[daysFromToday]}',
      color: AppColors.secondaryText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final col = widget.color;
    final live = _isLive(e);
    final club = clubs.firstWhere(
      (c) => c.id == e.clubId,
      orElse: () => clubs.first,
    );
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
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 22,
                          color: AppColors.secondaryText,
                        ),
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
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFEF5350,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PulseDot(color: const Color(0xFFEF5350)),
                            const SizedBox(width: 5),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEF5350),
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
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.of(context).padding.bottom + 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: col.withValues(alpha: 0.18)),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: live
                            ? const Color(0xFFEF5350).withValues(alpha: 0.10)
                            : col.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: live
                              ? const Color(0xFFEF5350).withValues(alpha: 0.30)
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
                            thickness: 1,
                          ),
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
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: col.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: col.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    color: col,
                                    size: 16,
                                  ),
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
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 12,
                                    color: col.withValues(alpha: 0.6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(
                            color: AppColors.divider,
                            height: 24,
                            thickness: 1,
                          ),
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
                                width: 1.5,
                              ),
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
