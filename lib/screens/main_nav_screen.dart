import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/user_state.dart';
import 'feed_screen.dart';
import 'explore_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard.dart';

class MainNavScreen extends StatefulWidget {
  final bool isAdmin;
  final VoidCallback? onLogout;
  const MainNavScreen({super.key, required this.isAdmin, this.onLogout});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;

  void _onNotificationsOpened() {
    setState(() => userState.unreadNotifications = 0);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const FeedScreen(),
      const ExploreScreen(),
      NotificationsScreen(),
      ProfileScreen(onLogout: widget.onLogout),
      if (widget.isAdmin) const AdminDashboard(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: const Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', selected: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
              _NavItem(icon: Icons.search, activeIcon: Icons.search, label: 'Search', selected: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
              _NavItem(
                icon: Icons.notifications_none,
                activeIcon: Icons.notifications,
                label: 'Alerts',
                selected: _selectedIndex == 2,
                badge: userState.unreadNotifications,
                onTap: () {
                  setState(() => _selectedIndex = 2);
                  _onNotificationsOpened();
                },
              ),
              _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', selected: _selectedIndex == 3, onTap: () => setState(() => _selectedIndex = 3)),
              if (widget.isAdmin)
                _NavItem(icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings, label: 'Admin', selected: _selectedIndex == 4, onTap: () => setState(() => _selectedIndex = 4)),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  color: selected ? AppColors.primaryRed : AppColors.secondaryText,
                  size: 26,
                ),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? AppColors.primaryRed : AppColors.secondaryText,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
