import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
import '../services/user_state.dart';
import '../widgets/rsvp_button.dart';
import 'event_detail_screen.dart';
import 'explore_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Week helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns Monday 00:00:00 of the current local week.
DateTime _weekStart() {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day);
}

/// Returns Sunday 23:59:59 of the current local week.
DateTime _weekEnd() {
  final start = _weekStart();
  return start
      .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
}

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

/// Whether the event overlaps [_weekStart, _weekEnd] at all.
/// A live event counts if it ends after weekStart.
bool _isThisWeek(Event e) {
  final ws = _weekStart();
  final we = _weekEnd();
  // Overlaps the week window if start <= weekEnd AND end >= weekStart
  return !e.dateTime.isAfter(we) && !e.endTime.isBefore(ws);
}

// ─────────────────────────────────────────────────────────────────────────────
// Scoring for "Don't Miss This Week"
// ─────────────────────────────────────────────────────────────────────────────

double _score(Event e) {
  final now = DateTime.now();
  if (e.endTime.isBefore(now)) return -1; // exclude ended

  double score = 0;

  // Live or soon
  if (_isLive(e)) {
    score += 4;
  } else if (e.dateTime.difference(now).inHours < 2) {
    score += 3;
  } else if (e.dateTime.difference(now).inHours < 6) {
    score += 2;
  } else if (e.dateTime.difference(now).inHours < 24) {
    score += 1;
  }

  // Attendee popularity
  score += e.attendeeUserIds.toSet().length * 0.3;

  // Followed club boost
  if (userState.followedClubIds.contains(e.clubId)) score += 5;

  // Slight recency bonus — closer upcoming events score higher
  final hoursAway = e.dateTime.difference(now).inHours.clamp(0, 168);
  score += (168 - hoursAway) * 0.01;

  return score;
}

