import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/calendar/providers/calendar_provider.dart';
import '../features/calendar/providers/calendar_state.dart';
import '../models/notification.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import '../services/theme_service.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';
import '../services/tutorial_service.dart';
import '../services/tutorial_anchors.dart';
import '../widgets/app_tutorial_overlay.dart';
import 'chat_screen.dart';
import 'feed_screen.dart';
import 'this_week_screen.dart';
// my_calendar_screen is used from feed_screen, not nav;
import 'explore_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard.dart';
import 'create_event_screen.dart';

class MainNavScreen extends ConsumerStatefulWidget {
  final bool isAdmin;
  final VoidCallback? onLogout;
  const MainNavScreen({super.key, required this.isAdmin, this.onLogout});

  @override
  ConsumerState<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends ConsumerState<MainNavScreen> {
  int _selectedIndex = 0;
  OverlayEntry? _bannerEntry;
  bool _showTutorial = false;

  String get _currentUserId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  @override
  void initState() {
    super.initState();
    userState.incomingMessageNotifier.addListener(_onIncomingMessage);
    tutorialService.replayRequests.addListener(_onTutorialReplayRequested);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _startInitialExperience(),
    );
  }

  // The tour covers the student-facing UI only — it never runs for club admins
  // or the super admin.
  void _startInitialExperience() {
    if (!mounted) return;
    if (authService.isStudentSession &&
        !tutorialService.isComplete(_currentUserId)) {
      _startTutorial();
      return;
    }
    _requestCalendarIfNeeded();
  }

  void _onTutorialReplayRequested() {
    if (!mounted || !authService.isStudentSession) return;
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
  }

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
          'This bar stays with you everywhere: Home, Events, Search, Alerts, and Profile. The active one turns red.',
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
      eyebrow: 'Alerts',
      title: 'Stay in the loop',
      description:
          'Follows, club posts, event changes, and messages collect here. Tap an alert to open it, filter with the chips, or clear them all with this button.',
      icon: Icons.notifications_active_rounded,
      targetKey: tutorialAnchors.keyFor(TutorialAnchors.alertsMarkAllRead),
      tabIndex: 3,
      tips: [
        'A badge on the bar means something’s new.',
        'Opening this tab clears the badge.',
      ],
    ),
    AppTutorialStep(
      eyebrow: 'Profile',
      title: 'This is you',
      description:
          'Tap your photo, name, bio, or interests to edit them so classmates recognize you. Your clubs, RSVPs, and stats live here too.',
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
      title: 'Preferences & replay',
      description:
          'The gear opens Settings — appearance, your interests, and “Replay App Tutorial” whenever you want this tour again.',
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
    userState.incomingMessageNotifier.removeListener(_onIncomingMessage);
    tutorialService.replayRequests.removeListener(_onTutorialReplayRequested);
    _bannerEntry?.remove();
    super.dispose();
  }

  void _onIncomingMessage() {
    final notif = userState.incomingMessageNotifier.value;
    if (notif == null) {
      _bannerEntry?.remove();
      _bannerEntry = null;
      return;
    }
    _showInAppBanner(notif);
  }

  void _showInAppBanner(AppNotification notif) {
    _bannerEntry?.remove();
    _bannerEntry = OverlayEntry(
      builder: (_) => _InAppMessageBanner(
        notification: notif,
        onTap: () {
          _bannerEntry?.remove();
          _bannerEntry = null;
          if (notif.targetId != null) {
            final user = users.firstWhere(
              (u) => u.id == notif.targetId,
              orElse: () => users.first,
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ChatScreen(otherUserId: user.id, otherUserName: user.name),
              ),
            );
          }
        },
        onDismiss: () {
          _bannerEntry?.remove();
          _bannerEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_bannerEntry!);
    // Auto-dismiss after 4 seconds.
    Future.delayed(const Duration(seconds: 4), () {
      _bannerEntry?.remove();
      _bannerEntry = null;
    });
  }

  void _onNotificationsOpened() {
    final currentId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final visible = [
      ...notifications,
      ...userState.dynamicNotifications,
    ].where((n) => n.userId == currentId && n.targetType != 'story');
    userState.markNotificationsRead(visible);
  }

  bool get _isClubAdmin {
    final admin = authService.currentAdmin;
    if (admin == null) return false;
    return admin.id != appAdmin.id; // not the super admin
  }

  void _onAddTap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateEventScreen(onCreated: () => setState(() {})),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeService, localeService]),
      builder: (context, _) {
        // Non-const instances so Flutter creates new widget objects each rebuild,
        // which triggers element.update() → markNeedsBuild() on each screen state.
        final screens = <Widget>[
          FeedScreen(), // 0
          ThisWeekScreen(isTutorialHost: true), // 1
          ExploreScreen(), // 2
          NotificationsScreen(isTutorialHost: true), // 3
          ProfileScreen(onLogout: widget.onLogout), // 4
          if (widget.isAdmin) AdminDashboard(), // 5
        ];

        return Stack(
          children: [
            Scaffold(
              extendBody: true,
              body: IndexedStack(index: _selectedIndex, children: screens),
              bottomNavigationBar: _buildBottomNav(context),
            ),
            if (_showTutorial)
              Positioned.fill(
                child: AppTutorialOverlay(
                  steps: _tutorialSteps,
                  onStepChanged: _onTutorialStepChanged,
                  onComplete: _finishTutorial,
                  onSkip: _finishTutorial,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final currentId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final unreadAlerts = userState.unreadNotificationCountFor(
      [
        ...notifications,
        ...userState.dynamicNotifications,
      ].where((n) => n.userId == currentId && n.targetType != 'story'),
    );
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
        icon: Icons.notifications_none_rounded,
        activeIcon: Icons.notifications_rounded,
        label: S.alerts,
        badge: unreadAlerts,
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
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.09),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.06),
                        ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.24),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
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
                  return Stack(
                    children: [
                      // Soft inner highlight sheen along the top edge.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: isDark ? 0.04 : 0.13,
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
                      if (selectedSlot != -1)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          left: slotWidth * selectedSlot + 6,
                          top: 8,
                          width: slotWidth - 12,
                          height: 72 - 16,
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
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
                                        color: AppColors.primaryRed
                                            .withValues(alpha: 0.16),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
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
                                  ? _CenterAddButton(onTap: _onAddTap)
                                  : _NavItem(
                                      icon: slot.icon!,
                                      activeIcon: slot.activeIcon!,
                                      label: slot.label!,
                                      selected: _selectedIndex == slot.index,
                                      badge: slot.badge,
                                      onTap: () {
                                        setState(
                                          () => _selectedIndex = slot.index!,
                                        );
                                        if (slot.index == 3) {
                                          _onNotificationsOpened();
                                        }
                                      },
                                    ),
                          ],
                        ),
                      ),
                    ],
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

