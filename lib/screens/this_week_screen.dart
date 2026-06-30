import 'package:flutter/material.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/event_access.dart';
import '../services/lazy_content_loader.dart';
import '../services/mock_data.dart';
import '../services/rsvp_store.dart';
import '../services/user_state.dart';
import '../services/view_tracker.dart';
import '../widgets/club_avatar.dart';
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

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

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

String _shortDay(DateTime d) {
  if (_isDateToday(d)) return S.today;
  if (_isDateTomorrow(d)) return S.tomorrow;
  return '${_kWeekdays[d.weekday].substring(0, 3)} ${d.day}';
}

String _relativeDay(DateTime d) {
  if (_isDateToday(d)) return S.today;
  if (_isDateTomorrow(d)) return S.tomorrow;
  return _kWeekdays[d.weekday].substring(0, 3);
}

// ─────────────────────────────────────────────────────────────────────────────
// Date result — differentiates explicit Done from sheet dismiss
// ─────────────────────────────────────────────────────────────────────────────

class _DateResult {
  final Set<String> keys; // day-key strings yyyy-m-d
  const _DateResult(this.keys);
}

// ─────────────────────────────────────────────────────────────────────────────
// Week tab — "Discover events" search-style layout
// ─────────────────────────────────────────────────────────────────────────────

class ThisWeekScreen extends StatefulWidget {
  const ThisWeekScreen({super.key});

  @override
  State<ThisWeekScreen> createState() => _ThisWeekScreenState();
}

