import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'club_profile_screen.dart';
import 'event_detail_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _read = {};

  int get _unreadCount {
    final currentId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final all = [...notifications, ...userState.dynamicNotifications]
        .where((n) => n.userId == currentId);
    return all.where((n) => !_read.contains(n.id)).length;
  }

  void _markAllRead() => setState(() {
        _read.addAll(notifications.map((n) => n.id));
        userState.unreadNotifications = 0;
      });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _isYesterday(DateTime dt) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
  }

  bool _isThisWeek(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dtDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(dtDay).inDays;
    return diff >= 2 && diff <= 6;
  }

  bool _isThisMonth(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dtDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(dtDay).inDays;
    return diff >= 7 && dt.year == now.year && dt.month == now.month;
  }

  static const List<Color> _clubColors = [
    Color(0xFFB41C18), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  Color _colorForClub(String clubId) {
    final idx = clubs.indexWhere((c) => c.id == clubId);
    return _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
  }

  void _navigate(BuildContext context, AppNotification n) {
    final type = n.targetType;
    final id = n.targetId;
    if (type == null || id == null) return;

    switch (type) {
      case 'post':
        final post = newsPosts.firstWhere((p) => p.id == id, orElse: () => newsPosts.first);
        final color = _colorForClub(post.clubId);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PostDetailScreen(post: post, clubColor: color),
        ));
      case 'club':
        final club = clubs.firstWhere((c) => c.id == id, orElse: () => clubs.first);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ClubProfileScreen(club: club, color: _colorForClub(id)),
        ));
      case 'event':
        final event = events.firstWhere((e) => e.id == id, orElse: () => events.first);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event, color: _colorForClub(event.clubId)),
        ));
      case 'user':
        final user = users.firstWhere((u) => u.id == id, orElse: () => users.first);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => UserProfileScreen(user: user),
        ));
      case 'message':
        final sender = users.firstWhere((u) => u.id == id, orElse: () => users.first);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatScreen(otherUserId: sender.id, otherUserName: sender.name),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show notifications addressed to the currently logged-in user/admin.
    final currentId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final all = [...notifications, ...userState.dynamicNotifications]
        .where((n) => n.userId == currentId)
        .toList();
    final sorted = all..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final today     = sorted.where((n) => _isToday(n.createdAt)).toList();
    final yesterday = sorted.where((n) => _isYesterday(n.createdAt)).toList();
    final thisWeek  = sorted.where((n) => _isThisWeek(n.createdAt)).toList();
    final thisMonth = sorted.where((n) => _isThisMonth(n.createdAt)).toList();
    final thisYear  = sorted.where((n) {
      final now = DateTime.now();
      final today0 = DateTime(now.year, now.month, now.day);
      final dtDay = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      final diff = today0.difference(dtDay).inDays;
      return diff >= 0 && n.createdAt.year == now.year &&
          !_isToday(n.createdAt) && !_isYesterday(n.createdAt) &&
          !_isThisWeek(n.createdAt) && !_isThisMonth(n.createdAt);
    }).toList();
    final older = sorted.where((n) => n.createdAt.year < DateTime.now().year).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) setState(() {});
        },
        color: AppColors.primaryRed,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(),
            if (all.isEmpty)
              const SliverFillRemaining(child: _EmptyState())
            else ...[
              if (today.isNotEmpty) ...[
                _SectionHeader(title: 'Today', count: today.where((n) => !_read.contains(n.id)).length),
                _buildGroup(today),
              ],
              if (yesterday.isNotEmpty) ...[
                _SectionHeader(title: 'Yesterday'),
                _buildGroup(yesterday),
              ],
              if (thisWeek.isNotEmpty) ...[
                _SectionHeader(title: 'This Week'),
                _buildGroup(thisWeek),
              ],
              if (thisMonth.isNotEmpty) ...[
                _SectionHeader(title: 'This Month'),
                _buildGroup(thisMonth),
              ],
              if (thisYear.isNotEmpty) ...[
                _SectionHeader(title: 'This Year'),
                _buildGroup(thisYear),
              ],
              if (older.isNotEmpty) ...[
                _SectionHeader(title: 'Older'),
                _buildGroup(older),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryRed, Color(0xFFB71C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (_unreadCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '$_unreadCount unread',
                            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_unreadCount > 0)
                  TextButton.icon(
                    onPressed: _markAllRead,
                    icon: const Icon(Icons.done_all, color: Colors.white, size: 16),
                    label: const Text(
                      'Mark all read',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverList _buildGroup(List<AppNotification> items) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final n = items[i];
          final isRead = _read.contains(n.id);

          if (n.targetType == 'follow_request') {
            return _FollowRequestCard(
              notification: n,
              timeLabel: _timeAgo(n.createdAt),
              isRead: isRead,
              onAccept: () => setState(() {
                _read.add(n.id);
                if (userState.unreadNotifications > 0) userState.unreadNotifications--;
                final myId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
                userState.acceptFollowRequest(n.fromId!, myId);
                userPrefsService.save(myId);
              }),
              onDecline: () => setState(() {
                _read.add(n.id);
                if (userState.unreadNotifications > 0) userState.unreadNotifications--;
                userState.declineFollowRequest(n.fromId!);
                final myId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
                userPrefsService.save(myId);
              }),
            );
          }

          if (n.targetType == 'board_member_request') {
            return _BoardMemberRequestCard(
              notification: n,
              timeLabel: _timeAgo(n.createdAt),
              isRead: isRead,
              onTap: () {
                setState(() {
                  _read.add(n.id);
                  if (userState.unreadNotifications > 0) userState.unreadNotifications--;
                });
                final clubId = n.targetId ?? '';
                final club = clubs.firstWhere((c) => c.id == clubId, orElse: () => clubs.first);
                final color = const [
                  Color(0xFFE53935), Color(0xFF8E24AA), Color(0xFF1E88E5),
                  Color(0xFF00897B), Color(0xFFF4511E), Color(0xFF3949AB),
                ][clubs.indexOf(club) % 6];
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ClubProfileScreen(club: club, color: color),
                ));
              },
            );
          }

          return _NotificationCard(
            notification: n,
            timeLabel: _timeAgo(n.createdAt),
            isRead: isRead,
            onTap: () {
              setState(() {
                _read.add(n.id);
                if (userState.unreadNotifications > 0) userState.unreadNotifications--;
              });
              _navigate(context, n);
            },
          );
        },
        childCount: items.length,
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, this.count = 0});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.secondaryText,
                letterSpacing: 0.5,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Notification Card ────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final String timeLabel;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.timeLabel,
    required this.isRead,
    required this.onTap,
  });

  _NotifStyle get _style {
    if (notification.targetType == 'message') {
      return _NotifStyle(Icons.message_rounded, const Color(0xFF00838F),
          const Color(0xFFE0F7FA), 'Message');
    }
    final msg = notification.message.toLowerCase();
    if (msg.contains('liked')) {
      return _NotifStyle(Icons.favorite_rounded, const Color(0xFFE91E63),
          const Color(0xFFFCE4EC), 'Like');
    }
    if (msg.contains('comment')) {
      return _NotifStyle(Icons.chat_bubble_rounded, const Color(0xFF1565C0),
          const Color(0xFFE3F2FD), 'Comment');
    }
    if (msg.contains('event') || msg.contains('hack') || msg.contains('night') ||
        msg.contains('tomorrow') || msg.contains('days')) {
      return _NotifStyle(Icons.event_rounded, const Color(0xFFE65100),
          const Color(0xFFFFF3E0), 'Event');
    }
    if (msg.contains('posted') || msg.contains('update') || msg.contains('new')) {
      return _NotifStyle(Icons.article_rounded, const Color(0xFF2E7D32),
          const Color(0xFFE8F5E9), 'Post');
    }
    if (msg.contains('follow')) {
      return _NotifStyle(Icons.person_add_rounded, const Color(0xFF6A1B9A),
          const Color(0xFFF3E5F5), 'Follow');
    }
    return _NotifStyle(Icons.notifications_rounded, AppColors.primaryRed,
        AppColors.lightRed, 'Alert');
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? AppColors.divider : s.iconColor.withValues(alpha: 0.3),
            width: isRead ? 0.5 : 1.5,
          ),
          boxShadow: isRead
              ? []
              : [
                  BoxShadow(
                    color: s.iconColor.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: s.bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(s.icon, color: s.iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: s.bgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s.typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: s.iconColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          timeLabel,
                          style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: s.iconColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (notification.targetType != null &&
                  notification.targetType != 'follow_request') ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.secondaryText),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Follow Request Card ──────────────────────────────────────────────────────

class _FollowRequestCard extends StatelessWidget {
  final AppNotification notification;
  final String timeLabel;
  final bool isRead;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _FollowRequestCard({
    required this.notification,
    required this.timeLabel,
    required this.isRead,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final fromId = notification.fromId ?? '';
    final sender = users.firstWhere((u) => u.id == fromId, orElse: () => users.first);
    final alreadyHandled = !userState.incomingFollowRequests.containsKey(fromId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? AppColors.divider
              : const Color(0xFF6A1B9A).withValues(alpha: 0.35),
          width: isRead ? 0.5 : 1.5,
        ),
        boxShadow: isRead
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                UserAvatar(
                  userId: sender.id,
                  name: sender.name,
                  size: 46,
                  fontSize: 20,
                  backgroundColor: const Color(0xFFF3E5F5),
                  textColor: const Color(0xFF6A1B9A),
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E5F5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Follow Request',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF6A1B9A),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(timeLabel,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.secondaryText)),
                          if (!isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6A1B9A),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.text,
                          fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!alreadyHandled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onAccept,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Accept',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onDecline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.secondaryText.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Decline',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                alreadyHandled && userState.isFollowingUser(fromId)
                    ? 'You accepted this request.'
                    : 'You declined this request.',
                style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Board Member Request Card ────────────────────────────────────────────────

class _BoardMemberRequestCard extends StatelessWidget {
  final AppNotification notification;
  final String timeLabel;
  final bool isRead;
  final VoidCallback onTap;

  const _BoardMemberRequestCard({
    required this.notification,
    required this.timeLabel,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fromId = notification.fromId ?? '';
    final clubId = notification.targetId ?? '';
    final requester = users.firstWhere((u) => u.id == fromId, orElse: () => users.first);
    final club = clubs.firstWhere((c) => c.id == clubId, orElse: () => clubs.first);
    // Derive handled state from the persisted BoardMemberRequest records —
    // never from userState, which is per-session and not visible across logins.
    final alreadyHandled = !boardMemberRequests.any(
        (r) => r.userId == fromId && r.clubId == clubId && r.status == 'pending');

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? AppColors.divider
              : const Color(0xFF1565C0).withValues(alpha: 0.35),
          width: isRead ? 0.5 : 1.5,
        ),
        boxShadow: isRead
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                UserAvatar(
                  userId: requester.id,
                  name: requester.name,
                  size: 46,
                  fontSize: 20,
                  backgroundColor: const Color(0xFFE3F2FD),
                  textColor: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Board Request',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(timeLabel,
                              style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                          if (!isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7, height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1565C0),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.text,
                          fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Club: ${club.name}',
                        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (alreadyHandled)
              Text(
                club.boardMemberIds.contains(fromId)
                    ? 'Approved — ${requester.name} is now a board member.'
                    : 'This request was declined.',
                style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
              )
            else
              Row(
                children: [
                  const Icon(Icons.touch_app_outlined, size: 13, color: Color(0xFF1565C0)),
                  const SizedBox(width: 4),
                  const Text(
                    'Tap to review in the club\'s Board tab',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
    );
  }
}

// ─── Style helper ─────────────────────────────────────────────────────────────

class _NotifStyle {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String typeLabel;
  const _NotifStyle(this.icon, this.iconColor, this.bgColor, this.typeLabel);
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.lightRed,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded, size: 44, color: AppColors.primaryRed),
          ),
          const SizedBox(height: 16),
          const Text('All caught up!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text('No notifications yet.',
              style: TextStyle(fontSize: 14, color: AppColors.secondaryText)),
        ],
      ),
    );
  }
}
