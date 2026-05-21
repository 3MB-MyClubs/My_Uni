import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/calendar_sync_service.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
import 'event_detail_screen.dart';

class PersonalCalendarScreen extends StatefulWidget {
  const PersonalCalendarScreen({super.key});

  @override
  State<PersonalCalendarScreen> createState() => _PersonalCalendarScreenState();
}

class _PersonalCalendarScreenState extends State<PersonalCalendarScreen> {
  late DateTime _selectedDay;

  String get _userId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  @override
  void initState() {
    super.initState();
    _selectedDay = _startOfDay(DateTime.now());
    if (_userId.isNotEmpty) rsvpStore.seedAll(events, _userId);
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DateTime> get _visibleDays {
    final today = _startOfDay(DateTime.now());
    return List.generate(14, (index) => today.add(Duration(days: index)));
  }

  List<Event> _personalEvents() {
    final userId = _userId;
    if (userId.isEmpty) return [];
    final now = DateTime.now();
    return events.where((event) {
      final attending =
          rsvpStore.isAttending(event.id) ||
          event.attendeeUserIds.contains(userId);
      return attending && event.endTime.isAfter(now);
    }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<Event> _eventsForDay(DateTime day, List<Event> source) {
    return source.where((event) => _sameDay(event.dateTime, day)).toList();
  }

  int _syncedCount(List<Event> source) {
    final userId = _userId;
    if (userId.isEmpty) return 0;
    return source
        .where((event) => calendarSyncService.isSynced(userId, event.id))
        .length;
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
    ];
    final idx = clubs.indexWhere((club) => club.id == clubId);
    return colors[(idx < 0 ? 0 : idx) % colors.length];
  }

  Future<void> _syncEvent(Event event) async {
    final synced = await calendarSyncService.addToDeviceCalendar(
      event,
      _userId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Added to your phone calendar.'
              : 'Could not open your phone calendar.',
        ),
      ),
    );
    setState(() {});
  }

  void _openEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EventDetailScreen(event: event, color: _clubColor(event.clubId)),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([rsvpStore, calendarSyncService]),
      builder: (context, _) {
        final allEvents = _personalEvents();
        final selectedEvents = _eventsForDay(_selectedDay, allEvents);
        final counts = {
          for (final day in _visibleDays)
            day: _eventsForDay(day, allEvents).length,
        };

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: _CalendarHeader(
                      eventCount: allEvents.length,
                      syncedCount: _syncedCount(allEvents),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DateStrip(
                    days: _visibleDays,
                    selectedDay: _selectedDay,
                    eventCounts: counts,
                    onSelect: (day) => setState(() => _selectedDay = day),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                    child: _SelectedDayTitle(
                      day: _selectedDay,
                      count: selectedEvents.length,
                    ),
                  ),
                ),
                if (selectedEvents.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _CalendarEmptyState(
                      hasAnyRsvp: allEvents.isNotEmpty,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                    sliver: SliverList.separated(
                      itemCount: selectedEvents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final event = selectedEvents[index];
                        return _CalendarEventCard(
                          event: event,
                          color: _clubColor(event.clubId),
                          synced: calendarSyncService.isSynced(
                            _userId,
                            event.id,
                          ),
                          onTap: () => _openEvent(event),
                          onSync: () => _syncEvent(event),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  final int eventCount;
  final int syncedCount;

  const _CalendarHeader({required this.eventCount, required this.syncedCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Calendar',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your RSVP events appear here and get sent to your phone calendar.',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  color: AppColors.primaryRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$eventCount RSVP${eventCount == 1 ? '' : 's'} upcoming',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$syncedCount synced with your phone calendar',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateStrip extends StatelessWidget {
  final List<DateTime> days;
  final DateTime selectedDay;
  final Map<DateTime, int> eventCounts;
  final ValueChanged<DateTime> onSelect;

  const _DateStrip({
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
    return SizedBox(
      height: 88,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = _sameDay(day, selectedDay);
          final count = eventCounts[day] ?? 0;
          return GestureDetector(
            onTap: () => onSelect(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryRed : AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? AppColors.primaryRed : AppColors.divider,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayLabel(day),
                    style: TextStyle(
                      fontSize: 11,
                      color: selected
                          ? Colors.white70
                          : AppColors.secondaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1,
                      color: selected ? Colors.white : AppColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    width: count > 0 ? 18 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.92)
                          : count > 0
                          ? AppColors.primaryRed
                          : AppColors.divider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _weekdayLabel(DateTime day) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    if (day.year == now.year && day.month == now.month && day.day == now.day) {
      return 'Today';
    }
    return labels[day.weekday - 1];
  }
}

class _SelectedDayTitle extends StatelessWidget {
  final DateTime day;
  final int count;

  const _SelectedDayTitle({required this.day, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _dateLabel(day),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
            letterSpacing: -0.4,
          ),
        ),
        const Spacer(),
        Text(
          '$count event${count == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _dateLabel(DateTime day) {
    const months = [
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
    final now = DateTime.now();
    if (day.year == now.year && day.month == now.month && day.day == now.day) {
      return 'Today';
    }
    return '${months[day.month - 1]} ${day.day}';
  }
}

class _CalendarEventCard extends StatelessWidget {
  final Event event;
  final Color color;
  final bool synced;
  final VoidCallback onTap;
  final VoidCallback onSync;

  const _CalendarEventCard({
    required this.event,
    required this.color,
    required this.synced,
    required this.onTap,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere(
      (club) => club.id == event.clubId,
      orElse: () => clubs.first,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 64,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(17),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _monthLabel(event.dateTime.month).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                  Text(
                    '${event.dateTime.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.text,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${club.name} - ${_timeLabel(event.dateTime)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: synced ? null : onSync,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: synced ? AppColors.lightRed : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Icon(
                  synced
                      ? Icons.event_available_rounded
                      : Icons.calendar_month_outlined,
                  size: 18,
                  color: synced
                      ? AppColors.primaryRed
                      : AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthLabel(int month) {
    const labels = [
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
    return labels[month - 1];
  }

  String _timeLabel(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

class _CalendarEmptyState extends StatelessWidget {
  final bool hasAnyRsvp;

  const _CalendarEmptyState({required this.hasAnyRsvp});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(
                hasAnyRsvp
                    ? Icons.event_note_outlined
                    : Icons.calendar_month_outlined,
                size: 34,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasAnyRsvp ? 'No RSVP on this day' : 'No events yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              hasAnyRsvp
                  ? 'Pick another day to see the events you are attending.'
                  : 'RSVP to an event and it will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