// ─── Center Add Button ────────────────────────────────────────────────────────

class _CenterAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CenterAddButton({required this.onTap});

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

// ─── In-App Message Banner ────────────────────────────────────────────────────

class _InAppMessageBanner extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppMessageBanner({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppMessageBanner> createState() => _InAppMessageBannerState();
}

class _InAppMessageBannerState extends State<_InAppMessageBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final senderName = widget.notification.message.contains(' sent you')
        ? widget.notification.message.split(' sent you').first
        : 'New message';
    final content = widget.notification.message.contains(': "')
        ? widget.notification.message.split(': "').last.replaceAll('"', '')
        : widget.notification.message;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryRed.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.lightRed,
                    ),
                    child: Center(
                      child: Text(
                        senderName.isNotEmpty
                            ? senderName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryRed,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          senderName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet chooser shown when a club admin taps the central +.
/// Pops itself before invoking [onPost] / [onEvent].
void showClubCreateSheet(
  BuildContext context, {
  required VoidCallback onPost,
  required VoidCallback onEvent,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Share something with your club',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _CreateOption(
                    icon: Icons.edit_square,
                    label: 'Post',
                    subtitle: 'Update your community',
                    color: AppColors.primaryRed,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onPost();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CreateOption(
                    icon: Icons.event_rounded,
                    label: 'Event',
                    subtitle: 'Create something inspiring',
                    color: const Color(0xFF1565C0),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onEvent();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _CreateOption extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CreateOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_CreateOption> createState() => _CreateOptionState();
}

class _CreateOptionState extends State<_CreateOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final deep = Color.lerp(color, Colors.black, 0.22)!;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.12),
                color.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, deep],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
