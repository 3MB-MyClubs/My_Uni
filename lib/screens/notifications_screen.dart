import 'package:flutter/material.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';
import '../models/notification.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../services/tutorial_anchors.dart';
import '../widgets/club_avatar.dart';
import 'chat_screen.dart';
import 'club_profile_screen.dart';
import 'event_detail_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

/// Notification center — "Filtered & grouped" (Style B from the UniHub Alerts
/// design): a header with an unread count + mark-all-read, scrollable filter
/// chips (All / You / Events / Clubs) with live unread counts, and a
/// New / Earlier grouped feed of type-colored icon-tile rows. Tapping a row
/// marks it read and opens its target. Follow requests keep their working
/// Accept / Decline actions. No non-functional buttons.
class NotificationsScreen extends StatefulWidget {
  /// True only for the instance hosted in the main nav bar's IndexedStack, so
  /// the app tour's "mark all read" anchor attaches to a single widget — this
  /// screen is also pushed as a route from the feed bell.
  final bool isTutorialHost;

  const NotificationsScreen({super.key, this.isTutorialHost = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  List<AppNotification> get _allNotifs =>
      [
          ...notifications,
          ...userState.dynamicNotifications,
        ].where((n) => n.userId == _myId && n.targetType != 'story').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  void initState() {
    super.initState();
    localeService.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  bool _isUnread(AppNotification n) => !userState.isNotificationRead(n);

  // ── Read state ──────────────────────────────────────────────────────────────
  void _markRead(AppNotification n) {
    userState.markNotificationRead(n);
  }

  void _markAllRead() => userState.markNotificationsRead(_allNotifs);

  // ── Time helper ───────────────────────────────────────────────────────────
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return S.yesterday;
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    return '${weeks}w';
  }

  // ── Navigation (only types with a real destination) ─────────────────────────
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

  /// The club a notification is "from", if any — so its uploaded profile photo
  /// can be shown as the row avatar (clubs are visible app-wide this way).
  dynamic _clubForNotification(AppNotification n) {
    String? clubId;
    switch (n.targetType) {
      case 'club':
        clubId = n.targetId;
      case 'post':
        final id = n.targetId;
        final idx = id == null ? -1 : newsPosts.indexWhere((p) => p.id == id);
        if (idx >= 0) clubId = newsPosts[idx].clubId;
      case 'event':
        final id = n.targetId;
        final idx = id == null ? -1 : events.indexWhere((e) => e.id == id);
        if (idx >= 0) clubId = events[idx].clubId;
    }
    if (clubId == null) return null;
    final ci = clubs.indexWhere((c) => c.id == clubId);
    return ci >= 0 ? clubs[ci] : null;
  }

  void _openTarget(AppNotification n) {
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

  void _onRowTap(AppNotification n) {
    _markRead(n);
    // Follow requests have no destination — the Accept / Decline buttons act.
    if (n.targetType == 'follow_request') return;
    _openTarget(n);
  }

  // ── Type → icon-tile (icon + accent) ────────────────────────────────────────
  (IconData, Color) _tileStyle(AppNotification n) {
    final msg = n.message.toLowerCase();
    switch (n.targetType) {
      case 'event':
        return (Icons.event_rounded, const Color(0xFF2E9E5B));
      case 'message':
        return (Icons.chat_bubble_rounded, const Color(0xFF00838F));
      case 'follow_request':
        return (Icons.person_add_alt_1_rounded, AppColors.primaryRed);
      case 'follow_accepted':
        return (Icons.how_to_reg_rounded, AppColors.primaryRed);
      case 'user':
        return (Icons.person_add_alt_1_rounded, const Color(0xFF6A1B9A));
      case 'club':
        if (msg.contains('photo')) {
          return (Icons.photo_rounded, const Color(0xFFE65100));
        }
        return (Icons.groups_rounded, AppColors.primaryRed);
      case 'post':
        if (msg.contains('lik')) {
          return (Icons.favorite_rounded, AppColors.primaryRed);
        }
        if (msg.contains('mention')) {
          return (Icons.alternate_email_rounded, const Color(0xFF00838F));
        }
        return (Icons.article_rounded, const Color(0xFF2E7D32));
    }
    return (Icons.notifications_rounded, AppColors.secondaryText);
  }

  // Bold the actor / club name at the start of the message.
  String? _boldPrefix(AppNotification n) {
    final m = n.message;
    final colon = m.indexOf(':');
    if (colon > 0 && colon <= 26) return m.substring(0, colon);
    for (final u in users) {
      if (m.startsWith(u.name)) return u.name;
    }
    for (final c in clubs) {
      if (m.startsWith(c.name)) return c.name;
    }
    return null;
  }

  bool _isPending(AppNotification n) =>
      n.targetType == 'follow_request' &&
      (n.fromId != null) &&
      userState.incomingFollowRequests.containsKey(n.fromId);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: userState,
        builder: (context, _) {
          final list = _allNotifs;
          final news = list.where(_isUnread).toList();
          final earlier = list.where((n) => !_isUnread(n)).toList();
          final totalUnread = _allNotifs.where(_isUnread).length;

          return Column(
            children: [
              _buildHeader(totalUnread),
              Expanded(
                child: (news.isEmpty && earlier.isEmpty)
                    ? const _BEmpty()
                    : ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          if (news.isNotEmpty) ...[
                            _Sec(label: S.newSection),
                            ...news.map(_row),
                          ],
                          if (earlier.isNotEmpty) ...[
                            _Sec(label: S.earlier),
                            ...earlier.map(_row),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Header (title + unread pill + mark-all + filter chips) ──────────────────
  Widget _buildHeader(int totalUnread) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          child: Column(
            children: [
              Row(
                children: [
                  if (canPop)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  Text(
                    S.notifications,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 9),
                  if (totalUnread > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalUnread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    key: widget.isTutorialHost
                        ? tutorialAnchors.keyFor(
                            TutorialAnchors.alertsMarkAllRead,
                          )
                        : null,
                    onTap: _markAllRead,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Icon(
                        Icons.done_all_rounded,
                        size: 19,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ── A single notification row (Style B) ─────────────────────────────────────
  Widget _row(AppNotification n) {
    final unread = _isUnread(n);
    final (icon, accent) = _tileStyle(n);
    final prefix = _boldPrefix(n);
    final pending = _isPending(n);
    final club = _clubForNotification(n);

    return InkWell(
      onTap: () => _onRowTap(n),
      child: Container(
        decoration: BoxDecoration(
          color: unread ? AppColors.card : Colors.transparent,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading: the club's profile photo (with a type-icon badge) when
            // the alert is from a club; otherwise a type-colored icon tile.
            if (club != null)
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClubAvatar(
                      clubId: club.id as String,
                      clubName: club.name as String,
                      color: accent,
                      imageUrl: club.logoUrl,
                      size: 46,
                      fontSize: 20,
                      borderRadius: 14,
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 11, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.20)),
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _messageText(n, prefix, unread),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(n.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  if (pending) ...[
                    const SizedBox(height: 10),
                    _followActions(n),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (unread)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _messageText(AppNotification n, String? prefix, bool unread) {
    final baseColor = unread ? AppColors.text : AppColors.secondaryText;
    if (prefix != null && n.message.startsWith(prefix)) {
      final rest = n.message.substring(prefix.length);
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: prefix,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            TextSpan(
              text: rest,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: baseColor,
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      n.message,
      style: TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
        color: baseColor,
      ),
    );
  }

  // Working Accept / Decline for pending follow requests.
  Widget _followActions(AppNotification n) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            _markRead(n);
            userState.acceptFollowRequest(n.fromId!, _myId);
            userPrefsService.save(_myId);
            setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              S.accept,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            _markRead(n);
            userState.declineFollowRequest(n.fromId!);
            userPrefsService.save(_myId);
            setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              S.decline,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _Sec extends StatelessWidget {
  final String label;
  const _Sec({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _BEmpty extends StatelessWidget {
  const _BEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.done_all_rounded,
                size: 36,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              S.nothingHereNotif,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.noNotificationsFor(''),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