String _reasonLabel(Event e) {
  if (_isLive(e)) return 'Live now';
  if (userState.followedClubIds.contains(e.clubId)) {
    final club =
        clubs.firstWhere((c) => c.id == e.clubId, orElse: () => clubs.first);
    return 'Because you follow ${club.name.split(' ').first}';
  }
  if (e.attendeeUserIds.length >= 5) return 'Popular this week';
  return 'Happening soon';
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class ThisWeekScreen extends StatefulWidget {
  const ThisWeekScreen({super.key});

  @override
  State<ThisWeekScreen> createState() => _ThisWeekScreenState();
}

class _ThisWeekScreenState extends State<ThisWeekScreen> {
  @override
  void initState() {
    super.initState();
    // Seed RSVP store for all this-week events
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    for (final e in events.where(_isThisWeek)) {
      rsvpStore.seed(e.id, e.attendeeUserIds.contains(userId));
    }
  }

  void _openDetail(Event e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EventDetailScreen(event: e, color: _clubColor(e.clubId)),
      ),
    ).then((_) => setState(() {}));
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // All events in this week's window
    final weekEvents = events.where(_isThisWeek).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // Live now
    final liveNow = weekEvents.where(_isLive).toList();

    // Today (not live; still upcoming or just started today)
    final todayEvents = weekEvents
        .where((e) => _isDateToday(e.dateTime) && !_isLive(e) && e.dateTime.isAfter(now))
        .toList();

    // Tomorrow
    final tomorrowEvents = weekEvents
        .where((e) => _isDateTomorrow(e.dateTime))
        .toList();

    // Don't Miss: scored, exclude already ended, take top 3, no duplicates with live
    final liveIds = liveNow.map((e) => e.id).toSet();
    final scored = weekEvents
        .where((e) => !e.endTime.isBefore(now))
        .map((e) => (e, _score(e)))
        .where((t) => t.$2 >= 0)
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final dontMissIds = <String>{};
    final dontMiss = <Event>[];
    for (final (e, _) in scored) {
      if (dontMiss.length == 3) break;
      if (liveIds.contains(e.id)) continue; // already shown in Live
      if (dontMissIds.contains(e.id)) continue;
      dontMiss.add(e);
      dontMissIds.add(e.id);
    }

    // Upcoming: rest of the week, exclude live, today, tomorrow, don't-miss, ended
    final shownIds = {
      ...liveIds,
      ...todayEvents.map((e) => e.id),
      ...tomorrowEvents.map((e) => e.id),
      ...dontMissIds,
    };
    final upcoming = weekEvents
        .where((e) =>
            !shownIds.contains(e.id) &&
            e.dateTime.isAfter(now) &&
            !_isDateToday(e.dateTime) &&
            !_isDateTomorrow(e.dateTime))
        .toList();

    // Header counts
    final totalCount = weekEvents
        .where((e) => !e.endTime.isBefore(now) || _isLive(e))
        .length;
    final todayTotal =
        weekEvents.where((e) => _isDateToday(e.dateTime)).length;
    final liveCount = liveNow.length;

    final isEmpty = totalCount == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, totalCount, todayTotal, liveCount),
          if (isEmpty)
            _emptyState(context)
          else ...[
            if (liveNow.isNotEmpty) ...[
              _sectionHeader('Live Now', Icons.radio_button_on,
                  AppColors.primaryRed,
                  showPulse: true),
              _liveSection(liveNow),
            ] else
              _liveSectionEmpty(),
            if (todayEvents.isNotEmpty) ...[
              _sectionHeader('Today', Icons.wb_sunny_outlined,
                  const Color(0xFFE65100)),
              _eventCardList(todayEvents),
            ],
            if (tomorrowEvents.isNotEmpty) ...[
              _sectionHeader('Tomorrow', Icons.brightness_2_outlined,
                  const Color(0xFF1565C0)),
              _eventCardList(tomorrowEvents),
            ],
            if (dontMiss.isNotEmpty) ...[
              _sectionHeader(
                  "Don't Miss This Week", Icons.star_rounded, AppColors.accentGold),
              _dontMissSection(dontMiss),
            ],
            if (upcoming.isNotEmpty) ...[
              _sectionHeader('Upcoming This Week', Icons.calendar_month_outlined,
                  AppColors.secondaryText),
              _upcomingList(upcoming),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ],
      ),
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar(
      BuildContext context, int total, int todayCount, int liveCount) {
    final ws = _weekStart();
    final we = _weekEnd();
    final monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final rangeLabel = ws.month == we.month
        ? '${ws.day}–${we.day} ${monthNames[ws.month]}'
        : '${ws.day} ${monthNames[ws.month]} – ${we.day} ${monthNames[we.month]}';

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(context).padding.top + 16, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.card,
          border:
              Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rangeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'This Week at KU',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '$total event${total == 1 ? '' : 's'} this week',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.secondaryText),
                ),
                if (todayCount > 0 || liveCount > 0) ...[
                  const Text('  ·  ',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.secondaryText)),
                  if (todayCount > 0)
                    Text(
                      '$todayCount today',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.secondaryText),
                    ),
                  if (todayCount > 0 && liveCount > 0)
                    const Text('  ·  ',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.secondaryText)),
                  if (liveCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          '$liveCount live now',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Section headers ──────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon, Color color,
      {bool showPulse = false}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
        child: Row(
          children: [
            if (showPulse)
              _PulseDot(color: color)
            else
              Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Live Now ─────────────────────────────────────────────────────────────────

  Widget _liveSection(List<Event> live) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _LiveCard(
            event: live[i],
            color: _clubColor(live[i].clubId),
            onTap: () => _openDetail(live[i]),
          ),
        ),
        childCount: live.length,
      ),
    );
  }

  Widget _liveSectionEmpty() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            Icon(Icons.radio_button_off,
                size: 14, color: AppColors.secondaryText.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Text(
              'Nothing live right now',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Today / Tomorrow cards ────────────────────────────────────────────────────

  Widget _eventCardList(List<Event> list) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _EventCard(
            event: list[i],
            color: _clubColor(list[i].clubId),
            onTap: () => _openDetail(list[i]),
          ),
        ),
        childCount: list.length,
      ),
    );
  }

  // ── Don't Miss ───────────────────────────────────────────────────────────────

  Widget _dontMissSection(List<Event> picks) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _DontMissCard(
            event: picks[i],
            color: _clubColor(picks[i].clubId),
            reason: _reasonLabel(picks[i]),
            onTap: () => _openDetail(picks[i]),
          ),
        ),
        childCount: picks.length,
      ),
    );
  }

  // ── Upcoming list ────────────────────────────────────────────────────────────

  Widget _upcomingList(List<Event> list) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final e = list[i];
          final club = clubs.firstWhere((c) => c.id == e.clubId,
              orElse: () => clubs.first);
          final color = _clubColor(e.clubId);
          final weekdays = [
            '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
            'Friday', 'Saturday', 'Sunday'
          ];
          final dayLabel = weekdays[e.dateTime.weekday];
          final timeLabel =
              '${_pad(e.dateTime.hour)}:${_pad(e.dateTime.minute)}';

          return InkWell(
            onTap: () => _openDetail(e),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  // Day / time column
                  SizedBox(
                    width: 68,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                        Text(
                          timeLabel,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 3,
                    height: 36,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${club.name.split(' ').first}  ·  ${e.location}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.secondaryText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.secondaryText),
                ],
              ),
            ),
          );
        },
        childCount: list.length,
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────────

  Widget _emptyState(BuildContext context) {
    return SliverFillRemaining(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.calendar_today_rounded,
                  color: AppColors.primaryRed, size: 34),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quiet week at KU',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text),
            ),
            const SizedBox(height: 10),
            const Text(
              'No events have been posted for this week yet.\nCheck back soon or follow more clubs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ExploreScreen()));
              },
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Explore clubs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ─────────────────────────────────────────────────────────────────────────────
// Live card
// ─────────────────────────────────────────────────────────────────────────────

