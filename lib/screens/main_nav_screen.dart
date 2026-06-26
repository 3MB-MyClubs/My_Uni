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

  final _contentKey = GlobalKey();
  final _homeHeaderKey = GlobalKey();
  final _homeEventsKey = GlobalKey();
  final _homeFeedKey = GlobalKey();
  final _bottomNavKey = GlobalKey();
  final _homeNavKey = GlobalKey();
  final _eventsNavKey = GlobalKey();
  final _searchNavKey = GlobalKey();
  final _alertsNavKey = GlobalKey();
  final _profileNavKey = GlobalKey();
  final _createNavKey = GlobalKey();
  final _adminNavKey = GlobalKey();

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

  void _startInitialExperience() {
    if (!mounted) return;
    if (!tutorialService.isComplete(_currentUserId)) {
      _startTutorial();
      return;
    }
    _requestCalendarIfNeeded();
  }

  void _onTutorialReplayRequested() {
    if (!mounted) return;
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

  List<AppTutorialStep> get _tutorialSteps {
    final steps = <AppTutorialStep>[
      const AppTutorialStep(
        eyebrow: 'Welcome',
        title: 'Your campus, in one place',
        description:
            'This quick tour uses the real app screens. We will show you where events, clubs, people, alerts, and profile tools live.',
        icon: Icons.waving_hand_rounded,
        tabIndex: 0,
        tips: [
          'Use Next and Back at your own pace.',
          'Skip tour is always available in the top-right corner.',
          'You can replay the full tour later from Settings.',
        ],
      ),
      AppTutorialStep(
        eyebrow: 'Home',
        title: 'Shortcuts and campus updates',
        description:
            'The Home header keeps your calendar, search, and notifications one tap away. Below it, your feed combines updates from clubs you follow with campus recommendations.',
        icon: Icons.home_rounded,
        targetKey: _homeHeaderKey,
        tabIndex: 0,
        tips: [
          'Tap the calendar icon to see everything you are going to.',
          'Tap the search icon to find a person or club quickly.',
          'The bell opens your latest activity.',
        ],
      ),
      AppTutorialStep(
        eyebrow: 'Home events',
        title: 'See what is happening this week',
        description:
            'These event cards show the next campus activities. Tap any card to open its full details before deciding whether to RSVP.',
        icon: Icons.event_available_rounded,
        targetKey: _homeEventsKey,
        tabIndex: 0,
        tips: [
          'Swipe sideways to browse up to ten upcoming events.',
          'Open an event to see its date, time, location, and description.',
          'After you RSVP, it can be added to your personal calendar.',
        ],
      ),
      AppTutorialStep(
        eyebrow: 'Home feed',
        title: 'Follow, RSVP, share, and save',
        description:
            'Switch between Following and All to control your feed. Every post and event has its own actions, and tapping an event opens its details.',
        icon: Icons.dynamic_feed_rounded,
        targetKey: _homeFeedKey,
        tabIndex: 0,
        tips: [
          'Follow clubs to shape the Following feed.',
          'Use RSVP on events and Save on anything you want to revisit.',
          'Share sends a post or event to another student.',
        ],
      ),
      AppTutorialStep(
        eyebrow: 'Events',
        title: 'Plan the week',
        description:
            'The Events tab is your campus agenda. Browse by day, search event names or clubs, and filter the list to clubs you follow.',
        icon: Icons.calendar_month_rounded,
        targetKey: _contentKey,
        tabIndex: 1,
        tips: [
          'Choose a day from the date strip to narrow the agenda.',
          'Tap an event to open details and RSVP.',
          'Going events appear in your personal calendar view.',
        ],
      ),
      if (!_isClubAdmin)
        AppTutorialStep(
          eyebrow: 'Search',
          title: 'Find people and clubs',
          description:
              'Search by a student’s first name, surname, or major, and search clubs by name. Suggested people prioritize useful campus connections.',
          icon: Icons.manage_search_rounded,
          targetKey: _contentKey,
          tabIndex: 2,
          tips: [
            'Type a name or surname to find a specific student.',
            'Open a profile before following to see clubs and interests.',
            'Follow and unfollow directly from search results.',
          ],
        ),
      AppTutorialStep(
        eyebrow: 'Alerts',
        title: 'Keep track of activity',
        description:
            'Alerts collect follow activity, club updates, event changes, message notices, and other account activity in one place.',
        icon: Icons.notifications_active_rounded,
        targetKey: _contentKey,
        tabIndex: 3,
        tips: [
          'Unread activity is marked with a badge in the navigation bar.',
          'Tap an alert to open the related person, message, club, or event.',
          'Opening this tab clears the navigation badge.',
        ],
      ),
      AppTutorialStep(
        eyebrow: 'Profile',
        title: 'Your campus identity',
        description:
            'Your Profile shows your bio, major, interests, clubs, connections, saved content, and upcoming RSVP. Use Settings to edit preferences and appearance.',
        icon: Icons.account_circle_rounded,
        targetKey: _contentKey,
        tabIndex: 4,
        tips: [
          'Edit your profile so classmates know who you are.',
          'Open follower and following lists from the profile counts.',
          'Settings includes preferences, theme, and Replay App Tour.',
        ],
      ),
      AppTutorialStep(
        eyebrow: 'Navigation',
        title: 'Move around from anywhere',
        description:
            'The bottom bar stays available across the main app. The active section turns red, and badges tell you when something needs attention.',
        icon: Icons.touch_app_rounded,
        targetKey: _bottomNavKey,
        tabIndex: 0,
        tips: [
          'Home is your personalized starting point.',
          _isClubAdmin
              ? 'Events, Create, Alerts, and Profile are one tap away.'
              : 'Events and Search are for discovery and planning.',
          'Alerts and Profile keep your activity and identity organized.',
        ],
      ),
    ];

    if (_isClubAdmin) {
      steps.add(
        AppTutorialStep(
          eyebrow: 'Club tools',
          title: 'Publish for your club',
          description:
              'Club posters get this central Create button. It opens a chooser for a club update or a scheduled event.',
          icon: Icons.add_circle_rounded,
          targetKey: _createNavKey,
          tabIndex: 0,
          tips: [
            'Post shares a club update with followers.',
            'Event adds a date, time, location, and RSVP page.',
            'Only the event poster can see attendee totals and the RSVP list.',
          ],
        ),
      );
    }

    if (widget.isAdmin) {
      steps.add(
        AppTutorialStep(
          eyebrow: 'Administration',
          title: 'Manage the wider community',
          description:
              'The Admin area contains platform-level moderation and management tools that are only visible to the super admin.',
          icon: Icons.admin_panel_settings_rounded,
          targetKey: _adminNavKey,
          tabIndex: 5,
          tips: [
            'Review management information from the dedicated dashboard.',
            'Student and club navigation remains available beside it.',
          ],
        ),
      );
    }

    steps.add(
      const AppTutorialStep(
        eyebrow: 'You are ready',
        title: 'Explore at your own pace',
        description:
            'That is the complete map. The tour will not appear automatically again for this account, but you can replay it from Profile → Settings.',
        icon: Icons.rocket_launch_rounded,
        tabIndex: 0,
        tips: [
          'Tap Start exploring to return to Home.',
          'Your follows, RSVPs, saves, and preferences personalize the app.',
        ],
      ),
    );
    return steps;
  }

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
          FeedScreen(
            tutorialHeaderKey: _homeHeaderKey,
            tutorialEventsKey: _homeEventsKey,
            tutorialFeedKey: _homeFeedKey,
          ), // 0
          ThisWeekScreen(), // 1
          ExploreScreen(), // 2
          NotificationsScreen(), // 3
          ProfileScreen(onLogout: widget.onLogout), // 4
          if (widget.isAdmin) AdminDashboard(), // 5
        ];

        return Stack(
          children: [
            Scaffold(
              extendBody: true,
              body: KeyedSubtree(
                key: _contentKey,
                child: IndexedStack(index: _selectedIndex, children: screens),
              ),
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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          key: _bottomNavKey,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.divider.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavItem(
                key: _homeNavKey,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: S.home,
                selected: _selectedIndex == 0,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _NavItem(
                key: _eventsNavKey,
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today_rounded,
                label: S.events,
                selected: _selectedIndex == 1,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              if (!_isClubAdmin)
                _NavItem(
                  key: _searchNavKey,
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search_rounded,
                  label: S.search,
                  selected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
              if (_isClubAdmin)
                _CenterAddButton(key: _createNavKey, onTap: _onAddTap),
              _NavItem(
                key: _alertsNavKey,
                icon: Icons.notifications_none_rounded,
                activeIcon: Icons.notifications_rounded,
                label: S.alerts,
                selected: _selectedIndex == 3,
                badge: unreadAlerts,
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  _onNotificationsOpened();
                },
              ),
              _NavItem(
                key: _profileNavKey,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: S.profile,
                selected: _selectedIndex == 4,
                onTap: () => setState(() => _selectedIndex = 4),
              ),
              if (widget.isAdmin)
                _NavItem(
                  key: _adminNavKey,
                  icon: Icons.admin_panel_settings_outlined,
                  activeIcon: Icons.admin_panel_settings_rounded,
                  label: S.admin,
                  selected: _selectedIndex == 5,
                  onTap: () => setState(() => _selectedIndex = 5),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
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


