import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
import '../services/user_state.dart';
import '../widgets/rsvp_button.dart';
import 'event_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Week helpers
// ─────────────────────────────────────────────────────────────────────────────

DateTime _weekStart() {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day);
}

DateTime _weekEnd() {
  final start = _weekStart();
  return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
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

bool _isThisWeek(Event e) {
  final ws = _weekStart();
  final we = _weekEnd();
  return !e.dateTime.isAfter(we) && !e.endTime.isBefore(ws);
}

// ─────────────────────────────────────────────────────────────────────────────
// Category system
// ─────────────────────────────────────────────────────────────────────────────

enum _Category { all, tech, career, arts, social, academic }

enum _ViewMode { live, byDate }

extension _CatInfo on _Category {
  String get label {
    switch (this) {
      case _Category.all:      return 'All';
      case _Category.tech:     return 'Tech';
      case _Category.career:   return 'Career';
      case _Category.arts:     return 'Arts';
      case _Category.social:   return 'Social';
      case _Category.academic: return 'Academic';
    }
  }

  IconData get icon {
    switch (this) {
      case _Category.all:      return Icons.apps_rounded;
      case _Category.tech:     return Icons.computer_rounded;
      case _Category.career:   return Icons.work_outline_rounded;
      case _Category.arts:     return Icons.palette_outlined;
      case _Category.social:   return Icons.people_outline_rounded;
      case _Category.academic: return Icons.school_outlined;
    }
  }
}

bool _matchesCategory(Event e, _Category cat) {
  if (cat == _Category.all) return true;
  final tags = e.tags.map((t) => t.toLowerCase()).join(' ');
  final title = e.title.toLowerCase();
  switch (cat) {
    case _Category.tech:
      return tags.contains('hackathon') || tags.contains('workshop') ||
          tags.contains('coding') || tags.contains('engineering') ||
          tags.contains('robotics') || tags.contains('hands-on') ||
          tags.contains('ai') ||
          ['c4', 'c21', 'c26'].contains(e.clubId) ||
          title.contains('workshop') || title.contains('hackathon') ||
          title.contains('api') || title.contains('flutter') ||
          title.contains('robolig') || title.contains('kodlama');
    case _Category.career:
      return tags.contains('career') || tags.contains('networking') ||
          tags.contains('entrepreneurship') || tags.contains('pitching') ||
          tags.contains('consulting') || tags.contains('case study') ||
          tags.contains('talk') || tags.contains('q&a') ||
          e.guestSpeaker != null ||
          ['c7', 'c8', 'c15', 'c18', 'c32'].contains(e.clubId);
    case _Category.arts:
      return ['c6', 'c9', 'c12', 'c28', 'c29', 'c31', 'c33', 'c34', 'c35', 'c39', 'c41']
              .contains(e.clubId) ||
          tags.contains('concert') || tags.contains('music') ||
          tags.contains('art') || tags.contains('dance') ||
          tags.contains('film') || tags.contains('classical');
    case _Category.social:
      return ['c11', 'c22', 'c23', 'c24', 'c25', 'c36'].contains(e.clubId) ||
          tags.contains('free food') || tags.contains('social') ||
          tags.contains('community') || tags.contains('volunteer') ||
          tags.contains('free entry');
    case _Category.academic:
      return ['c3', 'c10', 'c14', 'c17', 'c20', 'c27', 'c30', 'c37', 'c38']
              .contains(e.clubId) ||
          tags.contains('panel') || tags.contains('discussion') ||
          tags.contains('philosophy') || tags.contains('legal') ||
          tags.contains('reading') || tags.contains('competition') ||
          tags.contains('debate') || tags.contains('research') ||
          tags.contains('women in tech');
    default:
      return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Don't Miss scoring
// ─────────────────────────────────────────────────────────────────────────────

double _score(Event e) {
  final now = DateTime.now();
  if (e.endTime.isBefore(now)) return -1;
  double score = 0;
  if (_isLive(e)) {
    score += 4;
  } else if (e.dateTime.difference(now).inHours < 2) {
    score += 3;
  } else if (e.dateTime.difference(now).inHours < 6) {
    score += 2;
  } else if (e.dateTime.difference(now).inHours < 24) {
    score += 1;
  }
  score += e.attendeeUserIds.toSet().length * 0.3;
  if (userState.followedClubIds.contains(e.clubId)) score += 5;
  final hoursAway = e.dateTime.difference(now).inHours.clamp(0, 168);
  score += (168 - hoursAway) * 0.01;
  return score;
}

String _reasonLabel(Event e) {
  if (_isLive(e)) return 'Live now';
  if (userState.followedClubIds.contains(e.clubId)) {
    final club = clubs.firstWhere((c) => c.id == e.clubId, orElse: () => clubs.first);
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
  late DateTime _selectedDay;
  _Category _selectedCategory = _Category.all;
  _ViewMode _viewMode = _ViewMode.byDate;
  final _selectedDayKey = GlobalKey();

  void _scrollToSelectedDay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedDayKey.currentContext != null) {
        Scrollable.ensureVisible(
          _selectedDayKey.currentContext!,
          alignment: 0.3,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final userId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

    // Seed RSVP store for all non-past events
    for (final e in events.where((e) => e.endTime.isAfter(now))) {
      rsvpStore.seed(e.id, e.attendeeUserIds.contains(userId));
    }

    // Auto-select today if it has events, else the next upcoming date
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = now.add(const Duration(days: 365));
    final upcoming = events
        .where((e) => e.endTime.isAfter(now) && e.dateTime.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    DateTime? autoDay;
    for (final e in upcoming) {
      final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      if (!d.isBefore(today)) {
        autoDay = d;
        break;
      }
    }
    _selectedDay = autoDay ?? today;
    // Auto-switch to live mode if there are live events right now
    if (events.any(_isLive)) {
      _viewMode = _ViewMode.live;
    }
    _scrollToSelectedDay();
  }

  // Called when user taps a category chip — also resets to the nearest
  // valid date for that category.
  void _onCategoryTap(_Category cat) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = now.add(const Duration(days: 365));

    final filtered = events
        .where((e) =>
            e.endTime.isAfter(now) &&
            e.dateTime.isBefore(cutoff) &&
            _matchesCategory(e, cat))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    DateTime? newDay;
    for (final e in filtered) {
      final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      if (!d.isBefore(today)) {
        newDay = d;
        break;
      }
    }

    setState(() {
      _selectedCategory = cat;
      if (newDay != null) _selectedDay = newDay;
    });
    _scrollToSelectedDay();
  }

  void _openDetail(Event e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(event: e, color: _clubColor(e.clubId)),
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 365));

    // All non-past events in next 365 days
    final allUpcoming = events
        .where((e) => e.endTime.isAfter(now) && e.dateTime.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // Filtered by selected category
    final catFiltered = allUpcoming
        .where((e) => _matchesCategory(e, _selectedCategory))
        .toList();

    // Don't Miss — scored from this week, all categories
    final weekEvents = events.where(_isThisWeek).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final scored = weekEvents
        .where((e) => !e.endTime.isBefore(now))
        .map((e) => (e, _score(e)))
        .where((t) => t.$2 >= 0)
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final liveIds = weekEvents.where(_isLive).map((e) => e.id).toSet();
    final dontMissIds = <String>{};
    final dontMiss = <Event>[];
    for (final (e, _) in scored) {
      if (dontMiss.length == 3) break;
      if (liveIds.contains(e.id)) continue;
      if (dontMissIds.contains(e.id)) continue;
      dontMiss.add(e);
      dontMissIds.add(e.id);
    }

    final liveAll = catFiltered.where(_isLive).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, allUpcoming.length),

          // ── Category + mode toggle bar ────────────────────────────────────
          _buildTopControls(liveAll.length),

          // ── Live mode ─────────────────────────────────────────────────────
          if (_viewMode == _ViewMode.live) ...[
            _buildLiveSection(liveAll),
          ],

          // ── By-date mode ──────────────────────────────────────────────────
          if (_viewMode == _ViewMode.byDate) ...[
            _buildDayPicker(catFiltered),
            _buildBrowseResults(catFiltered),
          ],

          // ── Don't Miss This Week ─────────────────────────────────────────
          if (dontMiss.isNotEmpty) ...[
            _sectionHeader("Don't Miss This Week",
                Icons.star_rounded, AppColors.accentGold),
            _dontMissSection(dontMiss),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, int totalUpcoming) {
    final liveCount = events.where(_isLive).length;

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(context).padding.top + 16, 20, 16),
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Events at KU',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  '$totalUpcoming upcoming',
                  style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                ),
                if (liveCount > 0) ...[
                  const Text('  ·  ',
                      style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
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
                      fontSize: 13,
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Top controls: category chips + Live / By Date toggle ─────────────────

  Widget _buildTopControls(int liveCount) {
    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _Category.values.map((cat) {
                  final selected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _onCategoryTap(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryRed
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon,
                                size: 13,
                                color: selected
                                    ? Colors.white
                                    : AppColors.secondaryText),
                            const SizedBox(width: 5),
                            Text(
                              cat.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: selected
                                    ? Colors.white
                                    : AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // Live / By Date toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeTab(
                      label: 'By Date',
                      icon: Icons.calendar_month_rounded,
                      selected: _viewMode == _ViewMode.byDate,
                      liveCount: 0,
                      onTap: () => setState(() => _viewMode = _ViewMode.byDate),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeTab(
                      label: 'Live Now',
                      icon: Icons.radio_button_checked_rounded,
                      selected: _viewMode == _ViewMode.live,
                      liveCount: liveCount,
                      onTap: () => setState(() => _viewMode = _ViewMode.live),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Live events section ────────────────────────────────────────────────────

  Widget _buildLiveSection(List<Event> liveNow) {
    if (liveNow.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.radio_button_checked_rounded,
                    color: AppColors.primaryRed, size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'No live events right now',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text),
              ),
              const SizedBox(height: 8),
              const Text(
                'Switch to By Date to browse upcoming events.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    final rows = <Widget>[];

    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          _PulseDot(color: AppColors.primaryRed),
          const SizedBox(width: 8),
          const Text(
            'Happening right now',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${liveNow.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryRed,
              ),
            ),
          ),
        ],
      ),
    ));

    for (final e in liveNow) {
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: _LiveCard(
          event: e,
          color: _clubColor(e.clubId),
          onTap: () => _openDetail(e),
        ),
      ));
    }

    return SliverList(delegate: SliverChildListDelegate(rows));
  }

  // ── Date picker (year-wide, filtered by category) ─────────────────────────

  Widget _buildDayPicker(List<Event> catFiltered) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Count events per day key "YYYY-M-D"
    final dayCounts = <String, int>{};
    for (final e in catFiltered) {
      final k = '${e.dateTime.year}-${e.dateTime.month}-${e.dateTime.day}';
      dayCounts[k] = (dayCounts[k] ?? 0) + 1;
    }

    // Unique calendar dates in chronological order
    final uniqueDates = <DateTime>[];
    final seen = <String>{};
    for (final e in catFiltered) {
      final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      final k = '${d.year}-${d.month}-${d.day}';
      if (seen.add(k)) uniqueDates.add(d);
    }

    if (uniqueDates.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    const monthNames = [
      '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    const weekdayAbbr = ['', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    final items = <_PickerItem>[];
    int lastMonth = -1;
    for (final date in uniqueDates) {
      if (date.month != lastMonth) {
        items.add(_PickerItem.month(monthNames[date.month]));
        lastMonth = date.month;
      }
      items.add(_PickerItem.day(date));
    }

    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                'BROWSE BY DAY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryText,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: items.map((item) {
                  if (item.isMonth) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10, left: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.monthLabel!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondaryText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppColors.divider,
                          ),
                        ],
                      ),
                    );
                  }

                  final date = item.date!;
                  final isSelected = date == _selectedDay;
                  final isToday = date == today;
                  final countKey = '${date.year}-${date.month}-${date.day}';
                  final count = dayCounts[countKey] ?? 0;
                  final wd = weekdayAbbr[date.weekday];

                  return Padding(
                    key: isSelected ? _selectedDayKey : null,
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDay = date),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 54,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryRed
                              : isToday
                                  ? AppColors.lightRed
                                  : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: isToday && !isSelected
                              ? Border.all(
                                  color: AppColors.primaryRed
                                      .withValues(alpha: 0.55),
                                  width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Weekday abbrev
                            Text(
                              wd,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.75)
                                    : AppColors.secondaryText,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Day number
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                        ? AppColors.primaryRed
                                        : AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 5),
                            // "TODAY" label or event count dots
                            if (isToday && !isSelected)
                              Text(
                                'TODAY',
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryRed,
                                  letterSpacing: 0.5,
                                ),
                              )
                            else if (count > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  count.clamp(1, 3),
                                  (i) => Container(
                                    width: 4,
                                    height: 4,
                                    margin: EdgeInsets.only(
                                        right: i < count.clamp(1, 3) - 1
                                            ? 2.5
                                            : 0),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.65)
                                          : AppColors.primaryRed
                                              .withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 9),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Browse results: live + selected-day events ─────────────────────────────

  Widget _buildBrowseResults(List<Event> catFiltered) {
    // All events on selected day (live events also appear in the dedicated live section above)
    final dayEvents = catFiltered.where((e) {
      final d = e.dateTime;
      return d.year == _selectedDay.year &&
          d.month == _selectedDay.month &&
          d.day == _selectedDay.day;
    }).toList();

    if (dayEvents.isEmpty) {
      final dayStr = _dayLabel(_selectedDay);
      final catStr = _selectedCategory == _Category.all
          ? ''
          : ' ${_selectedCategory.label.toLowerCase()}';
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Row(
            children: [
              Icon(Icons.event_busy_rounded,
                  size: 16,
                  color: AppColors.secondaryText.withValues(alpha: 0.45)),
              const SizedBox(width: 8),
              Text(
                'No$catStr events on $dayStr',
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ),
      );
    }

    final rows = <Widget>[];

    // Day sub-header with event count
    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded,
              size: 14, color: AppColors.secondaryText),
          const SizedBox(width: 8),
          Text(
            _dayLabel(_selectedDay),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· ${dayEvents.length} event${dayEvents.length > 1 ? 's' : ''}',
            style: const TextStyle(
                fontSize: 13, color: AppColors.secondaryText),
          ),
        ],
      ),
    ));

    for (final e in dayEvents) {
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: _EventCard(
          event: e,
          color: _clubColor(e.clubId),
          onTap: () => _openDetail(e),
        ),
      ));
    }

    return SliverList(delegate: SliverChildListDelegate(rows));
  }

  String _dayLabel(DateTime d) {
    if (_isDateToday(d)) return 'Today';
    if (_isDateTomorrow(d)) return 'Tomorrow';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month]} ${d.day}';
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon, Color color,
      {bool showPulse = false}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
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

  // ── Don't Miss ─────────────────────────────────────────────────────────────

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

}

