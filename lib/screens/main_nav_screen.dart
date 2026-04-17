import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/notification.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import 'chat_screen.dart';
import 'feed_screen.dart';
import 'explore_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard.dart';
import 'campus_map_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const FeedScreen(),
      const ExploreScreen(),
      const CampusMapScreen(),
      NotificationsScreen(),
      ProfileScreen(onLogout: widget.onLogout),
      if (widget.isAdmin) const AdminDashboard(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      floatingActionButton: _isClubAdmin
          ? FloatingActionButton(
              onPressed: () => _openCreateChooser(context),
              backgroundColor: AppColors.primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
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
              _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map', selected: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
              if (_isClubAdmin) const Expanded(child: SizedBox()), // space for centred FAB
              _NavItem(
                icon: Icons.notifications_none,
                activeIcon: Icons.notifications,
                label: 'Alerts',
                selected: _selectedIndex == 3,
                badge: userState.unreadNotifications,
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  _onNotificationsOpened();
                },
              ),
              _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', selected: _selectedIndex == 4, onTap: () => setState(() => _selectedIndex = 4)),
              if (widget.isAdmin)
                _NavItem(icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings, label: 'Admin', selected: _selectedIndex == 5, onTap: () => setState(() => _selectedIndex = 5)),
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

// ─── Create Story Sheet ───────────────────────────────────────────────────────

class _CreateStorySheet extends StatefulWidget {
  final VoidCallback onPosted;
  const _CreateStorySheet({required this.onPosted});

  @override
  State<_CreateStorySheet> createState() => _CreateStorySheetState();
}

class _CreateStorySheetState extends State<_CreateStorySheet> {
  final _textController = TextEditingController();
  String _selectedEmoji = '📢';
  String? _imagePath;
  bool _posting = false;

  static const _emojis = [
    '📢', '🎉', '🔥', '📅', '🏆', '🎓', '💡', '🤝',
    '🎶', '🎨', '⚽', '🧪', '📸', '🌟', '🚀', '❤️',
  ];

  String? get _clubId {
    final admin = authService.currentAdmin;
    if (admin == null) return null;
    try {
      return clubs.firstWhere((c) => c.adminUserIds.contains(admin.id)).id;
    } catch (_) {
      return clubs.isNotEmpty ? clubs.first.id : null;
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) setState(() => _imagePath = picked.path);
  }

  void _showPhotoOptions() {
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
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryRed),
              title: const Text('Take a photo', style: TextStyle(color: AppColors.text)),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryRed),
              title: const Text('Choose from library', style: TextStyle(color: AppColors.text)),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); setState(() => _imagePath = null); },
              ),
          ],
        ),
      ),
    );
  }

  void _post() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final cid = _clubId;
    if (cid == null) return;

    setState(() => _posting = true);

    final story = ClubStory(
      id: 'st_${DateTime.now().millisecondsSinceEpoch}',
      clubId: cid,
      emoji: _selectedEmoji,
      text: text,
      postedAt: DateTime.now(),
      imagePath: _imagePath,
    );
    clubStories.insert(0, story);
    contentStore.saveClubStories();
    widget.onPosted();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.auto_stories_rounded, color: Color(0xFF2E7D32), size: 22),
                const SizedBox(width: 8),
                const Text('Post a Story', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Stories appear at the top of the feed for all followers.',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),

            // Photo picker
            GestureDetector(
              onTap: _showPhotoOptions,
              child: _imagePath != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(File(_imagePath!), height: 140, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8, right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _imagePath = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.lightGray,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF2E7D32), size: 26),
                          SizedBox(width: 8),
                          Text('Add a photo (optional)', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Emoji picker
            const Text('Emoji', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryText, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _emojis.length,
                separatorBuilder: (_, sep) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final e = _emojis[i];
                  final selected = e == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF2E7D32).withValues(alpha: 0.15) : AppColors.lightGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? const Color(0xFF2E7D32) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Text input
            const Text('Story text', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryText, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 3,
              maxLength: 280,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Share an update, announcement, or highlight…',
                hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                filled: true,
                fillColor: AppColors.lightGray,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                ),
                counterStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _textController.text.trim().isEmpty
                      ? AppColors.secondaryText.withValues(alpha: 0.3)
                      : const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _textController.text.trim().isEmpty || _posting ? null : _post,
                icon: _posting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_posting ? 'Posting…' : 'Post Story',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
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
