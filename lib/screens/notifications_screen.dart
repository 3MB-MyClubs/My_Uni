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
  String _filterMode = 'All';

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  List<AppNotification> get _allNotifs =>
      [
      ...notifications,
      ...userState.dynamicNotifications,
    ].where((n) => n.userId == _myId && n.targetType != 'story').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get _totalUnread => _allNotifs.where((n) => !_read.contains(n.id)).length;

  List<AppNotification> get _visibleNotifs {
    if (_filterMode == 'Unread') {
      return _allNotifs.where((n) => !_read.contains(n.id)).toList();
    }
    return _allNotifs;
  }

  void _markRead(AppNotification n) {
    if (_read.contains(n.id)) return;
    setState(() {
      _read.add(n.id);
      if (userState.unreadNotifications > 0) userState.unreadNotifications--;
    });
  }

  void _markAllRead() => setState(() {
    _read.addAll(_allNotifs.map((n) => n.id));
    userState.unreadNotifications = 0;
  });

  // ─── Time helpers ─────────────────────────────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d';
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _isYesterday(DateTime dt) {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return dt.year == y.year && dt.month == y.month && dt.day == y.day;
  }

  bool _isThisWeek(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    return diff >= 2 && diff <= 6;
  }

  bool _isThisMonth(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    return diff >= 7 && dt.year == now.year && dt.month == now.month;
  }

  bool _isThisYear(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    return diff >= 0 &&
        dt.year == now.year &&
        !_isToday(dt) &&
        !_isYesterday(dt) &&
        !_isThisWeek(dt) &&
        !_isThisMonth(dt);
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  static const List<Color> _clubColors = [
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  Color _colorForClub(String clubId) {
    final idx = clubs.indexWhere((c) => c.id == clubId);
    return _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
  }

  void _navigate(AppNotification n) {
    final type = n.targetType;
    final id = n.targetId;
    if (type == null || id == null) return;
    switch (type) {
      case 'post':
        final post = newsPosts.firstWhere(
          (p) => p.id == id,
          orElse: () => newsPosts.first,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              post: post,
              clubColor: _colorForClub(post.clubId),
            ),
          ),
        );
      case 'club':
        final club = clubs.firstWhere(
          (c) => c.id == id,
          orElse: () => clubs.first,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ClubProfileScreen(club: club, color: _colorForClub(id)),
          ),
        );
      case 'event':
        final event = events.firstWhere(
          (e) => e.id == id,
          orElse: () => events.first,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(
              event: event,
              color: _colorForClub(event.clubId),
            ),
          ),
        );
      case 'user':
      case 'follow_accepted':
        final user = users.firstWhere(
          (u) => u.id == id,
          orElse: () => users.first,
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
        );
      case 'message':
        final sender = users.firstWhere(
          (u) => u.id == id,
          orElse: () => users.first,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen(otherUserId: sender.id, otherUserName: sender.name),
          ),
        );
    }
  }

  String? _actionLabel(String? type) {
    switch (type) {
      case 'event':
        return 'Details';
      case 'club':
        return 'Open';
      case 'post':
        return 'Read';
      case 'message':
        return 'Reply';
      case 'user':
      case 'follow_accepted':
        return 'View';
    }
    return null;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: userState,
        builder: (context, _) {
          final sorted = _visibleNotifs;
          final today = sorted.where((n) => _isToday(n.createdAt)).toList();
          final yesterday = sorted
              .where((n) => _isYesterday(n.createdAt))
              .toList();
          final thisWeek = sorted
              .where((n) => _isThisWeek(n.createdAt))
              .toList();
          final thisMonth = sorted
              .where((n) => _isThisMonth(n.createdAt))
              .toList();
          final thisYear = sorted
              .where((n) => _isThisYear(n.createdAt))
              .toList();
          final older = sorted
              .where((n) => n.createdAt.year < DateTime.now().year)
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 400));
              if (mounted) setState(() {});
            },
            color: AppColors.primaryRed,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildHeader(),
                if (sorted.isEmpty)
                  SliverFillRemaining(
                    child: _filterMode == 'Unread'
                        ? const _NoUnreadState()
                        : const _EmptyState(),
                  )
                else ...[
                  if (today.isNotEmpty) ...[
                    _sectionLabel(
                      'Today',
                      today.where((n) => !_read.contains(n.id)).length,
                    ),
                    _buildTimeline(today),
                  ],
                  if (yesterday.isNotEmpty) ...[
                    _sectionLabel('Yesterday'),
                    _buildTimeline(yesterday),
                  ],
                  if (thisWeek.isNotEmpty) ...[
                    _sectionLabel('This Week'),
                    _buildTimeline(thisWeek),
                  ],
                  if (thisMonth.isNotEmpty) ...[
                    _sectionLabel('This Month'),
                    _buildTimeline(thisMonth),
                  ],
                  if (thisYear.isNotEmpty) ...[
                    _sectionLabel('This Year'),
                    _buildTimeline(thisYear),
                  ],
                  if (older.isNotEmpty) ...[
                    _sectionLabel('Older'),
                    _buildTimeline(older),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Header sliver ────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildHeader() {
    final unread = _totalUnread;
    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.card,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                              letterSpacing: -0.7,
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 10),
                            Text(
                              '$unread new',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (unread > 0)
                      GestureDetector(
                        onTap: _markAllRead,
                        child: Text(
                          'Mark all read',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Filter pills
                Row(
                  children: [
                    for (final f in ['All', 'Unread']) ...[
                      _FilterPill(
                        label: f,
                        active: _filterMode == f,
                        onTap: () => setState(() => _filterMode = f),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: AppColors.divider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Section label ────────────────────────────────────────────────────────

  SliverToBoxAdapter _sectionLabel(String title, [int unreadInGroup = 0]) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Row(
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.secondaryText,
                letterSpacing: 0.9,
              ),
            ),
            if (unreadInGroup > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadInGroup',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Timeline group ───────────────────────────────────────────────────────

  SliverToBoxAdapter _buildTimeline(List<AppNotification> items) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++)
              _buildTimelineRow(items[i], isLast: i == items.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(AppNotification n, {required bool isLast}) {
    final isRead = _read.contains(n.id);

    // Follow request
    if (n.targetType == 'follow_request') {
      return _TimelineRow(
        node: _AvatarNode(userId: n.fromId ?? ''),
        isLast: isLast,
        onTap: () => _markRead(n),
        child: _FollowRequestContent(
          notification: n,
          timeLabel: _timeAgo(n.createdAt),
          isRead: isRead,
          onAccept: () {
            _markRead(n);
            userState.acceptFollowRequest(n.fromId!, _myId);
            userPrefsService.save(_myId);
            setState(() {});
          },
          onDecline: () {
            _markRead(n);
            userState.declineFollowRequest(n.fromId!);
            userPrefsService.save(_myId);
            setState(() {});
          },
        ),
      );
    }

    // Board member request
    if (n.targetType == 'board_member_request') {
      return _TimelineRow(
        node: _AvatarNode(userId: n.fromId ?? ''),
        isLast: isLast,
        onTap: () {
          _markRead(n);
          final clubId = n.targetId ?? '';
          final club = clubs.firstWhere(
            (c) => c.id == clubId,
            orElse: () => clubs.first,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ClubProfileScreen(club: club, color: _colorForClub(clubId)),
            ),
          );
        },
        child: _BoardRequestContent(
          notification: n,
          timeLabel: _timeAgo(n.createdAt),
          isRead: isRead,
        ),
      );
    }

    // Standard notification
    final actionLabel = _actionLabel(n.targetType);
    return _TimelineRow(
      node: _NotifNodeIcon(targetType: n.targetType, message: n.message),
      isLast: isLast,
      onTap: () {
        _markRead(n);
        _navigate(n);
      },
      child: _NotifCard(
        notification: n,
        timeLabel: _timeAgo(n.createdAt),
        isRead: isRead,
        actionLabel: actionLabel,
        onAction: () {
          _markRead(n);
          _navigate(n);
        },
      ),
    );
  }
}

// ─── Timeline rail row ────────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  final Widget node;
  final Widget child;
  final bool isLast;
  final VoidCallback onTap;

  const _TimelineRow({
    required this.node,
    required this.child,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left rail: 40px icon + vertical connector line
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  node,
                  if (!isLast)
                    Expanded(
                      child: Center(
                        child: Container(width: 2, color: AppColors.divider),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Content card
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 4 : 16),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Node widgets (left rail) ─────────────────────────────────────────────────

class _NotifNodeIcon extends StatelessWidget {
  final String? targetType;
  final String message;

  const _NotifNodeIcon({required this.targetType, required this.message});

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, bgColor, isCircle) = _style;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: isCircle ? null : BorderRadius.circular(13),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  (IconData, Color, Color, bool) get _style {
    switch (targetType) {
      case 'event':
        return (
          Icons.event_rounded,
          const Color(0xFFE65100),
          const Color(0xFFFFF3E0),
          false,
        );
      case 'post':
        return (
          Icons.article_rounded,
          const Color(0xFF2E7D32),
          const Color(0xFFE8F5E9),
          false,
        );
      case 'message':
        return (
          Icons.message_rounded,
          const Color(0xFF00838F),
          const Color(0xFFE0F7FA),
          false,
        );
      case 'follow_accepted':
        return (
          Icons.person_add_rounded,
          const Color(0xFF6A1B9A),
          const Color(0xFFF3E5F5),
          true,
        );
      case 'user':
        return (
          Icons.person_rounded,
          const Color(0xFF6A1B9A),
          const Color(0xFFF3E5F5),
          true,
        );
      case 'club':
        return (
          Icons.groups_rounded,
          AppColors.primaryRed,
          AppColors.lightRed,
          false,
        );
    }
    final msg = message.toLowerCase();
    if (msg.contains('liked') || msg.contains('like')) {
      return (
        Icons.favorite_rounded,
        const Color(0xFFE91E63),
        const Color(0xFFFCE4EC),
        true,
      );
    }
    if (msg.contains('comment')) {
      return (
        Icons.chat_bubble_rounded,
        const Color(0xFF1565C0),
        const Color(0xFFE3F2FD),
        false,
      );
    }
    return (
      Icons.notifications_rounded,
      AppColors.primaryRed,
      AppColors.lightRed,
      false,
    );
  }
}

class _AvatarNode extends StatelessWidget {
  final String userId;
  const _AvatarNode({required this.userId});

  @override
  Widget build(BuildContext context) {
    final user = users.cast<dynamic>().firstWhere(
      (u) => u.id == userId,
      orElse: () => users.first,
    );
    return UserAvatar(
      userId: user.id as String,
      name: user.name as String,
      size: 40,
      fontSize: 15,
      backgroundColor: const Color(0xFFF3E5F5),
      textColor: const Color(0xFF6A1B9A),
      borderRadius: BorderRadius.circular(20),
    );
  }
}

// ─── Notification content cards ───────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final AppNotification notification;
  final String timeLabel;
  final bool isRead;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _NotifCard({
    required this.notification,
    required this.timeLabel,
    required this.isRead,
    this.actionLabel,
    this.onAction,
  });

  String? _boldTitle() {
    // If there's a known sender, the bold title is their name.
    if (notification.fromId != null) {
      final u = users.cast<dynamic>().firstWhere(
        (u) => u.id == notification.fromId,
        orElse: () => null,
      );
      if (u != null) return u.name as String;
    }
    // For club/event notifications, use the club name if message starts with it.
    if (notification.targetType == 'club' && notification.targetId != null) {
      final club = clubs.cast<dynamic>().firstWhere(
        (c) => c.id == notification.targetId,
        orElse: () => null,
      );
      if (club != null &&
          notification.message.startsWith(club.name as String)) {
        return club.name as String;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = _boldTitle();
    final body = title != null && notification.message.startsWith(title)
        ? notification.message.substring(title.length)
        : notification.message;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.transparent : AppColors.lightRed,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? AppColors.divider : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: title != null
                    ? RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.text,
                                height: 1.4,
                              ),
                            ),
                            TextSpan(
                              text: body,
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 14,
                                color: AppColors.text,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.text,
                          fontWeight: isRead
                              ? FontWeight.normal
                              : FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(height: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 9),
            GestureDetector(
              onTap: onAction,
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isRead ? AppColors.card : Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: AppColors.primaryRed.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryRed,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Follow request card content ──────────────────────────────────────────────

class _FollowRequestContent extends StatelessWidget {
  final AppNotification notification;
  final String timeLabel;
  final bool isRead;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _FollowRequestContent({
    required this.notification,
    required this.timeLabel,
    required this.isRead,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final fromId = notification.fromId ?? '';
    final alreadyHandled = !userState.incomingFollowRequests.containsKey(
      fromId,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.transparent : AppColors.lightRed,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? AppColors.divider : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'FOLLOW REQUEST',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF6A1B9A),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(height: 5),
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
            ],
          ),
          const SizedBox(height: 10),
          if (!alreadyHandled)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onAccept,
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: onDecline,
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: AppColors.secondaryText.withValues(alpha: 0.4),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Decline',
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
            )
          else
            Text(
              userState.isFollowingUser(fromId)
                  ? 'You accepted this request.'
                  : 'You declined this request.',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
        ],
      ),
    );
  }
}

// ─── Board member request card content ───────────────────────────────────────

class _BoardRequestContent extends StatelessWidget {
  final AppNotification notification;
  final String timeLabel;
  final bool isRead;

  const _BoardRequestContent({
    required this.notification,
    required this.timeLabel,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final fromId = notification.fromId ?? '';
    final clubId = notification.targetId ?? '';
    final requester = users.firstWhere(
      (u) => u.id == fromId,
      orElse: () => users.first,
    );
    final club = clubs.firstWhere(
      (c) => c.id == clubId,
      orElse: () => clubs.first,
    );
    final alreadyHandled = !boardMemberRequests.any(
      (r) => r.userId == fromId && r.clubId == clubId && r.status == 'pending',
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.transparent : AppColors.lightRed,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? AppColors.divider : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'BOARD REQUEST',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Club: ${club.name}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(height: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1565C0),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (alreadyHandled)
            Text(
              club.boardMemberIds.contains(fromId)
                  ? 'Approved — ${requester.name} is now a board member.'
                  : 'This request was declined.',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            )
          else
            Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 13,
                  color: Color(0xFF1565C0),
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap to review in the club\'s Board tab',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Filter pill ──────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryRed : AppColors.background,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active ? AppColors.primaryRed : AppColors.divider,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : AppColors.text,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}

// ─── Empty states ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.lightRed,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No notifications yet.',
            style: TextStyle(fontSize: 14, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _NoUnreadState extends StatelessWidget {
  const _NoUnreadState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.lightRed,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.done_all_rounded,
              size: 38,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No unread notifications.',
            style: TextStyle(fontSize: 14, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}
