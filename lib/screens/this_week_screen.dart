import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/content_store.dart';
import '../services/event_access.dart';
import '../services/lazy_content_loader.dart';
import '../services/mock_data.dart';
import '../services/moderation_service.dart';
import '../services/rsvp_store.dart';
import '../services/user_state.dart';
import '../services/view_tracker.dart';
import '../onboarding/onboarding_anchors.dart';
import '../widgets/event_cover_image.dart';
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
  final idx = clubOrdinal(clubId);
  return colors[(idx < 0 ? 0 : idx) % colors.length];
}

String _fmt2(int n) => n.toString().padLeft(2, '0');
String _timeStr(DateTime dt) => '${_fmt2(dt.hour)}:${_fmt2(dt.minute)}';

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _shortDay(DateTime d, BuildContext context) {
  if (_isDateToday(d)) return AppLocalizations.of(context)!.today;
  if (_isDateTomorrow(d)) return AppLocalizations.of(context)!.tomorrow;
  return '${DateFormat.E(localeService.languageCode).format(d)} ${d.day}';
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
  /// True only for the instance hosted in the main nav bar's IndexedStack, so
  /// the app tour's RSVP anchor attaches to a single widget — this screen is
  /// also pushed as a route from the home "See all".
  final bool isTutorialHost;

  const ThisWeekScreen({super.key, this.isTutorialHost = false});

  @override
  State<ThisWeekScreen> createState() => _ThisWeekScreenState();
}