class _ThisWeekScreenState extends State<ThisWeekScreen> {
  String _audience = 'all'; // 'all' | 'following'
  Set<String> _dateFilters =
      {}; // empty = any date; else set of day-key strings
  bool _showLive = false;
  bool _showPastWeek = false;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEventContent();
    localeService.addListener(_onLocaleChanged);
    final now = DateTime.now();
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    for (final e in events.where((e) => e.endTime.isAfter(now))) {
      rsvpStore.seed(e.id, e.attendeeUserIds.contains(userId));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadEventContent() async {
    try {
      await lazyContentLoader.ensureContentLoaded();
      if (mounted) setState(() {});
    } catch (_) {
      // Keep local seed events visible if Supabase content is unreachable.
    }
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // Rolling 21-day pool (3 weeks) — excludes fully-past events, keeps live ones.
  List<Event> get _eventPool {
    final now = DateTime.now();
    final end = _today.add(const Duration(days: 21));
    return events
        .where((e) => e.endTime.isAfter(now) && e.dateTime.isBefore(end))
        .toList();
  }

  // Events that finished during the previous seven days.
  List<Event> get _pastWeekPool {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return events
        .where(
          (event) =>
              !event.endTime.isAfter(now) && event.endTime.isAfter(weekAgo),
        )
        .toList();
  }

  bool _matchesQuery(Event e, String q) {
    if (e.title.toLowerCase().contains(q)) return true;
    if (e.description.toLowerCase().contains(q)) return true;
    if (e.location.toLowerCase().contains(q)) return true;
    final club = clubs.firstWhere(
      (c) => c.id == e.clubId,
      orElse: () => clubs.first,
    );
    return club.name.toLowerCase().contains(q);
  }

  List<Event> _results() {
    var list = _showPastWeek ? _pastWeekPool : _eventPool;
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      // Search stays inside the selected upcoming/past time window.
      list = list.where((e) => _matchesQuery(e, q)).toList();
    } else {
      if (_audience == 'following') {
        final followed = userState.followedClubIds;
        list = list.where((e) => followed.contains(e.clubId)).toList();
      }
      if (_dateFilters.isNotEmpty) {
        list = list
            .where((e) => _dateFilters.contains(_dayKey(e.dateTime)))
            .toList();
      }
      if (_showLive) {
        list = list.where((e) => _isLive(e)).toList();
      }
    }
    if (_showPastWeek) {
      list.sort((a, b) => b.endTime.compareTo(a.endTime));
    } else {
      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }
    return list;
  }

  // ── New-events bell ─────────────────────────────────────────────────────────

  String get _viewerId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  DateTime _createdAtForEvent(Event event) {
    if (event.id.startsWith('ev_')) {
      final millis = int.tryParse(event.id.substring(3));
      if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return event.dateTime;
  }

  bool _isCreatedInApp(Event event) {
    return event.createdByUserId != null || event.id.startsWith('ev_');
  }

  List<Event> _newUnopenedEvents() {
    final viewerId = _viewerId;
    if (viewerId.isEmpty) return [];
    final now = DateTime.now();
    return events.where((event) {
        if (!_isCreatedInApp(event)) return false;
        if (!event.endTime.isAfter(now)) return false;
        return !viewTracker.viewerIds(event.id).contains(viewerId);
      }).toList()
      ..sort((a, b) => _createdAtForEvent(b).compareTo(_createdAtForEvent(a)));
  }

  Future<void> _openNewEventNotifications() async {
    final newEvents = _newUnopenedEvents();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NewEventsSheet(
        events: newEvents,
        createdAtForEvent: _createdAtForEvent,
        onEventTap: (event) {
          Navigator.pop(sheetContext);
          _openEvent(event);
        },
      ),
    );
    if (mounted) setState(() {});
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

  void _resetFilters() {
    setState(() {
      _audience = 'all';
      _dateFilters = {};
      _showLive = false;
      _showPastWeek = false;
      _query = '';
      _searchController.clear();
    });
  }

  // ── Filter sheets ──────────────────────────────────────────────────────────

  Future<void> _showAudienceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AudienceSheet(
        current: _audience,
        onPick: (v) {
          setState(() => _audience = v);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _showDateSheet() async {
    final result = await showModalBottomSheet<_DateResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DatePickerSheet(selected: _dateFilters),
    );
    if (mounted && result != null) {
      setState(() {
        _dateFilters = result.keys;
        _showPastWeek = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  // Pull-to-refresh: re-pull the event list (same gesture as the home feed).
  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final results = _results();
    final newEventCount = _newUnopenedEvents().length;
    final searching = _query.trim().isNotEmpty;
    final hasFilter =
        _audience != 'all' ||
        _dateFilters.isNotEmpty ||
        _showLive ||
        _showPastWeek;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primaryRed,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header: title + subtitle + bell ──
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, topPad + 14, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (Navigator.canPop(context)) ...[
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          margin: const EdgeInsets.only(right: 10, top: 2),
                          decoration: BoxDecoration(
                            color: AppColors.lightGray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.discoverEvents,
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              letterSpacing: -0.9,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _showPastWeek
                                ? S.pastEventsHint
                                : S.upcomingEventsHint,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.secondaryText,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (authService.isStudentSession) ...[
                      const SizedBox(width: 8),
                      _HeaderIconBtn(
                        icon: Icons.notifications_outlined,
                        badgeCount: newEventCount,
                        onTap: _openNewEventNotifications,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Search bar ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: _SearchBar(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () => setState(() {
                    _query = '';
                    _searchController.clear();
                  }),
                ),
              ),
            ),

            // ── Filter bar: audience · date (multi) · live · past · clear ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    // Audience
                    _FilterPillBtn(
                      label: _audience == 'following' ? S.following : S.all,
                      icon: _audience == 'following'
                          ? Icons.favorite_outline_rounded
                          : Icons.people_outline_rounded,
                      active: _audience == 'following',
                      onTap: _showAudienceSheet,
                    ),
                    const SizedBox(width: 8),
                    // Date (multi-select)
                    Expanded(
                      child: _FilterPillBtn(
                        label: _dateFilters.isEmpty
                            ? S.anyDate
                            : _dateFilters.length == 1
                            ? _shortDay(_dayKeyToDate(_dateFilters.first))
                            : '${_dateFilters.length} days',
                        icon: Icons.calendar_today_outlined,
                        active: _dateFilters.isNotEmpty,
                        onTap: _showDateSheet,
                        expand: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Live toggle
                    _LiveToggleBtn(
                      active: _showLive,
                      onTap: () => setState(() => _showLive = !_showLive),
                    ),
                    const SizedBox(width: 8),
                    // Past week toggle
                    _FilterPillBtn(
                      label: S.past,
                      icon: Icons.history_rounded,
                      active: _showPastWeek,
                      showChevron: false,
                      horizontalPadding: 10,
                      onTap: () => setState(() {
                        _showPastWeek = !_showPastWeek;
                        if (_showPastWeek) _dateFilters = {};
                      }),
                    ),
                    // Clear all filters
                    if (hasFilter && !searching) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _resetFilters,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: AppColors.primaryRed.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Count header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${results.length} ${results.length == 1 ? 'event' : 'events'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _contextLabel(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Results / empty ──
            if (results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  searching: searching || hasFilter,
                  onReset: _resetFilters,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, i) {
                    final ev = results[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i < results.length - 1 ? 12 : 0,
                      ),
                      child: _WeekEventRow(
                        key: ValueKey(ev.id),
                        event: ev,
                        color: _clubColor(ev.clubId),
                        onTap: () => _openEvent(ev),
                      ),
                    );
                  }, childCount: results.length),
                ),
              ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 90,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Converts a stored day-key string (yyyy-m-d) back to a DateTime.
  DateTime _dayKeyToDate(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  String _contextLabel() {
    final q = _query.trim();
    if (q.isNotEmpty) return '· "$q"';
    final parts = <String>[];
    if (_showPastWeek) parts.add('past week');
    if (_showLive) parts.add('live now');
    if (_audience == 'following') parts.add('following');
    if (_dateFilters.isNotEmpty) {
      parts.add(
        _dateFilters.length == 1
            ? _shortDay(_dayKeyToDate(_dateFilters.first))
            : '${_dateFilters.length} days',
      );
    }
    if (parts.isEmpty) return '· next 3 weeks';
    return '· ${parts.join(' · ')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 19, color: AppColors.secondaryText),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              cursorColor: AppColors.text,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.text,
                letterSpacing: -0.2,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: S.searchEvents,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: AppColors.secondaryText,
                ),
              ),
              onChanged: (v) {
                widget.onChanged(v);
                setState(() {});
              },
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: () {
                widget.onClear();
                setState(() {});
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter pill button (used in the two-button filter bar)
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPillBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool expand;
  final bool showChevron;
  final double horizontalPadding;

  const _FilterPillBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.expand = false,
    this.showChevron = true,
    this.horizontalPadding = 14,
  });

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryRed : AppColors.card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active ? AppColors.primaryRed : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  color: active ? Colors.white : AppColors.text,
                ),
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: active
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.secondaryText,
              ),
            ],
          ],
        ),
      ),
    );
    return expand ? child : child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live toggle button (pulsing dot when active)
// ─────────────────────────────────────────────────────────────────────────────

class _LiveToggleBtn extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _LiveToggleBtn({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryRed : AppColors.card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active ? AppColors.primaryRed : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulseDot(color: active ? Colors.white : AppColors.primaryRed),
            const SizedBox(width: 6),
            Text(
              S.live,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: active ? Colors.white : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audience bottom sheet (All / Following)
// ─────────────────────────────────────────────────────────────────────────────

class _AudienceSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onPick;

  const _AudienceSheet({required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            S.showEventsFrom,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          _AudienceOption(
            label: S.allEvents,
            subtitle: S.everythingOnCampus,
            icon: Icons.public_outlined,
            selected: current == 'all',
            onTap: () => onPick('all'),
          ),
          const SizedBox(height: 10),
          _AudienceOption(
            label: S.following,
            subtitle: S.followingOnly,
            icon: Icons.favorite_outline_rounded,
            selected: current == 'following',
            onTap: () => onPick('following'),
          ),
        ],
      ),
    );
  }
}

class _AudienceOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AudienceOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryRed.withValues(alpha: 0.08)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primaryRed.withValues(alpha: 0.4)
                : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryRed.withValues(alpha: 0.15)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected
                    ? AppColors.primaryRed
                    : AppColors.secondaryText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primaryRed : AppColors.text,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppColors.primaryRed,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date picker bottom sheet — 3-week calendar grid
// ─────────────────────────────────────────────────────────────────────────────

class _DatePickerSheet extends StatefulWidget {
  final Set<String> selected;

  const _DatePickerSheet({required this.selected});

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late Set<String> _temp;

  @override
  void initState() {
    super.initState();
    _temp = {...widget.selected};
  }

  DateTime get _todayDate {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // Monday of the current week.
  DateTime get _weekStart {
    final t = _todayDate;
    return t.subtract(Duration(days: t.weekday - 1));
  }

  // Week rows to display: from current week through the week that covers today+20.
  List<List<DateTime>> get _weeks {
    final end = _todayDate.add(const Duration(days: 21));
    final List<List<DateTime>> rows = [];
    var ws = _weekStart;
    while (ws.isBefore(end)) {
      rows.add(List.generate(7, (i) => ws.add(Duration(days: i))));
      ws = ws.add(const Duration(days: 7));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final today = _todayDate;
    final weeks = _weeks;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          // Title + Clear
          Row(
            children: [
              Text(
                S.pickDate,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              if (_temp.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(_temp.clear),
                  child: Text(
                    S.clear,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          // Day-of-week header
          Row(
            children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondaryText,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          // Week rows
          for (int wi = 0; wi < weeks.length; wi++) ...[
            // Month label when a new month starts
            if (wi == 0 || weeks[wi][0].month != weeks[wi - 1][0].month) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_kMonths[weeks[wi][0].month]} ${weeks[wi][0].year}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondaryText,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: weeks[wi].map((day) {
                final isToday =
                    day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                final isPast = day.isBefore(today);
                final dayKey = _dayKey(day);
                final isSelected = _temp.contains(dayKey);

                return Expanded(
                  child: GestureDetector(
                    onTap: isPast
                        ? null
                        : () => setState(() {
                            if (!_temp.add(dayKey)) _temp.remove(dayKey);
                          }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.symmetric(
                        vertical: 3,
                        horizontal: 1,
                      ),
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryRed
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isToday && !isSelected
                            ? Border.all(
                                color: AppColors.primaryRed,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : isPast
                                ? AppColors.divider
                                : isToday
                                ? AppColors.primaryRed
                                : AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          // Done button
          GestureDetector(
            onTap: () => Navigator.pop(context, _DateResult({..._temp})),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryRed, AppColors.darkRed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                _temp.isEmpty
                    ? S.showAllDates
                    : 'Show events for ${_temp.length} selected ${_temp.length == 1 ? 'date' : 'dates'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
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
// Compact event result card (design: EventResultRow)
// ─────────────────────────────────────────────────────────────────────────────

class _WeekEventRow extends StatelessWidget {
  final Event event;
  final Color color;
  final VoidCallback onTap;

  const _WeekEventRow({
    super.key,
    required this.event,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere(
      (c) => c.id == event.clubId,
      orElse: () => clubs.first,
    );
    final live = _isLive(event);
    final canSeeAttendance = canViewEventAttendance(event);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: live
                ? AppColors.primaryRed.withValues(alpha: 0.5)
                : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClubAvatar(
                  clubId: club.id,
                  clubName: club.name,
                  color: color,
                  size: 46,
                  fontSize: 19,
                  shape: 'rounded',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              club.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryText,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (live)
                            const _LiveBadge()
                          else
                            Text(
                              _relativeDay(event.dateTime),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondaryText,
                                letterSpacing: 0.3,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 38.4,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Pill(
                            label: _shortDay(event.dateTime),
                            fg: color,
                            bg: color.withValues(alpha: 0.12),
                          ),
                          if (canSeeAttendance) ...[
                            const SizedBox(width: 7),
                            _Pill(
                              label:
                                  '${event.attendeeUserIds.length} attending',
                              icon: Icons.people_outline,
                              fg: AppColors.secondaryText,
                              bg: Colors.transparent,
                              border: true,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    event.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 5),
                Text(
                  live
                      ? 'Now · ${_timeStr(event.dateTime)}'
                      : _timeStr(event.dateTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  height: 34,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _WeekRsvpPill(event: event),
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

class _Pill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final IconData? icon;
  final bool border;

  const _Pill({
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
    this.border = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: border ? Border.all(color: AppColors.divider) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RSVP pill (design style)
// ─────────────────────────────────────────────────────────────────────────────

class _WeekRsvpPill extends StatelessWidget {
  final Event event;
  const _WeekRsvpPill({required this.event});

  @override
  Widget build(BuildContext context) {
    if (!authService.isStudentSession) return const SizedBox.shrink();

    if (!event.endTime.isAfter(DateTime.now())) {
      return Container(
        width: 92,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          S.ended,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
            letterSpacing: -0.1,
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: rsvpStore,
      builder: (context, _) {
        final userId = authService.currentUser?.id ?? '';
        final attending = rsvpStore.isAttending(event.id);
        return GestureDetector(
          onTap: userId.isEmpty
              ? null
              : () => rsvpStore.toggle(event.id, userId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 92,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: attending
                  ? AppColors.primaryRed.withValues(alpha: 0.10)
                  : AppColors.primaryRed,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: attending
                    ? AppColors.primaryRed.withValues(alpha: 0.3)
                    : AppColors.primaryRed,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (attending) ...[
                  Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      attending ? S.going : S.rsvp,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: attending ? AppColors.primaryRed : Colors.white,
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Live badge (pulsing dot + LIVE)
// ─────────────────────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulseDot(color: AppColors.primaryRed),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryRed,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool searching;
  final VoidCallback onReset;

  const _EmptyState({required this.searching, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                searching ? Icons.search_off_rounded : Icons.event_busy_rounded,
                size: 26,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              S.noEventsFound,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              searching
                  ? S.tryDifferentKeyword
                  : S.nothingScheduled,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onReset,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  S.resetFilters,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
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
// Header icon button (bell)
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback? onTap;

  const _HeaderIconBtn({required this.icon, this.badgeCount = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Icon(icon, size: 18, color: AppColors.secondaryText),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  height: 17,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
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
// New events bottom sheet (opened from the bell)
// ─────────────────────────────────────────────────────────────────────────────

class _NewEventsSheet extends StatelessWidget {
  final List<Event> events;
  final DateTime Function(Event event) createdAtForEvent;
  final ValueChanged<Event> onEventTap;

  const _NewEventsSheet({
    required this.events,
    required this.createdAtForEvent,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.74,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 30,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.newEvents,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                          letterSpacing: -0.6,
                        ),
                      ),
                      Text(
                        '${events.length} unopened ${events.length == 1 ? 'event' : 'events'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: events.isEmpty
                ? const _NoNewEventsState()
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(16, 6, 16, bottom + 18),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return _NewEventNotificationCard(
                        event: event,
                        createdAt: createdAtForEvent(event),
                        onTap: () => onEventTap(event),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoNewEventsState extends StatelessWidget {
  const _NoNewEventsState();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 26, 28, bottom + 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.divider),
            ),
            child: Icon(
              Icons.done_all_rounded,
              color: AppColors.primaryRed,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            S.allCaughtUp,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S.newEventsHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewEventNotificationCard extends StatelessWidget {
  final Event event;
  final DateTime createdAt;
  final VoidCallback onTap;

  const _NewEventNotificationCard({
    required this.event,
    required this.createdAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere(
      (c) => c.id == event.clubId,
      orElse: () => clubs.first,
    );
    final color = _clubColor(event.clubId);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 58,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _kMonths[event.dateTime.month].toUpperCase(),
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
                      fontSize: 23,
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
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _createdLabel(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${club.name} · ${_kWeekdays[event.dateTime.weekday].substring(0, 3)} · ${_timeStr(event.dateTime)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondaryText,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  String _createdLabel(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return 'New';
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
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
