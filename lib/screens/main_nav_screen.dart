import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/calendar/providers/calendar_provider.dart';
import '../features/calendar/providers/calendar_state.dart';
import '../services/app_bootstrap.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/mock_data.dart';
import '../services/theme_service.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';
import '../services/tutorial_service.dart';
import '../services/tutorial_anchors.dart';
import '../widgets/app_tutorial_overlay.dart';
import '../widgets/lazy_indexed_stack.dart';
import 'feed_screen.dart';
import 'this_week_screen.dart';
// my_calendar_screen is used from feed_screen, not nav;
import 'explore_screen.dart';
import 'chats_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard.dart';
import 'create_event_screen.dart';

/// Presents the older club-admin create chooser used by visual drive tests and
/// any explicit callers that still need a Post/Event split.
///
/// The center nav "+" does not call this helper anymore; it opens event
/// creation directly.
Future<void> showClubCreateSheet(
  BuildContext context, {
  required VoidCallback onPost,
  required VoidCallback onEvent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final isDark = theme.brightness == Brightness.dark;
      final surface = isDark ? const Color(0xFF16181D) : Colors.white;
      final primaryText = isDark ? Colors.white : AppColors.text;
      final secondaryText = isDark
          ? Colors.white.withValues(alpha: 0.68)
          : AppColors.secondaryText;

      void choose(VoidCallback callback) {
        Navigator.of(sheetContext).pop();
        callback();
      }

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.all(Radius.circular(28)),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: secondaryText.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Create',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Update your community',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Create something inspiring',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CreateSheetAction(
                    icon: Icons.article_outlined,
                    title: 'Post',
                    subtitle: 'Share an update with your followers',
                    onTap: () => choose(onPost),
                  ),
                  const SizedBox(height: 10),
                  _CreateSheetAction(
                    icon: Icons.event_available_outlined,
                    title: 'Event',
                    subtitle: 'Add an event to the campus calendar',
                    onTap: () => choose(onEvent),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class MainNavScreen extends ConsumerStatefulWidget {
  final bool isAdmin;
  final VoidCallback? onLogout;
  const MainNavScreen({super.key, required this.isAdmin, this.onLogout});

  @override
  ConsumerState<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends ConsumerState<MainNavScreen> {
  int _selectedIndex = 0;
  bool _showTutorial = false;
  double? _navDragDx;
  final ChatsController _chatsController = ChatsController();

  // Built once and never replaced by nav taps or content-creation callbacks,
  // so IndexedStack sees the same widget instances and Flutter's element-
  // identity fast path skips rebuilding every off-screen tab. Each tab
  // listens for theme/locale changes itself, so this list doesn't need to be
  // rebuilt for that either — only this screen's own chrome (the nav bar)
  // does, via _onThemeOrLocaleChanged below.
  late final List<Widget> _screens = _buildScreens();

  List<Widget> _buildScreens() => <Widget>[
    FeedScreen(), // 0
    ThisWeekScreen(isTutorialHost: true), // 1
    ExploreScreen(), // 2
    ChatsScreen(isTutorialHost: true, controller: _chatsController), // 3
    ProfileScreen(onLogout: () => widget.onLogout?.call()), // 4
    if (widget.isAdmin) AdminDashboard(), // 5
  ];

  String get _currentUserId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  @override
  void initState() {
    super.initState();
    tutorialService.replayRequests.addListener(_onTutorialReplayRequested);
    themeService.addListener(_onThemeOrLocaleChanged);
    localeService.addListener(_onThemeOrLocaleChanged);
    // Keeps the Chats badge live when a message arrives on another screen.
    chatStore.addListener(_onThemeOrLocaleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialExperience();
      // One MainNavScreen State per login session, and userPrefsService.load
      // has already restored followedClubIds by the time boxes are ready — so
      // this seeds the demo DM threads for whoever just logged in, before the
      // lazily-built Chats tab first opens.
      unawaited(
        appBootstrap.ready.then((_) {
          if (!mounted) return;
          chatStore.ensureSeededFor(_currentUserId);
          if (authService.isStudentSession) {
            unawaited(chatStore.startDirectMessageSync(_currentUserId));
          }
        }),
      );
    });
  }

  void _onThemeOrLocaleChanged() {
    // Only this screen's own chrome (nav bar colors/labels) needs to redraw;
    // _screens is left untouched so the tab bodies aren't force-rebuilt.
    if (mounted) setState(() {});
  }

  // Students get the student tour; club admins get the separate club tour
  // (_clubTutorialSteps). Neither runs for the super admin.
  void _startInitialExperience() {
    if (!mounted) return;
    if ((authService.isStudentSession || _isClubAdmin) &&
        !tutorialService.isComplete(_currentUserId)) {
      _startTutorial();
      return;
    }
    _requestCalendarIfNeeded();
  }

  void _onTutorialReplayRequested() {
    if (!mounted || !(authService.isStudentSession || _isClubAdmin)) return;
    _startTutorial();
  }

  void _startTutorial() {
    setState(() {
      _selectedIndex = 0;
      _showTutorial = true;
    });
  }

  Future<void> _finishTutorial() async {
    if (!_showTutorial) return;
    setState(() {
      _showTutorial = false;
      _selectedIndex = 0;
    });
    await tutorialService.complete(_currentUserId);
    if (mounted) await _requestCalendarIfNeeded();
  }

  void _onTutorialStepChanged(AppTutorialStep step) {
    if (_selectedIndex == step.tabIndex) return;
    setState(() => _selectedIndex = step.tabIndex);
    if (step.tabIndex == 3) _chatsController.showStudents();
  }

  // Whichever tour applies to the current session. Kept as a single getter so
  // build() and the orchestration methods don't need to branch themselves.
  List<AppTutorialStep> get _activeTutorialSteps =>
      _isClubAdmin ? _clubTutorialSteps : _tutorialSteps;

  // Student-only walkthrough. Each anchored step points at the real widget via
  // a shared key from [tutorialAnchors]; welcome/finale are centered heroes.
  List<AppTutorialStep> get _tutorialSteps => <AppTutorialStep>[
    const AppTutorialStep(
      eyebrow: 'Welcome',
      title: 'Your campus, in one place',
      description:
          'A quick, tappable tour of the app — we’ll point to the real buttons as we go.',
      icon: Icons.waving_hand_rounded,
      tabIndex: 0,
      tips: [
        'Tap Next, or tap anywhere, to advance.',
        'Use Back to revisit a step.',
        'Skip tour is always in the top-right.',
      ],
    ),
    AppTutorialStep(
      eyebrow: 'Getting around',
      title: 'Your five sections',
      description:
          'This bar stays with you everywhere: Home, Events, Search, Chats, and Profile. The active one turns red.',
      icon: Icons.touch_app_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.navBar),
      tabIndex: 0,
      tips: ['Home is your personalized feed.', 'Badges flag new activity.'],
    ),
    AppTutorialStep(
      eyebrow: 'Home',
      title: 'Your feed, your way',
      description:
          'Switch between Following and All to control what you see. Like, RSVP, save, and share right from each post.',
      icon: Icons.dynamic_feed_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.homeFeedToggle),
      tabIndex: 0,
      tips: [
        'Following shows only clubs you follow.',
        'All mixes in campus recommendations.',
      ],
    ),
    AppTutorialStep(
      eyebrow: 'Events',
      title: 'RSVP in one tap',
      description:
          'Tap RSVP to mark you’re going — it turns to “Going” and can flow into your calendar. Search and filter the agenda up top.',
      icon: Icons.event_available_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.eventsRsvp),
      tabIndex: 1,
      tips: [
        'Filter by date, audience, or what’s live now.',
        'Open any event for full details.',
      ],
    ),
    AppTutorialStep(
      eyebrow: 'Search',
      title: 'Find people & clubs',
      description:
          'Search students by name or major, and clubs by name. Use the tabs above to switch between People and Clubs.',
      icon: Icons.manage_search_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.searchField),
      tabIndex: 2,
      tips: [
        'Follow people and join clubs from the results.',
        'Open a profile before you follow.',
      ],
    ),
    AppTutorialStep(
      eyebrow: 'Chats',
      title: 'Message your people',
      description:
          'Direct messages and your clubs’ group chats live here. Every club you join gets a members-only room — and this button starts a new DM.',
      icon: Icons.chat_bubble_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.chatsCompose),
      tabIndex: 3,
      tips: [
        'A badge on the bar means new messages.',
        'Notifications moved to the bell on Home.',
      ],
    ),
    AppTutorialStep(
      eyebrow: 'Profile',
      title: 'This is you',
      description:
          'Tap your photo, name, or bio to edit them so classmates recognize you. Your clubs, RSVPs, and stats live here too.',
      icon: Icons.account_circle_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.profileHeader),
      tabIndex: 4,
      tips: [
        'Tap Followers / Following to see who’s who.',
        'Your “Up next” event is one tap away.',
      ],
    ),
    AppTutorialStep(
      eyebrow: 'Settings',
      title: 'Appearance & replay',
      description:
          'The gear opens Settings — appearance and “Replay App Tutorial” whenever you want this tour again.',
      icon: Icons.settings_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.profileSettings),
      tabIndex: 4,
      tips: ['Switch between light and dark mode here.'],
    ),
    const AppTutorialStep(
      eyebrow: 'You’re set',
      title: 'Explore at your own pace',
      description:
          'That’s the tour. It won’t pop up again automatically — replay it anytime from Profile → Settings.',
      icon: Icons.rocket_launch_rounded,
      tabIndex: 0,
      tips: ['Your follows, RSVPs, and saves personalize the app.'],
    ),
  ];

  // Club-admin walkthrough. Separate from _tutorialSteps because clubs get a
  // different nav (no Search tab, a center "+" instead) and a different
  // Profile tab (ClubProfileScreen, not personal info).
  List<AppTutorialStep> get _clubTutorialSteps => <AppTutorialStep>[
    const AppTutorialStep(
      eyebrow: 'Welcome',
      title: 'Run your club from here',
      description:
          'A quick tour of the tools you get as a club admin — we’ll point to the real buttons as we go.',
      icon: Icons.waving_hand_rounded,
      tabIndex: 0,
      tips: [
        'Tap Next, or tap anywhere, to advance.',
        'Skip tour is always in the top-right.',
      ],
    ),
    AppTutorialStep(
      eyebrow: 'Getting around',
      title: 'Your four sections',
      description:
          'Home, Events, Chats, and Profile stay with you everywhere. The center button replaces Search — it’s reserved for posting.',
      icon: Icons.touch_app_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.navBar),
      tabIndex: 0,
      tips: ['The active section turns red.', 'Badges flag new activity.'],
    ),
    AppTutorialStep(
      eyebrow: 'Create',
      title: 'Post a new event',
      description:
          'Tap the center button anytime to open the event form — title, time, location, and audience.',
      icon: Icons.add_circle_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.clubCreateButton),
      tabIndex: 0,
      tips: ['Your event shows up in Events for everyone right away.'],
    ),
    AppTutorialStep(
      eyebrow: 'Home',
      title: 'Quick text updates',
      description:
          'This composer posts a quick update to your club’s followers — no need for the full event form for a text-only post.',
      icon: Icons.dynamic_feed_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.clubQuickComposer),
      tabIndex: 0,
      tips: ['Add a photo for a bigger, more visible post.'],
    ),
    AppTutorialStep(
      eyebrow: 'Your club',
      title: 'Posts, Events, Collabs, Board',
      description:
          'This is your club’s public profile. Switch tabs to manage posts and events — tap the ⋯ menu on any of yours to pin or delete it, or tap an event’s attendee count to see who’s coming.',
      icon: Icons.view_agenda_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.clubProfileTabs),
      tabIndex: 4,
      tips: [
        'Board lists your club’s board members and titles.',
        'Collabs shows joint events with other clubs.',
      ],
    ),
    AppTutorialStep(
      eyebrow: 'Insights',
      title: 'See what’s landing',
      description:
          'Track views, likes, and top posts so you know what your followers respond to.',
      icon: Icons.insights_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.clubInsights),
      tabIndex: 4,
    ),
    AppTutorialStep(
      eyebrow: 'Settings',
      title: 'Board, appearance & replay',
      description:
          'The gear opens Settings — add or remove board members, switch appearance, and replay this tour whenever you want.',
      icon: Icons.settings_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.clubProfileSettings),
      tabIndex: 4,
      tips: ['Board management lives under your club’s section in Settings.'],
    ),
    const AppTutorialStep(
      eyebrow: 'Chats',
      title: 'Talk with your members',
      description:
          'Chats opens your club’s single shared community room. Talk with members there, answer questions, and share plans; club-admin accounts do not use direct messages.',
      icon: Icons.chat_bubble_rounded,
      tabIndex: 3,
    ),
    const AppTutorialStep(
      eyebrow: 'You’re set',
      title: 'Run your club at your own pace',
      description:
          'That’s the tour. It won’t pop up again automatically — replay it anytime from Profile → Settings.',
      icon: Icons.rocket_launch_rounded,
      tabIndex: 0,
    ),
  ];

  Future<void> _requestCalendarIfNeeded() async {
    final service = ref.read(calendarServiceProvider);
    final permission = await service.checkPermission();
    if (!mounted) return;
    if (permission == CalendarPermissionState.granted ||
        permission == CalendarPermissionState.permanentlyDenied ||
        permission == CalendarPermissionState.restricted) {
      return;
    }
    await service.requestPermission();
  }

  @override
  void dispose() {
    tutorialService.replayRequests.removeListener(_onTutorialReplayRequested);
    themeService.removeListener(_onThemeOrLocaleChanged);
    localeService.removeListener(_onThemeOrLocaleChanged);
    chatStore.removeListener(_onThemeOrLocaleChanged);
    _chatsController.dispose();
    super.dispose();
  }

  // Chat unreads clear per-thread when a conversation is opened (see
  // ChatThreadScreen), so unlike the old Alerts tab there's nothing to
  // mark read when the Chats tab itself is selected.
  void _selectNavIndex(int index) {
    if (index == 3) _chatsController.showStudents();
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  void _handleNavDragPosition(
    Offset localPosition,
    double barWidth,
    List<_NavSlot> slots,
  ) {
    if (slots.isEmpty || barWidth <= 0) return;

    final clampedDx = localPosition.dx.clamp(0.0, barWidth).toDouble();
    final slotWidth = barWidth / slots.length;
    final slotIndex = (clampedDx / slotWidth).floor().clamp(
      0,
      slots.length - 1,
    );
    final navIndex = slots[slotIndex].index;
    final enteringChats = navIndex == 3 && _selectedIndex != 3;

    setState(() {
      _navDragDx = clampedDx;
      if (navIndex != null) {
        _selectedIndex = navIndex;
      }
    });
    if (enteringChats) _chatsController.showStudents();
  }

  void _endNavDrag() {
    if (_navDragDx == null) return;
    setState(() => _navDragDx = null);
  }

  bool get _isClubAdmin {
    final admin = authService.currentAdmin;
    if (admin == null) return false;
    return admin.id != appAdmin.id; // not the super admin
  }

  void _openCreateEvent() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        // FeedScreen/ThisWeekScreen refresh themselves via contentStore's
        // change notification — no need to rebuild this screen too.
        builder: (_) => const CreateEventScreen(),
      ),
    );
  }

  // The center "+" is event-creation only — club admins post from the quick
  // composer inline in their feed instead, so this button skips straight to
  // the event form rather than asking Post-or-Event first.
  void _onAddTap() => _openCreateEvent();

  @override
  Widget build(BuildContext context) {
    // BackdropGroup lets the nav bar's and the feed top bar's grouped blurs
    // share a single backdrop readback per frame instead of one each.
    return BackdropGroup(
      child: Stack(
        children: [
          Scaffold(
            extendBody: true,
            body: LazyIndexedStack(index: _selectedIndex, children: _screens),
            bottomNavigationBar: _buildBottomNav(context),
          ),
          if (_showTutorial)
            Positioned.fill(
              child: AppTutorialOverlay(
                steps: _activeTutorialSteps,
                onStepChanged: _onTutorialStepChanged,
                onComplete: _finishTutorial,
                onSkip: _finishTutorial,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final currentId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final unreadChats = chatStore.totalUnreadFor(currentId);
    final isDark = themeService.isDark;

    // Ordered slots so the sliding highlight can be positioned purely from
    // list index, regardless of which tabs are hidden for admins.
    final slots = <_NavSlot>[
      _NavSlot(
        index: 0,
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: S.home,
      ),
      _NavSlot(
        index: 1,
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today_rounded,
        label: S.events,
      ),
      if (!_isClubAdmin)
        _NavSlot(
          index: 2,
          icon: Icons.search_outlined,
          activeIcon: Icons.search_rounded,
          label: S.search,
        ),
      if (_isClubAdmin) const _NavSlot.center(),
      _NavSlot(
        index: 3,
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label: S.chats,
        badge: unreadChats,
      ),
      _NavSlot(
        index: 4,
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: S.profile,
      ),
      if (widget.isAdmin)
        _NavSlot(
          index: 5,
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings_rounded,
          label: S.admin,
        ),
    ];

    final slotCount = slots.length;
    final selectedSlot = slots.indexWhere((s) => s.index == _selectedIndex);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: ClipRRect(
          key: tutorialAnchors.keyFor(TutorialAnchors.navBar),
          borderRadius: BorderRadius.all(Radius.circular(30)),
          child: BackdropFilter.grouped(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(30)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: 0.008),
                          Colors.black.withValues(alpha: 0.015),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.03),
                          Colors.white.withValues(alpha: 0.01),
                        ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.10),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
                    blurRadius: 32,
                    spreadRadius: 0,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth;
                  final slotWidth = slotCount > 0
                      ? barWidth / slotCount
                      : barWidth;
                  final isNavDragging = _navDragDx != null;
                  final capsuleWidth = slotWidth - 12;
                  final capsuleLeft = isNavDragging
                      ? (_navDragDx! - capsuleWidth / 2)
                            .clamp(6.0, barWidth - capsuleWidth - 6)
                            .toDouble()
                      : slotWidth * selectedSlot + 6;
                  final underlineLeft = isNavDragging
                      ? (_navDragDx! - slotWidth / 2)
                            .clamp(0.0, barWidth - slotWidth)
                            .toDouble()
                      : slotWidth * selectedSlot;

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPressStart: (details) => _handleNavDragPosition(
                      details.localPosition,
                      barWidth,
                      slots,
                    ),
                    onLongPressMoveUpdate: (details) => _handleNavDragPosition(
                      details.localPosition,
                      barWidth,
                      slots,
                    ),
                    onLongPressEnd: (_) => _endNavDrag(),
                    onLongPressCancel: _endNavDrag,
                    child: Stack(
                      children: [
                        // Soft inner highlight sheen along the top edge.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(30),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: isDark ? 0.015 : 0.04,
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.55],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Brighter glass capsule sliding under the selected tab.
                        // No blur here (that's still on the outer bar) — a
                        // solid-ish highlight is visually close at a fraction
                        // of the compositing cost of two stacked BackdropFilters.
                        if (selectedSlot != -1)
                          AnimatedPositioned(
                            duration: isNavDragging
                                ? Duration.zero
                                : const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            left: capsuleLeft,
                            top: 8,
                            width: capsuleWidth,
                            height: 72 - 16,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(22),
                                  ),
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.white.withValues(alpha: 0.36),
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha: isDark ? 0.17 : 0.52,
                                    ),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryRed.withValues(
                                        alpha: 0.16,
                                      ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        // Thin maroon underline with a soft glow, sliding in
                        // step with the capsule above.
                        if (selectedSlot != -1)
                          AnimatedPositioned(
                            duration: isNavDragging
                                ? Duration.zero
                                : const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            left: underlineLeft,
                            bottom: 6,
                            width: slotWidth,
                            height: 3,
                            child: IgnorePointer(
                              child: Center(
                                child: Container(
                                  width: 22,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(100),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryRed.withValues(
                                          alpha: 0.55,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Foreground row of nav items.
                        Positioned.fill(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (final slot in slots)
                                slot.isCenterButton
                                    ? _CenterAddButton(
                                        key: tutorialAnchors.keyFor(
                                          TutorialAnchors.clubCreateButton,
                                        ),
                                        onTap: _onAddTap,
                                      )
                                    : _NavItem(
                                        icon: slot.icon!,
                                        activeIcon: slot.activeIcon!,
                                        label: slot.label!,
                                        selected: _selectedIndex == slot.index,
                                        badge: slot.badge,
                                        onTap: () =>
                                            _selectNavIndex(slot.index!),
                                      ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Describes one position in the bottom nav row — either a selectable tab
/// or the club-admin center "add" button, which has no selection state.
class _NavSlot {
  final int? index;
  final IconData? icon;
  final IconData? activeIcon;
  final String? label;
  final int badge;
  final bool isCenterButton;

  _NavSlot({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
  }) : isCenterButton = false;

  const _NavSlot.center()
    : index = null,
      icon = null,
      activeIcon = null,
      label = null,
      badge = 0,
      isCenterButton = true;
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: selected ? 1.0 : 0.82,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        selected ? activeIcon : icon,
                        color: selected
                            ? AppColors.primaryRed
                            : AppColors.secondaryText,
                        size: 24,
                      ),
                      if (badge > 0)
                        Positioned(
                          top: -4,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(
                              minWidth: 15,
                              minHeight: 15,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              badge > 9 ? '9+' : '$badge',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? AppColors.primaryRed
                      : AppColors.secondaryText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateSheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateSheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.text;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.64)
        : AppColors.secondaryText;

    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : AppColors.lightRed.withValues(alpha: 0.55),
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.14),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                ),
                child: Icon(icon, color: AppColors.primaryRed, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: subtitleColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Center Add Button ────────────────────────────────────────────────────────

class _CenterAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CenterAddButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryRed, AppColors.darkRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withValues(alpha: 0.55),
                  blurRadius: 18,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