class _ThisWeekScreenState extends State<ThisWeekScreen> {
  String _audience = 'all'; // 'all' | 'following'
  Set<String> _dateFilters =
      {}; // empty = any date; else set of day-key strings
  bool _showLive = false;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEventContent();
    localeService.addListener(_onLocaleChanged);
    themeService.addListener(_onLocaleChanged);
    contentStore.addListener(_onContentChanged);
    final now = DateTime.now();
    final userId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    for (final e in events.where(
      (e) =>
          e.endTime.isAfter(now) && !moderationService.isClubBlocked(e.clubId),
    )) {
      rsvpStore.seed(e.id, e.attendeeUserIds.contains(userId));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    localeService.removeListener(_onLocaleChanged);
    themeService.removeListener(_onLocaleChanged);
    contentStore.removeListener(_onContentChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  void _onContentChanged() {
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

  // Rolling two-year pool — excludes fully-past events, keeps live ones.
  List<Event> get _eventPool {
    final now = DateTime.now();
    final endExclusive = DateTime(
      _today.year + 2,
      _today.month,
      _today.day + 1,
    );
    return events
        .where(
          (e) =>
              clubForId(e.clubId) != null &&
              e.endTime.isAfter(now) &&
              e.dateTime.isBefore(endExclusive),
        )
        .toList();
  }

  bool _matchesQuery(Event e, String q) {
    if (e.title.toLowerCase().contains(q)) return true;
    if (e.description.toLowerCase().contains(q)) return true;
    if (e.location.toLowerCase().contains(q)) return true;
    return clubForId(e.clubId)?.name.toLowerCase().contains(q) ?? false;
  }

  List<Event> _results() {
    var list = _eventPool;
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      // Search stays inside the two-year upcoming event window.
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
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
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
        if (moderationService.isClubBlocked(event.clubId)) return false;
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
      setState(() => _dateFilters = result.keys);
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
    final topPad = MediaQuery.paddingOf(context).top;
    final results = _results();
    final newEventCount = _newUnopenedEvents().length;
    final searching = _query.trim().isNotEmpty;
    final hasFilter =
        _audience != 'all' || _dateFilters.isNotEmpty || _showLive;
    final contextLabel = _contextLabel();

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
                            borderRadius: BorderRadius.all(Radius.circular(12)),
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
                            AppLocalizations.of(context)!.discoverEvents,
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
                            S.upcomingEventsHint,
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

            // ── Filter bar: audience · date (multi) · live · clear ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    // Audience
                    Expanded(
                      child: _FilterPillBtn(
                        label: _audience == 'following'
                            ? AppLocalizations.of(context)!.following
                            : AppLocalizations.of(context)!.all,
                        icon: _audience == 'following'
                            ? Icons.favorite_outline_rounded
                            : Icons.people_outline_rounded,
                        active: _audience == 'following',
                        onTap: _showAudienceSheet,
                        expand: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Date (multi-select)
                    Expanded(
                      child: _FilterPillBtn(
                        label: _dateFilters.isEmpty
                            ? AppLocalizations.of(context)!.anyDate
                            : _dateFilters.length == 1
                            ? _shortDay(
                                _dayKeyToDate(_dateFilters.first),
                                context,
                              )
                            : AppLocalizations.of(
                                context,
                              )!.daysCount(_dateFilters.length),
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
                            borderRadius: BorderRadius.all(
                              Radius.circular(100),
                            ),
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
                      AppLocalizations.of(context)!.eventsCount(results.length),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (contextLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          contextLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Results / empty ──
            if (results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  searching: searching,
                  hasFilter: hasFilter,
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
                        // Anchor the tour's "RSVP" step to the first event's
                        // pill — only on the nav-hosted instance.
                        rsvpAnchorKey: (i == 0 && widget.isTutorialHost)
                            ? onboardingAnchors.keyFor(
                                OnboardingAnchors.eventsRsvp,
                              )
                            : null,
                      ),
                    );
                  }, childCount: results.length),
                ),
              ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.paddingOf(context).bottom + 90,
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
    if (q.isNotEmpty) return AppLocalizations.of(context)!.filterQueryLabel(q);
    final parts = <String>[];
    if (_showLive) parts.add(AppLocalizations.of(context)!.liveNowFilterLabel);
    if (_audience == 'following') {
      parts.add(AppLocalizations.of(context)!.followingFilterLabel);
    }
    if (_dateFilters.isNotEmpty) {
      parts.add(
        _dateFilters.length == 1
            ? _shortDay(_dayKeyToDate(_dateFilters.first), context)
            : AppLocalizations.of(context)!.daysCount(_dateFilters.length),
      );
    }
    if (parts.isEmpty) return '';
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
        borderRadius: BorderRadius.all(Radius.circular(14)),
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
                hintText: AppLocalizations.of(context)!.searchEvents,
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

  const _FilterPillBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryRed : AppColors.card,
          borderRadius: BorderRadius.all(Radius.circular(100)),
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
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppColors.secondaryText,
            ),
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
          borderRadius: BorderRadius.all(Radius.circular(100)),
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
              AppLocalizations.of(context)!.live,
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
    final bottom = MediaQuery.paddingOf(context).bottom;
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
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppLocalizations.of(context)!.showEventsFrom,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          _AudienceOption(
            label: AppLocalizations.of(context)!.allEvents,
            subtitle: AppLocalizations.of(context)!.everythingOnCampus,
            icon: Icons.public_outlined,
            selected: current == 'all',
            onTap: () => onPick('all'),
          ),
          const SizedBox(height: 10),
          _AudienceOption(
            label: AppLocalizations.of(context)!.following,
            subtitle: AppLocalizations.of(context)!.followingOnly,
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
          borderRadius: BorderRadius.all(Radius.circular(16)),
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
                borderRadius: BorderRadius.all(Radius.circular(11)),
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
// Date picker bottom sheet — vertically scrolling two-year calendar
// ─────────────────────────────────────────────────────────────────────────────

class _DatePickerSheet extends StatefulWidget {
  final Set<String> selected;

  const _DatePickerSheet({required this.selected});

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late Set<String> _temp;
  final Map<String, GlobalKey> _cellKeys = {};
  String? _pendingDragKey;
  bool? _pendingDragAdding;
  String? _lastDragKey;
  bool? _dragAdding;

  @override
  void initState() {
    super.initState();
    _temp = {...widget.selected};
  }

  DateTime get _todayDate {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _endDate =>
      DateTime(_todayDate.year + 2, _todayDate.month, _todayDate.day);

  List<DateTime> get _months {
    final first = DateTime(_todayDate.year, _todayDate.month);
    final last = DateTime(_endDate.year, _endDate.month);
    final count = (last.year - first.year) * 12 + last.month - first.month + 1;
    return List.generate(count, (index) {
      return DateTime(first.year, first.month + index);
    });
  }

  void _toggleDate(DateTime day) {
    final key = _dayKey(day);
    setState(() {
      if (!_temp.add(key)) _temp.remove(key);
    });
  }

  String? _dayKeyAt(Offset globalPosition) {
    for (final entry in _cellKeys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final local = renderObject.globalToLocal(globalPosition);
      if (local.dx >= 0 &&
          local.dy >= 0 &&
          local.dx <= renderObject.size.width &&
          local.dy <= renderObject.size.height) {
        return entry.key;
      }
    }
    return null;
  }

  bool _isSelectableKey(String key) {
    final date = _dateForKey(key);
    if (date == null) return false;
    return !date.isBefore(_todayDate) && !date.isAfter(_endDate);
  }

  DateTime? _dateForKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  void _handleDateDragDown(Offset globalPosition) {
    final key = _dayKeyAt(globalPosition);
    if (key == null || !_isSelectableKey(key)) {
      _pendingDragKey = null;
      _pendingDragAdding = null;
      return;
    }
    _pendingDragKey = key;
    _pendingDragAdding = !_temp.contains(key);
  }

  void _handleDateDragStart(Offset globalPosition) {
    final startKey = _pendingDragKey;
    final adding = _pendingDragAdding;
    if (startKey == null || adding == null) return;
    _dragAdding = adding;
    _lastDragKey = startKey;
    _applyDragToKey(startKey);
    _handleDateDragUpdate(globalPosition);
  }

  void _handleDateDragUpdate(Offset globalPosition) {
    final key = _dayKeyAt(globalPosition);
    if (_dragAdding == null ||
        key == null ||
        key == _lastDragKey ||
        !_isSelectableKey(key)) {
      return;
    }
    final previousKey = _lastDragKey!;
    _lastDragKey = key;
    _applyDragThroughKeys(previousKey, key);
  }

  void _applyDragToKey(String key) {
    setState(() {
      if (_dragAdding!) {
        _temp.add(key);
      } else {
        _temp.remove(key);
      }
    });
  }

  void _applyDragThroughKeys(String fromKey, String toKey) {
    final from = _dateForKey(fromKey);
    final to = _dateForKey(toKey);
    if (from == null || to == null) return;
    final first = from.isBefore(to) ? from : to;
    final last = from.isBefore(to) ? to : from;

    setState(() {
      for (
        var day = first;
        !day.isAfter(last);
        day = day.add(const Duration(days: 1))
      ) {
        final key = _dayKey(day);
        if (!_isSelectableKey(key)) continue;
        if (_dragAdding!) {
          _temp.add(key);
        } else {
          _temp.remove(key);
        }
      }
    });
  }

  void _endDateDrag() {
    _pendingDragKey = null;
    _pendingDragAdding = null;
    _lastDragKey = null;
    _dragAdding = null;
  }

  String _monthName(BuildContext context, int month) {
    final l10n = AppLocalizations.of(context)!;
    return switch (month) {
      1 => l10n.monthJanuary,
      2 => l10n.monthFebruary,
      3 => l10n.monthMarch,
      4 => l10n.monthApril,
      5 => l10n.monthMay,
      6 => l10n.monthJune,
      7 => l10n.monthJuly,
      8 => l10n.monthAugust,
      9 => l10n.monthSeptember,
      10 => l10n.monthOctober,
      11 => l10n.monthNovember,
      12 => l10n.monthDecember,
      _ => '',
    };
  }

  Widget _buildMonth(BuildContext context, DateTime month) {
    final today = _todayDate;
    final endDate = _endDate;
    final firstDay = DateTime(month.year, month.month);
    final leadingSpaces = firstDay.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final populatedCells = leadingSpaces + daysInMonth;
    final cellCount = ((populatedCells + 6) ~/ 7) * 7;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
            child: Text(
              '${_monthName(context, month.month)} ${month.year}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.25,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 44,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              final dayNumber = index - leadingSpaces + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final day = DateTime(month.year, month.month, dayNumber);
              final isToday = day == today;
              final isDisabled = day.isBefore(today) || day.isAfter(endDate);
              final dayKey = _dayKey(day);
              final isSelected = _temp.contains(dayKey);

              return Semantics(
                label:
                    '${_monthName(context, day.month)} ${day.day}, ${day.year}',
                hint: 'Tap one date or drag horizontally to select a week',
                selected: isSelected,
                enabled: !isDisabled,
                button: true,
                child: GestureDetector(
                  key: ValueKey('event-date-$dayKey'),
                  behavior: HitTestBehavior.opaque,
                  onTap: isDisabled ? null : () => _toggleDate(day),
                  onHorizontalDragDown: isDisabled
                      ? null
                      : (details) =>
                            _handleDateDragDown(details.globalPosition),
                  onHorizontalDragStart: isDisabled
                      ? null
                      : (details) =>
                            _handleDateDragStart(details.globalPosition),
                  onHorizontalDragUpdate: isDisabled
                      ? null
                      : (details) =>
                            _handleDateDragUpdate(details.globalPosition),
                  onHorizontalDragEnd: isDisabled
                      ? null
                      : (_) => _endDateDrag(),
                  onHorizontalDragCancel: isDisabled ? null : _endDateDrag,
                  child: Center(
                    child: AnimatedContainer(
                      key: _cellKeys.putIfAbsent(dayKey, GlobalKey.new),
                      duration: const Duration(milliseconds: 120),
                      width: 38,
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
                      alignment: Alignment.center,
                      child: Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : isDisabled
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
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final months = _months;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
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
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ),
          const SizedBox(height: 18),
          // Title + Clear
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.pickDate,
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
                    AppLocalizations.of(context)!.clear,
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
          Expanded(
            child: ListView.builder(
              key: const PageStorageKey('two-year-event-date-picker'),
              padding: const EdgeInsets.only(top: 2),
              itemCount: months.length,
              itemBuilder: (context, index) =>
                  _buildMonth(context, months[index]),
            ),
          ),
          const SizedBox(height: 12),
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
                borderRadius: BorderRadius.all(Radius.circular(14)),
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
                    ? AppLocalizations.of(context)!.showAllDates
                    : AppLocalizations.of(
                        context,
                      )!.showEventsForSelectedDates(_temp.length),
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

  /// When set, wraps this row's RSVP pill so the app tour can highlight it.
  final Key? rsvpAnchorKey;

  const _WeekEventRow({
    super.key,
    required this.event,
    required this.color,
    required this.onTap,
    this.rsvpAnchorKey,
  });

  String _dateTimeChipLabel(BuildContext context) {
    if (_isLive(event)) {
      return '${AppLocalizations.of(context)!.liveNowLabel} · ${_timeStr(event.dateTime)}';
    }
    if (_isDateToday(event.dateTime)) {
      return '${AppLocalizations.of(context)!.today} · ${_timeStr(event.dateTime)}';
    }
    if (_isDateTomorrow(event.dateTime)) {
      return '${AppLocalizations.of(context)!.tomorrow} · ${_timeStr(event.dateTime)}';
    }
    return '${DateFormat.E(localeService.languageCode).format(event.dateTime)}. ${_timeStr(event.dateTime)}';
  }

  @override
  Widget build(BuildContext context) {
    final live = _isLive(event);
    final canSeeAttendance = canViewEventAttendance(event);
    final rsvpPill = rsvpAnchorKey == null
        ? _WeekRsvpPill(event: event)
        : KeyedSubtree(
            key: rsvpAnchorKey,
            child: _WeekRsvpPill(event: event),
          );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.all(Radius.circular(22)),
          border: Border.all(
            color: live
                ? AppColors.primaryRed.withValues(alpha: 0.5)
                : AppColors.primaryRed.withValues(
                    alpha: themeService.isDark ? 0.34 : 0.18,
                  ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: themeService.isDark ? 0.22 : 0.06,
              ),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EventCoverImage(
                    event: event,
                    color: color,
                    width: double.infinity,
                    height: 150,
                    cacheWidth: 700,
                    cacheHeight: 300,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.46),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 11,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        _dateTimeChipLabel(context),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.94),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                      letterSpacing: -0.42,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          event.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      if (authService.isStudentSession) ...[
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 92,
                          height: 34,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: rsvpPill,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (canSeeAttendance) ...[
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 13,
                            color: color.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.attendingCount(event.attendeeUserIds.length),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: color.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
          borderRadius: BorderRadius.all(Radius.circular(100)),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          AppLocalizations.of(context)!.ended,
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
              borderRadius: BorderRadius.all(Radius.circular(100)),
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
                      attending
                          ? AppLocalizations.of(context)!.going
                          : AppLocalizations.of(context)!.rsvp,
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
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool searching;
  final bool hasFilter;
  final VoidCallback onReset;

  const _EmptyState({
    required this.searching,
    required this.hasFilter,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    // Nothing typed and nothing filtered, yet the list is still empty —
    // that means there simply aren't any upcoming events, not that the
    // user's search/filters excluded everything. Show a friendlier nudge
    // instead of "try a different keyword" / a reset button with nothing
    // to reset.
    final trulyEmpty = !searching && !hasFilter;
    final active = searching || hasFilter;
    final String title = trulyEmpty
        ? AppLocalizations.of(context)!.noEventsYet
        : AppLocalizations.of(context)!.noEventsFound;
    final String subtitle = searching
        ? AppLocalizations.of(context)!.tryDifferentKeyword
        : (hasFilter
              ? AppLocalizations.of(context)!.nothingScheduled
              : AppLocalizations.of(context)!.checkBackLater);

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
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Icon(
                trulyEmpty
                    ? Icons.event_available_rounded
                    : (searching
                          ? Icons.search_off_rounded
                          : Icons.event_busy_rounded),
                size: 26,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
            ),
            if (active) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onReset,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.resetFilters,
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
                  borderRadius: BorderRadius.all(Radius.circular(12)),
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
                    borderRadius: BorderRadius.all(Radius.circular(999)),
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
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.74,
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
              borderRadius: BorderRadius.all(Radius.circular(999)),
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
                    borderRadius: BorderRadius.all(Radius.circular(13)),
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
                        AppLocalizations.of(context)!.newEvents,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                          letterSpacing: -0.6,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.unopenedEventsCount(events.length),
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
    final bottom = MediaQuery.paddingOf(context).bottom;
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
              borderRadius: BorderRadius.all(Radius.circular(22)),
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
            AppLocalizations.of(context)!.allCaughtUp,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.newEventsHint,
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
    final club = clubForId(event.clubId);
    if (club == null) return const SizedBox.shrink();
    final color = _clubColor(event.clubId);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.all(Radius.circular(18)),
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
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.MMM(
                      localeService.languageCode,
                    ).format(event.dateTime).toUpperCase(),
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
                        _createdLabel(context, createdAt),
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
                    '${club.name} · ${DateFormat.E(localeService.languageCode).format(event.dateTime)} · ${_timeStr(event.dateTime)}',
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

  String _createdLabel(BuildContext context, DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return AppLocalizations.of(context)!.justNow;
    if (diff.inMinutes < 60) {
      return AppLocalizations.of(context)!.minutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return AppLocalizations.of(context)!.hoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return AppLocalizations.of(context)!.daysAgo(diff.inDays);
    }
    return AppLocalizations.of(context)!.newLabel;
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
    // Opacity-only repaint of a cached child (visually identical for a solid
    // dot) instead of rebuilding the Container every animation tick.
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
