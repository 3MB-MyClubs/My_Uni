import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import 'chat_screen.dart';
import 'feed_screen.dart';
import 'this_week_screen.dart';
import 'explore_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard.dart';
import 'create_post_screen.dart';
import 'create_event_screen.dart';
import 'create_story_screen.dart';

class MainNavScreen extends StatefulWidget {
  final bool isAdmin;
  final VoidCallback? onLogout;
  const MainNavScreen({super.key, required this.isAdmin, this.onLogout});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;
  OverlayEntry? _bannerEntry;

  @override
  void initState() {
    super.initState();
    userState.incomingMessageNotifier.addListener(_onIncomingMessage);
  }

  @override
  void dispose() {
    userState.incomingMessageNotifier.removeListener(_onIncomingMessage);
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
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatScreen(
                otherUserId: user.id,
                otherUserName: user.name,
              ),
            ));
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
    setState(() => userState.unreadNotifications = 0);
  }

  bool get _isClubAdmin {
    final admin = authService.currentAdmin;
    if (admin == null) return false;
    return admin.id != appAdmin.id; // not the super admin
  }

  void _openCreateChooser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Text('Create', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _CreateOption(
                    icon: Icons.edit_square,
                    label: 'Post',
                    subtitle: 'Share a photo or update',
                    color: AppColors.primaryRed,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => CreatePostScreen(onPosted: () => setState(() {})),
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CreateOption(
                    icon: Icons.event_rounded,
                    label: 'Event',
                    subtitle: 'Schedule a club event',
                    color: const Color(0xFF1565C0),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => CreateEventScreen(onCreated: () => setState(() {})),
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CreateOption(
                    icon: Icons.auto_stories_rounded,
                    label: 'Story',
                    subtitle: 'Post a club story',
                    color: const Color(0xFF2E7D32),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => CreateStoryScreen(onPosted: () => setState(() {})),
                      ));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onAddTap() {
    _openCreateChooser(context);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const FeedScreen(),
      const ThisWeekScreen(),
      const ExploreScreen(),
      NotificationsScreen(),
      ProfileScreen(onLogout: widget.onLogout),
      if (widget.isAdmin) const AdminDashboard(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                selected: _selectedIndex == 0,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _NavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today_rounded,
                label: 'This Week',
                selected: _selectedIndex == 1,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _NavItem(
                icon: Icons.search_outlined,
                activeIcon: Icons.search_rounded,
                label: 'Search',
                selected: _selectedIndex == 2,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              if (_isClubAdmin) _CenterAddButton(onTap: _onAddTap),
              _NavItem(
                icon: Icons.notifications_none_rounded,
                activeIcon: Icons.notifications_rounded,
                label: 'Alerts',
                selected: _selectedIndex == 3,
                badge: userState.unreadNotifications,
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  _onNotificationsOpened();
                },
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                selected: _selectedIndex == 4,
                onTap: () => setState(() => _selectedIndex = 4),
              ),
              if (widget.isAdmin)
                _NavItem(
                  icon: Icons.admin_panel_settings_outlined,
                  activeIcon: Icons.admin_panel_settings_rounded,
                  label: 'Admin',
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
                      color: selected ? AppColors.primaryRed : AppColors.secondaryText,
                      size: 24,
                    ),
                    if (badge > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryRed,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            badge > 9 ? '9+' : '$badge',
                            style: const TextStyle(
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
                  color: selected ? AppColors.primaryRed : AppColors.secondaryText,
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
              gradient: const LinearGradient(
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
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
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
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
                border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.4)),
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
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.lightRed,
                    ),
                    child: Center(
                      child: Text(
                        senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                        style: const TextStyle(
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
                          style: const TextStyle(
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Icon(Icons.close, size: 16, color: AppColors.secondaryText),
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

class _CreateOption extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 3),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
          ],
        ),
      ),
    );
  }
}