class _LiveCard extends StatelessWidget {
  final Event event;
  final Color color;
  final VoidCallback onTap;

  const _LiveCard(
      {required this.event, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == event.clubId,
        orElse: () => clubs.first);
    final endsAt =
        '${event.endTime.hour.toString().padLeft(2, '0')}:${event.endTime.minute.toString().padLeft(2, '0')}';
    final remaining = event.endTime.difference(DateTime.now());
    final remainingLabel = remaining.inMinutes < 60
        ? 'Ends in ${remaining.inMinutes} min'
        : 'Ends at $endsAt';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primaryRed.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live banner
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryRed,
                    Color.lerp(AppColors.primaryRed, Colors.black, 0.2)!,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  _PulseDot(color: Colors.white),
                  const SizedBox(width: 7),
                  const Text(
                    'LIVE NOW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    remainingLabel,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.groups_outlined,
                          size: 14, color: AppColors.secondaryText),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          club.name.split(' ').first,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.secondaryText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.secondaryText),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          event.location,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.secondaryText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RsvpButton(
                          eventId: event.id,
                          color: color,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ViewChip(onTap: onTap),
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
// Event card (Today / Tomorrow)
// ─────────────────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final Event event;
  final Color color;
  final VoidCallback onTap;

  const _EventCard(
      {required this.event, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == event.clubId,
        orElse: () => clubs.first);
    final timeLabel =
        '${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}';
    final attendeeCount = event.attendeeUserIds.toSet().length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time accent
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.groups_outlined,
                          size: 13, color: AppColors.secondaryText),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          club.name.split(' ').first,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.secondaryText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.secondaryText),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          event.location,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.secondaryText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (attendeeCount > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            size: 13, color: AppColors.secondaryText),
                        const SizedBox(width: 4),
                        Text(
                          '$attendeeCount attending',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.secondaryText),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  RsvpButton(
                    eventId: event.id,
                    color: color,
                    compact: true,
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
// Don't Miss card
// ─────────────────────────────────────────────────────────────────────────────

class _DontMissCard extends StatelessWidget {
  final Event event;
  final Color color;
  final String reason;
  final VoidCallback onTap;

  const _DontMissCard({
    required this.event,
    required this.color,
    required this.reason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == event.clubId,
        orElse: () => clubs.first);
    final weekdays = [
      '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    final dayLabel = _isDateToday(event.dateTime)
        ? 'Today'
        : _isDateTomorrow(event.dateTime)
            ? 'Tomorrow'
            : weekdays[event.dateTime.weekday];
    final timeLabel =
        '${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reason chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 12, color: color),
                  const SizedBox(width: 5),
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '$dayLabel · $timeLabel',
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600),
                ),
                const Text('  ·  ',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.secondaryText)),
                Flexible(
                  child: Text(
                    event.location,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.secondaryText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              club.name.split(' ').first,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                RsvpButton(
                    eventId: event.id, color: color, compact: true),
                const Spacer(),
                _ViewChip(onTap: onTap),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ViewChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 11, color: AppColors.secondaryText),
          ],
        ),
      ),
    );
  }
}

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
      builder: (context2, x) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
