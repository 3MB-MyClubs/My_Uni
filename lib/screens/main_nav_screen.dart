import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/calendar/providers/calendar_provider.dart';
import '../features/calendar/providers/calendar_state.dart';
import '../services/app_bootstrap.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/mock_data.dart';
import '../services/theme_service.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';
import '../services/push_notification_service.dart';
import '../onboarding/onboarding_anchors.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/onboarding_service.dart';
import '../onboarding/onboarding_steps.dart';
import '../onboarding/starter_checklist_service.dart';
import '../widgets/lazy_indexed_stack.dart';
import 'feed_screen.dart';
import 'this_week_screen.dart';
// my_calendar_screen is used from feed_screen, not nav;
import 'explore_screen.dart';
import 'chats_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard.dart';
import 'create_event_screen.dart';
import 'chat_thread_screen.dart';
import 'club_profile_screen.dart';
import 'event_detail_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

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
      final surface = isDark ? DarkColors.card : Colors.white;
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
                    AppLocalizations.of(sheetContext)!.createSheetTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(sheetContext)!.updateYourCommunity,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppLocalizations.of(sheetContext)!.createSomethingInspiring,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CreateSheetAction(
                    icon: Icons.article_outlined,
                    title: AppLocalizations.of(sheetContext)!.post,
                    subtitle: AppLocalizations.of(
                      sheetContext,
                    )!.shareUpdateWithFollowers,
                    onTap: () => choose(onPost),
                  ),
                  const SizedBox(height: 10),
                  _CreateSheetAction(
                    icon: Icons.event_available_outlined,
                    title: AppLocalizations.of(sheetContext)!.eventLabel,
                    subtitle: AppLocalizations.of(
                      sheetContext,
                    )!.addEventToCampusCalendar,
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

class _MainNavScreenState extends ConsumerState<MainNavScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _showOnboarding = false;
  // True while the current run was requested from Settings, so finishing it
  // doesn't re-trigger the first-run calendar permission prompt.
  bool _isOnboardingReplay = false;
  double? _navDragDx;
  final ChatsController _chatsController = ChatsController();
  final FeedController _feedController = FeedController();
  late final AnimationController _tabTransitionController;

  // Built once and never replaced by nav taps or content-creation callbacks,
  // so IndexedStack sees the same widget instances and Flutter's element-
  // identity fast path skips rebuilding every off-screen tab. Each tab
  // listens for theme/locale changes itself, so this list doesn't need to be
  // rebuilt for that either — only this screen's own chrome (the nav bar)
  // does, via _onThemeOrLocaleChanged below.
  late final List<Widget> _screens = _buildScreens();

  List<Widget> _buildScreens() => <Widget>[
    FeedScreen(controller: _feedController), // 0
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
    _tabTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: 1,
    );
    onboardingService.replayRequests.addListener(_onOnboardingReplayRequested);
    onboardingService.tabRequests.addListener(_onTabRequested);
    pushNotificationService.addListener(_onPushNotificationOpened);
    themeService.addListener(_onThemeOrLocaleChanged);
    localeService.addListener(_onThemeOrLocaleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialExperience();
      unawaited(
        appBootstrap.ready.then((_) {
          if (!mounted) return;
          if (authService.isStudentSession) {
            unawaited(chatStore.startDirectMessageSync(_currentUserId));
          }
        }),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _onPushNotificationOpened(),
    );
  }

  void _onPushNotificationOpened() {
    final target = pushNotificationService.takePendingTarget();
    if (!mounted || target == null) return;
    unawaited(_openPushNotificationTarget(target));
  }

  Future<void> _openPushNotificationTarget(
    PushNotificationTarget target,
  ) async {
    await appBootstrap.ready;
    if (!mounted) return;

    final id = target.targetId;
    switch (target.type) {
      case 'message':
      case 'chat':
        _selectNavIndex(3);
        if (id == null) return;
        if (target.notificationType == 'club_channel_message') {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ChatThreadScreen(threadId: ChatStore.clubThreadId(id)),
            ),
          );
          return;
        }
        if (target.notificationType == 'club_inbox_message') {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ChatThreadScreen(threadId: ChatStore.clubInboxThreadId(id)),
            ),
          );
          return;
        }
        if (ChatStore.isAdminAccountId(_currentUserId)) return;
        final isGroup =
            target.notificationType == 'group_message' ||
            ChatStore.isGroupThread(id);
        final threadId = isGroup
            ? (ChatStore.isGroupThread(id) ? id : 'group:$id')
            : ChatStore.dmThreadId(_currentUserId, id);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatThreadScreen(threadId: threadId),
          ),
        );
      case 'post':
        _selectNavIndex(0);
        if (id == null) return;
        final index = newsPosts.indexWhere((post) => post.id == id);
        if (index < 0) return;
        final post = newsPosts[index];
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              post: post,
              clubColor: _colorForNotificationClub(post.clubId),
            ),
          ),
        );
      case 'event':
        _selectNavIndex(1);
        if (id == null) return;
        final index = events.indexWhere((event) => event.id == id);
        if (index < 0) return;
        final event = events[index];
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(
              event: event,
              color: _colorForNotificationClub(event.clubId),
            ),
          ),
        );
      case 'club':
        _selectNavIndex(2);
        if (id == null) return;
        final club = clubForId(id);
        if (club == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ClubProfileScreen(
              club: club,
              color: _colorForNotificationClub(id),
            ),
          ),
        );
      case 'user':
      case 'profile':
      case 'follow_accepted':
        _selectNavIndex(2);
        if (id == null) return;
        final index = users.indexWhere((user) => user.id == id);
        if (index < 0) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(user: users[index]),
          ),
        );
      default:
        _selectNavIndex(0);
    }
  }

  Color _colorForNotificationClub(String clubId) {
    const colors = <Color>[
      Color(0xFFB41C18),
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFF6A1B9A),
      Color(0xFFE65100),
      Color(0xFF00838F),
    ];
    final ordinal = clubOrdinal(clubId);
    return colors[(ordinal < 0 ? 0 : ordinal) % colors.length];
  }

  void _onThemeOrLocaleChanged() {
    // Only this screen's own chrome (nav bar colors/labels) needs to redraw;
    // _screens is left untouched so the tab bodies aren't force-rebuilt.
    if (mounted) setState(() {});
  }

  // Students get the student tour; club admins get the separate club tour.
  // Neither runs for the super admin.
  void _startInitialExperience() {
    if (!mounted) return;
    if ((authService.isStudentSession || _isClubAdmin) &&
        !onboardingService.isComplete(_currentUserId)) {
      _startOnboarding(isReplay: false);
      return;
    }
    _requestCalendarIfNeeded();
  }

  void _onOnboardingReplayRequested() {
    if (!mounted || !(authService.isStudentSession || _isClubAdmin)) return;
    _startOnboarding(isReplay: true);
  }

  void _onTabRequested() {
    final index = onboardingService.tabRequests.value;
    if (index == null || !mounted) return;
    _selectNavIndex(index);
  }

  void _startOnboarding({required bool isReplay}) {
    setState(() {
      _selectedIndex = 0;
      _showOnboarding = true;
      _isOnboardingReplay = isReplay;
    });
  }

  // The flow starts the animated return Home before invoking this callback;
  // this method owns persistence and the post-tour checklist lifecycle.
  Future<void> _finishOnboarding() async {
    if (!_showOnboarding) return;
    setState(() => _showOnboarding = false);
    await onboardingService.complete(_currentUserId);
    if (!mounted) return;
    if (authService.isStudentSession) {
      await starterChecklistService.startFor(_currentUserId);
    }
    if (mounted && !_isOnboardingReplay) await _requestCalendarIfNeeded();
  }

  void _onOnboardingStepChanged(OnboardingStep step) {
    if (_selectedIndex == step.tabIndex) return;
    _tabTransitionController.forward(from: 0);
    setState(() => _selectedIndex = step.tabIndex);
    if (step.tabIndex == 3) _chatsController.showStudents();
  }

  String get _onboardingFirstName {
    final name =
        authService.currentUser?.name ?? authService.currentAdmin?.name ?? '';
    final parts = name.trim().split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }

  String get _onboardingUserId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

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
    onboardingService.replayRequests.removeListener(
      _onOnboardingReplayRequested,
    );
    onboardingService.tabRequests.removeListener(_onTabRequested);
    pushNotificationService.removeListener(_onPushNotificationOpened);
    themeService.removeListener(_onThemeOrLocaleChanged);
    localeService.removeListener(_onThemeOrLocaleChanged);
    _chatsController.dispose();
    _feedController.dispose();
    _tabTransitionController.dispose();
    super.dispose();
  }

  // Chat unreads clear per-thread when a conversation is opened (see
  // ChatThreadScreen), so unlike the old Alerts tab there's nothing to
  // mark read when the Chats tab itself is selected.
  void _selectNavIndex(int index) {
    if (index == 0 && _selectedIndex == 0) {
      _feedController.scrollToTop();
      return;
    }
    if (index == 3) _chatsController.showStudents();
    if (_selectedIndex != index) {
      if (_showOnboarding) _tabTransitionController.forward(from: 0);
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
            body: AnimatedBuilder(
              animation: _tabTransitionController,
              child: LazyIndexedStack(
                index: _selectedIndex,
                children: _screens,
              ),
              builder: (context, child) {
                final motion = Curves.easeOutCubic.transform(
                  _tabTransitionController.value,
                );
                return Opacity(
                  opacity: 0.88 + (0.12 * motion),
                  child: Transform.scale(
                    scale: 0.985 + (0.015 * motion),
                    child: child,
                  ),
                );
              },
            ),
            // ChatStore can notify for message delivery, read receipts,
            // typing state, and sync progress. Only the unread badge depends
            // on those updates, so keep them from rebuilding the mounted tab
            // stack and the rest of this scaffold.
            bottomNavigationBar: ListenableBuilder(
              listenable: chatStore,
              builder: (context, _) => _buildBottomNav(context),
            ),
          ),
          if (_showOnboarding)
            Positioned.fill(
              child: OnboardingFlow(
                steps: _isClubAdmin
                    ? clubAdminOnboardingSteps()
                    : studentOnboardingSteps(),
                userId: _onboardingUserId,
                firstName: _onboardingFirstName,
                showChecklist: authService.isStudentSession,
                onStepChanged: _onOnboardingStepChanged,
                onComplete: _finishOnboarding,
                onSkip: _finishOnboarding,
                onNavigateHome: () => _selectNavIndex(0),
                onDeepLink: _selectNavIndex,
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
        label: AppLocalizations.of(context)!.home,
      ),
      _NavSlot(
        index: 1,
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today_rounded,
        label: AppLocalizations.of(context)!.events,
      ),
      if (!_isClubAdmin)
        _NavSlot(
          index: 2,
          icon: Icons.search_outlined,
          activeIcon: Icons.search_rounded,
          label: AppLocalizations.of(context)!.search,
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
        label: AppLocalizations.of(context)!.profile,
      ),
      if (widget.isAdmin)
        _NavSlot(
          index: 5,
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings_rounded,
          label: AppLocalizations.of(context)!.admin,
        ),
    ];

    final slotCount = slots.length;
    final selectedSlot = slots.indexWhere((s) => s.index == _selectedIndex);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: ClipRRect(
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
                                        key: onboardingAnchors.keyFor(
                                          OnboardingAnchors.clubCreateButton,
                                        ),
                                        onTap: _onAddTap,
                                      )
                                    : _NavItem(
                                        // The super-admin Dashboard slot (5) has
                                        // no tour step, and reusing navProfile
                                        // there would mount one GlobalKey twice.
                                        key: switch (slot.index!) {
                                          0 => onboardingAnchors.keyFor(
                                            OnboardingAnchors.navHome,
                                          ),
                                          1 => onboardingAnchors.keyFor(
                                            OnboardingAnchors.navEvents,
                                          ),
                                          2 => onboardingAnchors.keyFor(
                                            OnboardingAnchors.navSearch,
                                          ),
                                          3 => onboardingAnchors.keyFor(
                                            OnboardingAnchors.navChats,
                                          ),
                                          4 => onboardingAnchors.keyFor(
                                            OnboardingAnchors.navProfile,
                                          ),
                                          _ => null,
                                        },
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
    super.key,
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