// ─────────────────────────────────────────────────────────────────────────────
// Date-picker helper
// ─────────────────────────────────────────────────────────────────────────────

class _PickerItem {
  final bool isMonth;
  final String? monthLabel;
  final DateTime? date;

  const _PickerItem._({required this.isMonth, this.monthLabel, this.date});

  factory _PickerItem.month(String label) =>
      _PickerItem._(isMonth: true, monthLabel: label);

  factory _PickerItem.day(DateTime date) =>
      _PickerItem._(isMonth: false, date: date);
}

// ─────────────────────────────────────────────────────────────────────────────
// Live card
// ─────────────────────────────────────────────────────────────────────────────

class _LiveCard extends StatelessWidget {
  final Event event;
  final Color color;
  final VoidCallback onTap;

  const _LiveCard({required this.event, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final club =
        clubs.firstWhere((c) => c.id == event.clubId, orElse: () => clubs.first);
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryRed,
                    Color.lerp(AppColors.primaryRed, Colors.black, 0.2)!,
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
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
                        letterSpacing: 1.2),
                  ),
                  const Spacer(),
                  Text(remainingLabel,
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
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
                        color: AppColors.text),
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
                            eventId: event.id, color: color, compact: true),
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
// Event card
// ─────────────────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final Event event;
  final Color color;
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final club =
        clubs.firstWhere((c) => c.id == event.clubId, orElse: () => clubs.first);
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
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        color: color),
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
                        color: AppColors.text),
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
                  if (event.guestSpeaker != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.mic_rounded,
                            size: 13, color: AppColors.accentGold),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            event.guestSpeaker!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                                fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: event.tags
                            .map((tag) => Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(tag,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: color)),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  RsvpButton(eventId: event.id, color: color, compact: true),
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
    final club =
        clubs.firstWhere((c) => c.id == event.clubId, orElse: () => clubs.first);
    const weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              event.title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.text),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '$dayLabel · $timeLabel',
                  style: TextStyle(
                      fontSize: 12, color: color, fontWeight: FontWeight.w600),
                ),
                const Text('  ·  ',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.secondaryText)),
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
              style:
                  const TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            if (event.guestSpeaker != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.mic_rounded,
                      size: 13, color: AppColors.accentGold),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      event.guestSpeaker!,
                      style: TextStyle(
                          fontSize: 12, color: color, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (event.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: event.tags
                    .take(3)
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(tag,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                RsvpButton(eventId: event.id, color: color, compact: true),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                  color: AppColors.text),
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

// ─────────────────────────────────────────────────────────────────────────────
// Mode toggle tab
// ─────────────────────────────────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int liveCount;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.liveCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = liveCount > 0 && label == 'Live Now';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? (isLive ? AppColors.primaryRed : AppColors.surfaceAlt)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.divider,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLive && selected)
              _PulseDot(color: Colors.white)
            else
              Icon(
                icon,
                size: 15,
                color: selected
                    ? (isLive ? Colors.white : AppColors.text)
                    : AppColors.secondaryText,
              ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? (isLive ? Colors.white : AppColors.text)
                    : AppColors.secondaryText,
              ),
            ),
            if (liveCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.primaryRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$liveCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : AppColors.primaryRed,
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
