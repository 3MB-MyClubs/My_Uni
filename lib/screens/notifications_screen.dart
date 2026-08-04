import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/event.dart';
import '../models/news_post.dart';
import '../models/user.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../models/notification.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/notification_inbox_service.dart';
import '../services/people_service.dart';
import '../services/photo_file_cache.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../services/chat_store.dart';
import '../services/notification_navigation.dart';
import '../services/push_notification_copy.dart';
import '../widgets/app_network_image.dart';
import '../widgets/club_avatar.dart';
import '../widgets/event_cover_image.dart';
import '../widgets/user_avatar.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_motion.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/instagram_refresh_control.dart';

/// Notification center — the "UniHub Notifications" design.
///
/// One chronological feed bucketed into New / Today / This Week / This Month /
/// Earlier with sticky section headers, a collapsible follow-request strip
/// pinned above it, per-row type badges, content thumbnails, stacked "and N
/// others" faces, inline follow-back buttons, pull-to-refresh with a custom
/// arc spinner + "Updated just now" toast, and a caught-up footer.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

// ── Notification kind → badge icon + accent ──────────────────────────────────
enum _Kind {
  like,
  comment,
  mention,
  event,
  poll,
  member,
  photo,
  follow,
  message,
  system,
}

const Map<_Kind, IconData> _kindIcon = {
  _Kind.like: Icons.favorite_rounded,
  _Kind.comment: Icons.mode_comment_rounded,
  _Kind.mention: Icons.alternate_email_rounded,
  _Kind.event: Icons.event_rounded,
  _Kind.poll: Icons.bar_chart_rounded,
  _Kind.member: Icons.group_add_rounded,
  _Kind.photo: Icons.photo_rounded,
  _Kind.follow: Icons.person_add_alt_1_rounded,
  _Kind.message: Icons.chat_bubble_rounded,
  _Kind.system: Icons.verified_rounded,
};

const Map<_Kind, Color> _kindColorRaw = {
  _Kind.comment: Color(0xFF1565C0),
  _Kind.mention: Color(0xFF00838F),
  _Kind.event: Color(0xFF2E9E5B),
  _Kind.poll: Color(0xFF6A1B9A),
  _Kind.member: Color(0xFF00838F),
  _Kind.photo: Color(0xFFE65100),
  _Kind.message: Color(0xFF1565C0),
};

Color _kindColor(_Kind kind) =>
    _kindColorRaw[kind] ??
    (kind == _Kind.system ? AppColors.mutedText : AppColors.primaryRed);

/// The five chronological buckets, in display order.
enum _Group { fresh, today, week, month, earlier }

// Trailing content-preview tile.
const double _thumbSize = 46;
const BorderRadius _thumbRadius = BorderRadius.all(Radius.circular(9));

class _NotificationClub {
  final String id;
  final String name;
  final String? logoUrl;

  const _NotificationClub({required this.id, required this.name, this.logoUrl});
}

class _NotificationGroup {
  const _NotificationGroup({required this.latest, required this.items});

  final AppNotification latest;
  final List<AppNotification> items;
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _requestsOpen = false;
  bool _toastVisible = false;
  bool _markAllReadInProgress = false;
  Timer? _toastTimer;
  final Map<String, Timer> _followPulseTimers = {};
  final Set<String> _visuallyReadGroups = {};
  final Set<String> _followPulseUserIds = {};

  /// notification id → the conversation message it previews, once resolved.
  final Map<String, ChatMessage> _previewMessages = {};

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  /// Follow requests are surfaced by the pinned strip, so their rows are kept
  /// out of the chronological feed (they would otherwise appear twice).
  List<_NotificationGroup> get _allNotifs {
    final byId = <String, AppNotification>{};
    final retentionCutoff = DateTime.now().subtract(const Duration(days: 30));
    for (final notification in [
      ...notificationInboxService.rows.map(_remoteFromMap),
      ...notifications,
      ...userState.dynamicNotifications,
    ]) {
      if (!canViewNotification(notification, currentUserId: _myId) ||
          notification.targetType == 'story') {
        continue;
      }
      if (notification.createdAt.isBefore(retentionCutoff)) continue;
      // Opening a conversation consumes its chat alert. Keep read activity
      // history, but remove stale message rows from the notification center.
      if (notification.targetType == 'message' &&
          userState.isNotificationRead(notification)) {
        continue;
      }
      if (notification.targetType == 'follow_request' &&
          notification.fromId != null &&
          userState.incomingFollowRequests.containsKey(notification.fromId)) {
        continue;
      }
      // Remote rows are listed first and are the source of truth for server
      // read state when the same notification was also cached locally.
      byId.putIfAbsent(notification.id, () => notification);
    }
    final grouped = <String, List<AppNotification>>{};
    for (final notification in byId.values) {
      final key =
          notificationConversationKey(notification) ??
          'notification:${notification.id}';
      grouped.putIfAbsent(key, () => <AppNotification>[]).add(notification);
    }

    final result = grouped.values.map((items) {
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _NotificationGroup(latest: items.first, items: items);
    }).toList();
    result.sort((a, b) => b.latest.createdAt.compareTo(a.latest.createdAt));
    return result;
  }

  @override
  void initState() {
    super.initState();
    localeService.addListener(_onLocaleChanged);
    themeService.addListener(_onLocaleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(notificationInboxService.startForCurrentUser());
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    for (final timer in _followPulseTimers.values) {
      timer.cancel();
    }
    _followPulseTimers.clear();
    localeService.removeListener(_onLocaleChanged);
    themeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  bool _isUnread(_NotificationGroup group) =>
      group.items.any((n) => !n.read && !userState.isNotificationRead(n));

  String _groupKey(_NotificationGroup group) =>
      notificationConversationKey(group.latest) ??
      'notification:${group.latest.id}';

  bool _isVisuallyUnread(_NotificationGroup group) =>
      _isUnread(group) && !_visuallyReadGroups.contains(_groupKey(group));

  AppNotification _remoteFromMap(Map<String, dynamic> row) {
    final rawArgs = row['localization_args'];
    final args = rawArgs is Map
        ? Map<String, dynamic>.from(rawArgs)
        : <String, dynamic>{};
    final copy = localizedPushNotificationCopy(
      type: row['type']?.toString() ?? '',
      args: args,
      languageCode: localeService.languageCode,
      fallbackTitle: row['title']?.toString() ?? '',
      fallbackBody: row['body']?.toString() ?? '',
    );
    return AppNotification(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      fromId: row['actor_user_id'] as String?,
      message: copy.body,
      createdAt: DateTime.parse(row['created_at'] as String),
      read: row['read_at'] != null,
      notificationType: row['type'] as String?,
      targetType: row['target_type'] as String?,
      targetId: row['target_id'] as String?,
    );
  }

  // ── Pull to refresh ─────────────────────────────────────────────────────────
  Future<void> _onRefresh() async {
    await Future.wait([
      notificationInboxService.refresh(),
      // Keep the pulse on screen long enough to read as a refresh even
      // when the request resolves (or is skipped) instantly.
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);
    if (!mounted) return;
    setState(() => _toastVisible = true);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toastVisible = false);
    });
  }

  // ── Read state ──────────────────────────────────────────────────────────────
  void _markGroupRead(_NotificationGroup group) {
    userState.markNotificationsRead(group.items);
    for (final notification in group.items) {
      notificationInboxService.markRead(notification.id);
    }
  }

  Future<void> _markAllRead() async {
    if (_markAllReadInProgress) return;
    final unreadGroups = _allNotifs.where(_isUnread).toList();
    if (unreadGroups.isEmpty) return;
    final notificationsToRead = unreadGroups
        .expand((group) => group.items)
        .toList(growable: false);

    if (MediaQuery.disableAnimationsOf(context)) {
      userState.markNotificationsRead(notificationsToRead);
      notificationInboxService.markAllRead();
      return;
    }

    setState(() => _markAllReadInProgress = true);
    final delayMs = math.max(
      36,
      math.min(90, (360 / unreadGroups.length).round()),
    );
    for (var index = 0; index < unreadGroups.length; index++) {
      if (mounted) {
        setState(() => _visuallyReadGroups.add(_groupKey(unreadGroups[index])));
      }
      if (index != unreadGroups.length - 1) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    userState.markNotificationsRead(notificationsToRead);
    notificationInboxService.markAllRead();
    HapticFeedback.selectionClick();
    if (mounted) {
      setState(() {
        _visuallyReadGroups.clear();
        _markAllReadInProgress = false;
      });
    }
  }

  // ── Time helper ───────────────────────────────────────────────────────────
  String _timeAgo(DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.justNowShort;
    if (diff.inMinutes < 60) return l10n.minutesShort(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursShort(diff.inHours);
    if (diff.inDays == 1) return l10n.yesterday;
    if (diff.inDays < 7) return l10n.daysShort(diff.inDays);
    final weeks = (diff.inDays / 7).floor();
    return l10n.weeksShort(weeks);
  }

  // ── Grouping ──────────────────────────────────────────────────────────────
  /// Anything still unread lands in "New" regardless of age — everything else
  /// falls into an age bucket, exactly like the design's five sections.
  _Group _groupFor(_NotificationGroup group) {
    if (_isUnread(group)) return _Group.fresh;
    final now = DateTime.now();
    final created = group.latest.createdAt;
    if (created.year == now.year &&
        created.month == now.month &&
        created.day == now.day) {
      return _Group.today;
    }
    final days = now.difference(created).inDays;
    if (days < 7) return _Group.week;
    if (days < 30) return _Group.month;
    return _Group.earlier;
  }

  String _groupLabel(_Group group) {
    final l10n = AppLocalizations.of(context)!;
    return switch (group) {
      _Group.fresh => l10n.notifGroupNew,
      _Group.today => l10n.notifGroupToday,
      _Group.week => l10n.notifGroupThisWeek,
      _Group.month => l10n.notifGroupThisMonth,
      _Group.earlier => l10n.notifGroupEarlier,
    };
  }

  // ── Actor resolution ──────────────────────────────────────────────────────
  User? _userForId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final user in peopleService.cachedPeople) {
      if (user.id == id) return user;
    }
    for (final user in users) {
      if (user.id == id) return user;
    }
    return null;
  }

  Map<String, dynamic>? _remoteRowFor(AppNotification n) {
    for (final row in notificationInboxService.rows) {
      if (row['id']?.toString() == n.id) return row;
    }
    return null;
  }

  /// The club a notification is genuinely from. A student liking or commenting
  /// on club content remains a person notification even though its target is a
  /// club post.
  _NotificationClub? _clubForNotification(AppNotification n) {
    final remoteRow = _remoteRowFor(n);
    final hydratedClubId = remoteRow?['_actor_club_id']?.toString();
    final type = n.notificationType?.toLowerCase() ?? '';
    final isClubActivity =
        hydratedClubId != null ||
        n.targetType == 'club' ||
        type == 'club_post' ||
        type == 'club_event' ||
        type == 'club_channel_message' ||
        // Legacy/local club alerts predate notificationType. With no person
        // actor, a post or event alert is safely attributable to its club.
        (type.isEmpty &&
            n.fromId == null &&
            (n.targetType == 'post' || n.targetType == 'event'));
    if (!isClubActivity) return null;

    String? clubId;
    clubId = hydratedClubId;
    if (clubId == null || clubId.isEmpty) {
      if (n.targetType == 'club' || type == 'club_channel_message') {
        clubId = n.targetId;
      } else if (n.targetType == 'post') {
        final id = n.targetId;
        final idx = id == null ? -1 : newsPosts.indexWhere((p) => p.id == id);
        if (idx >= 0) clubId = newsPosts[idx].clubId;
      } else if (n.targetType == 'event') {
        final id = n.targetId;
        final idx = id == null ? -1 : events.indexWhere((e) => e.id == id);
        if (idx >= 0) clubId = events[idx].clubId;
      }
    }
    if (clubId == null || clubId.isEmpty) return null;

    final localClub = clubForId(clubId);
    if (localClub != null) {
      return _NotificationClub(
        id: localClub.id,
        name: localClub.name,
        logoUrl:
            remoteRow?['_actor_club_logo_url']?.toString() ?? localClub.logoUrl,
      );
    }
    final rawArgs = remoteRow?['localization_args'];
    final args = rawArgs is Map ? rawArgs : const <String, dynamic>{};
    final name =
        remoteRow?['_actor_club_name']?.toString().trim() ??
        args['clubName']?.toString().trim() ??
        'Club';
    return _NotificationClub(
      id: clubId,
      name: name.isEmpty ? 'Club' : name,
      logoUrl: remoteRow?['_actor_club_logo_url']?.toString(),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _openTarget(AppNotification n) {
    unawaited(
      openNotificationTarget(
        context,
        notificationTargetFor(n),
        currentUserId: _myId,
      ),
    );
  }

  void _onRowTap(_NotificationGroup group) {
    final n = group.latest;
    _markGroupRead(group);
    // Follow requests have no destination — the strip's Confirm / Delete act.
    if (n.targetType == 'follow_request') return;
    _openTarget(n);
  }

  // ── Type → badge ──────────────────────────────────────────────────────────
  _Kind _kindFor(AppNotification n) {
    final msg = n.message.toLowerCase();
    final type = n.notificationType?.toLowerCase() ?? '';
    if (type == 'profile_follow' || type == 'follow_accepted') {
      return _Kind.follow;
    }
    switch (n.targetType) {
      case 'message':
        return _Kind.message;
      case 'event':
        return _Kind.event;
      case 'follow_request':
      case 'follow_accepted':
      case 'user':
        return _Kind.follow;
      case 'club':
        if (msg.contains('photo') || msg.contains('fotoğraf')) {
          return _Kind.photo;
        }
        return _Kind.member;
      case 'post':
        if (msg.contains('lik') || msg.contains('beğen')) return _Kind.like;
        if (msg.contains('comment') ||
            msg.contains('repl') ||
            msg.contains('yorum') ||
            msg.contains('yanıt')) {
          return _Kind.comment;
        }
        if (msg.contains('mention') ||
            msg.contains('@') ||
            msg.contains('bahset') ||
            msg.contains('etiket')) {
          return _Kind.mention;
        }
        if (msg.contains('poll') ||
            msg.contains('anket') ||
            msg.contains('vote') ||
            msg.contains('oy')) {
          return _Kind.poll;
        }
        if (msg.contains('photo') || msg.contains('fotoğraf')) {
          return _Kind.photo;
        }
        return _Kind.comment;
    }
    return _Kind.system;
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

  /// The secondary "snippet" line: the post being reacted to, or the event's
  /// place and time.
  String? _subFor(AppNotification n) {
    switch (n.targetType) {
      case 'post':
        final idx = newsPosts.indexWhere((p) => p.id == n.targetId);
        if (idx < 0) return null;
        final text = newsPosts[idx].content.trim().replaceAll('\n', ' ');
        return text.isEmpty ? null : '“$text”';
      case 'event':
        final idx = events.indexWhere((e) => e.id == n.targetId);
        if (idx < 0) return null;
        final event = events[idx];
        final materialL10n = MaterialLocalizations.of(context);
        final when =
            '${materialL10n.formatMediumDate(event.dateTime)} '
            '${materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(event.dateTime))}';
        final place = event.location.trim();
        return place.isEmpty ? when : '$place · $when';
    }
    return null;
  }

  /// Stacked mini-avatars for "and N others" style alerts, built from the real
  /// likers / commenters of the target post. Empty unless there are at least
  /// two distinct people.
  List<String> _facesFor(AppNotification n) {
    if (n.targetType != 'post' || n.targetId == null) return const [];
    final kind = _kindFor(n);
    final Iterable<String> others;
    if (kind == _Kind.like) {
      others = likes.where((l) => l.postId == n.targetId).map((l) => l.userId);
    } else if (kind == _Kind.comment) {
      others = comments
          .where((c) => c.postId == n.targetId)
          .map((c) => c.userId);
    } else {
      return const [];
    }
    final seen = <String>{};
    final out = <String>[];
    for (final id in [if (n.fromId != null) n.fromId!, ...others]) {
      if (id == _myId || !seen.add(id)) continue;
      if (_userForId(id) == null) continue;
      out.add(id);
      if (out.length == 3) break;
    }
    return out.length > 1 ? out : const [];
  }

  /// The person a follow-back button on this row should act on.
  String? _followTargetFor(AppNotification n) {
    if (!authService.isStudentSession) return null;
    final type = n.notificationType?.toLowerCase() ?? '';
    final isFollowAlert =
        n.targetType == 'user' ||
        n.targetType == 'follow_accepted' ||
        type == 'profile_follow' ||
        type == 'follow_accepted';
    if (!isFollowAlert) return null;
    final id = n.fromId ?? n.targetId;
    if (id == null || id.isEmpty || id == _myId) return null;
    return _userForId(id) == null ? null : id;
  }

  Future<void> _toggleFollow(String userId) async {
    final myId = _myId;
    final wasFollowing = userState.isFollowingUser(userId);
    final wasPending = userState.hasPendingRequest(userId);

    if (wasPending) {
      userState.pendingFollowRequests.remove(userId);
      userState.followedUserIds.remove(userId);
      setState(() {});
      userPrefsService.save(myId);
      return;
    }

    if (wasFollowing) {
      userState.toggleFollowUser(userId);
    } else {
      userState.followedUserIds.add(userId);
      HapticFeedback.lightImpact();
      _followPulseUserIds.add(userId);
      _followPulseTimers[userId]?.cancel();
      _followPulseTimers[userId] = Timer(const Duration(milliseconds: 260), () {
        _followPulseTimers.remove(userId);
        if (mounted) setState(() => _followPulseUserIds.remove(userId));
      });
    }
    setState(() {});
    userPrefsService.save(myId);
    try {
      await peopleService.setFollowing(
        followerId: myId,
        followingId: userId,
        follow: !wasFollowing,
      );
    } catch (_) {
      // Roll the optimistic toggle back if the write failed.
      if (wasFollowing) {
        userState.followedUserIds.add(userId);
      } else {
        userState.followedUserIds.remove(userId);
      }
      if (mounted) setState(() {});
      userPrefsService.save(myId);
    }
  }

  // ── Follow requests ───────────────────────────────────────────────────────
  List<User> get _pendingRequesters => userState.incomingFollowRequests.keys
      .map(_userForId)
      .whereType<User>()
      .toList();

  String _requestMeta(User user) {
    final l10n = AppLocalizations.of(context)!;
    final parts = <String>[];
    final major = userState.majors[user.id]?.trim() ?? '';
    if (major.isNotEmpty) parts.add(major);
    final mutual = userState.followedUserIds
        .intersection(Set<String>.from(user.followingUserIds))
        .length;
    if (mutual > 0) {
      parts.add(l10n.mutualBadgeCount(mutual > 30 ? '30+' : '$mutual'));
    }
    if (parts.isEmpty) {
      final username = userState.usernameFor(user.id);
      parts.add(username != null ? '@$username' : user.email);
    }
    return parts.join(' · ');
  }

  void _resolveRequest(User user, {required bool accept}) {
    final myId = _myId;
    final notifId = userState.incomingFollowRequests[user.id];
    if (notifId != null) {
      final pending = [
        ...notifications,
        ...userState.dynamicNotifications,
      ].where((n) => n.id == notifId);
      for (final n in pending) {
        userState.markNotificationRead(n);
      }
    }
    if (accept) {
      userState.acceptFollowRequest(user.id, myId);
    } else {
      userState.declineFollowRequest(user.id);
    }
    userPrefsService.save(myId);
    setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: Listenable.merge([userState, notificationInboxService]),
        builder: (context, _) {
          final all = _allNotifs;
          final totalUnread = all.where(_isVisuallyUnread).length;
          final requesters = _pendingRequesters;

          return Column(
            children: [
              _buildHeader(totalUnread),
              Expanded(
                child: Stack(
                  children: [
                    CustomScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        InstagramRefreshControl(
                          refreshTriggerPullDistance: 90,
                          refreshIndicatorExtent: 48,
                          onRefresh: _onRefresh,
                        ),
                        if (requesters.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildRequestsStrip(requesters),
                          ),
                        if (all.isEmpty &&
                            requesters.isEmpty &&
                            notificationInboxService.isLoading)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _BLoading(),
                          )
                        else if (all.isEmpty && requesters.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _BEmpty(),
                          )
                        else ...[
                          for (final group in _Group.values)
                            ..._buildGroup(group, all),
                          SliverToBoxAdapter(child: _buildFooter()),
                        ],
                      ],
                    ),
                    KeyedSubtree(
                      key: _toastVisible
                          ? const ValueKey('pull-refresh-success')
                          : null,
                      child: _buildToast(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildGroup(_Group group, List<_NotificationGroup> all) {
    final rows = all.where((item) => _groupFor(item) == group).toList();
    if (rows.isEmpty) return const [];
    return [
      SliverMainAxisGroup(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _GroupHeaderDelegate(label: _groupLabel(group)),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _row(rows[i]),
              childCount: rows.length,
            ),
          ),
        ],
      ),
    ];
  }

  // ── Header (title + unread pill + mark-all) ─────────────────────────────────
  Widget _buildHeader(int totalUnread) {
    final canPop = Navigator.of(context).canPop();
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            // The design's `navBlur` is the page surface at 85%, not the card
            // white — the header reads as frosted background, not a raised bar.
            color: AppColors.background.withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.55),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (canPop)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 4),
                      child: GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  // Title and count pill share a baseline (the design aligns
                  // them on it rather than on the box bottom), so the pill sits
                  // on the title's baseline no matter how tall it grows.
                  Flexible(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            AppLocalizations.of(context)!.notifications,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.15,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (totalUnread > 0) ...[
                          const SizedBox(width: 9),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(99),
                              ),
                            ),
                            // No line-height override: the pill is aligned by
                            // its baseline, so the glyphs keep their natural
                            // line box exactly as the design's span does.
                            child: Text(
                              '$totalUnread',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (totalUnread > 0)
                    AnimatedOpacity(
                      opacity: _markAllReadInProgress ? 0.55 : 1,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _markAllReadInProgress ? null : _markAllRead,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, bottom: 3),
                          child: Text(
                            AppLocalizations.of(context)!.markAllRead,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryRed,
                            ),
                          ),
                        ),
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

  // ── Follow-request strip ───────────────────────────────────────────────────
  Widget _buildRequestsStrip(List<User> requesters) {
    final l10n = AppLocalizations.of(context)!;
    final first = userState.displayNameFor(
      requesters.first.id,
      requesters.first.name,
    );
    final subtitle = requesters.length > 1
        ? '$first ${l10n.plusOthersCount(requesters.length - 1)}'
        : first;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.55)),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _requestsOpen = !_requestsOpen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 34,
                    child: OverflowBox(
                      maxWidth: 120,
                      minHeight: 34,
                      maxHeight: 34,
                      alignment: Alignment.center,
                      child: Center(
                        child: _AvatarStack(
                          userIds: requesters.take(3).map((u) => u.id).toList(),
                          nameFor: (id) => userState.displayNameFor(
                            id,
                            requesters.firstWhere((u) => u.id == id).name,
                          ),
                          size: 34,
                          overlap: 16,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.followRequests,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  AnimatedRotation(
                    turns: _requestsOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // The design renders the request rows only while the strip is open,
          // so they are built conditionally rather than cross-faded — a
          // collapsed strip must not leave live Confirm / Delete buttons
          // (or their focus targets) sitting in the tree.
          if (_requestsOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Column(
                children: [for (final user in requesters) _requestRow(user)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _requestRow(User user) {
    final l10n = AppLocalizations.of(context)!;
    final name = userState.displayNameFor(user.id, user.name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          IgnorePointer(
            child: UserAvatar(
              userId: user.id,
              name: name,
              size: 42,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _requestMeta(user),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: AppColors.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _pillButton(
            label: l10n.confirm,
            filled: true,
            onTap: () => _resolveRequest(user, accept: true),
          ),
          const SizedBox(width: 12),
          _pillButton(
            label: l10n.delete,
            filled: false,
            onTap: () => _resolveRequest(user, accept: false),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return AppPressable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? AppColors.primaryRed : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(9)),
          border: filled ? null : Border.all(color: AppColors.borderStrong),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : AppColors.bodyText,
          ),
        ),
      ),
    );
  }

  // ── A single notification row ──────────────────────────────────────────────
  Widget _row(_NotificationGroup group) {
    final n = group.latest;
    final unread = _isVisuallyUnread(group);
    final kind = _kindFor(n);
    final accent = _kindColor(kind);
    final prefix = _boldPrefix(n);
    final sub = _subFor(n);
    final faces = _facesFor(n);
    final followTarget = _followTargetFor(n);
    final thumb = followTarget == null ? _buildThumb(n, accent) : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onRowTap(group),
      child: AnimatedContainer(
        key: ValueKey('notification-row-${n.id}'),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        color: unread ? AppColors.lightRed : Colors.transparent,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(n, kind, accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _messageText(n, prefix),
                        if (sub != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                        if (faces.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _AvatarStack(
                            userIds: faces,
                            nameFor: (id) => userState.displayNameFor(
                              id,
                              _userForId(id)?.name ?? '',
                            ),
                            size: 22,
                            overlap: 8,
                            fontSize: 8.5,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (followTarget != null) ...[
                    const SizedBox(width: 12),
                    _FollowAccessory(
                      userId: followTarget,
                      onTap: () => unawaited(_toggleFollow(followTarget)),
                    ),
                  ] else if (thumb != null) ...[
                    const SizedBox(width: 12),
                    thumb,
                  ],
                ],
              ),
            ),
            Positioned(
              left: 7,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedScale(
                  key: ValueKey('notification-unread-dot-${n.id}'),
                  scale: unread ? 1 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: unread ? 1 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Actor avatar (club square-ish, person round, system bell) with the
  /// type badge tucked into its bottom-right corner.
  Widget _buildAvatar(AppNotification n, _Kind kind, Color accent) {
    final club = _clubForNotification(n);
    final user = club == null ? _userForId(n.fromId ?? n.targetId) : null;

    final Widget base;
    if (club != null) {
      base = ClubAvatar(
        key: ValueKey('notification-club-avatar-${n.id}'),
        clubId: club.id,
        clubName: club.name,
        color: accent,
        imageUrl: club.logoUrl,
        size: 48,
        fontSize: 20,
        borderRadius: 14,
      );
    } else if (user != null) {
      base = UserAvatar(
        key: ValueKey('notification-user-avatar-${n.id}'),
        userId: user.id,
        name: userState.displayNameFor(user.id, user.name),
        size: 48,
        fontSize: 19,
      );
    } else {
      // System alerts have no actor: the design fills the slot with the app's
      // own brand avatar — a solid gradient disc, not a tinted outline.
      base = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryRed, AppColors.darkRed],
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.notifications_rounded,
          size: 22,
          color: Colors.white,
        ),
      );
    }

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The design lifts every avatar on a soft shadow tinted with its own
          // accent (`0 2px 8px accent30`).
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: club != null ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: club != null
                      ? const BorderRadius.all(Radius.circular(14))
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.19),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (user != null && _followPulseUserIds.contains(user.id))
            Positioned(
              left: -2,
              top: -2,
              child: IgnorePointer(
                child: FollowAvatarPulse(
                  active: true,
                  color: AppColors.primaryRed,
                  child: base,
                ),
              ),
            )
          else
            IgnorePointer(child: base),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _kindColor(kind),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: Icon(_kindIcon[kind], size: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageText(AppNotification n, String? prefix) {
    // The design keeps the timestamp on one piece (`white-space:nowrap`), so
    // localised forms that contain a space ("5 dk", "2 gün") can't be split
    // across lines by the wrap that follows the message.
    final time = _timeAgo(n.createdAt).replaceAll(' ', '\u00A0');
    final bodyStyle = TextStyle(
      fontSize: 14.5,
      height: 1.42,
      fontWeight: FontWeight.w400,
      color: AppColors.bodyText,
    );
    final nameStyle = TextStyle(
      fontSize: 14.5,
      height: 1.42,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
    );
    final timeStyle = TextStyle(
      fontSize: 14.5,
      height: 1.42,
      fontWeight: FontWeight.w500,
      color: AppColors.secondaryText,
    );

    final hasPrefix = prefix != null && n.message.startsWith(prefix);
    return Text.rich(
      TextSpan(
        children: [
          if (hasPrefix) ...[
            TextSpan(text: prefix, style: nameStyle),
            TextSpan(
              text: n.message.substring(prefix.length),
              style: bodyStyle,
            ),
          ] else
            TextSpan(text: n.message, style: bodyStyle),
          TextSpan(text: ' $time', style: timeStyle),
        ],
      ),
    );
  }

  /// Trailing content preview: the real post image / event cover when there is
  /// one, otherwise the design's striped placeholder tile.
  Widget? _buildThumb(AppNotification n, Color accent) {
    switch (n.targetType) {
      case 'event':
        return _eventThumb(n.targetId, accent);
      case 'post':
        return _postThumb(n.targetId, accent);
      case 'message':
        // A post, event or photo someone sent into a conversation gets the same
        // right-hand preview tile, so a share is recognisable from the alert
        // without opening the thread.
        final message = _previewableMessageFor(n);
        if (message == null) return null;
        if (message.sharedPostId != null) {
          return _postThumb(message.sharedPostId, accent);
        }
        if (message.eventId != null) {
          return _eventThumb(message.eventId, accent);
        }
        final path = message.attachmentPath;
        return path == null ? null : _photoThumb(path, accent);
    }
    return null;
  }

  /// The conversation message a "sent you a message" alert was raised for, but
  /// only when it carries something worth previewing. Local alerts are stamped
  /// with the message's own timestamp, so the closest send from that sender is
  /// the one that triggered it — the tolerance covers inbox rows that carry a
  /// server-side timestamp instead.
  ChatMessage? _previewableMessageFor(AppNotification n) {
    final threadId = n.targetId;
    if (threadId == null || threadId.isEmpty) return null;
    final cached = _previewMessages[n.id];
    if (cached != null) return cached;

    ChatMessage? best;
    Duration? bestGap;
    for (final message in chatStore.messagesFor(threadId, viewerId: _myId)) {
      if (message.senderId == _myId) continue;
      if (n.fromId != null && message.senderId != n.fromId) continue;
      if (!_hasPreview(message)) continue;
      final gap = message.createdAt.difference(n.createdAt).abs();
      if (gap > const Duration(minutes: 5)) continue;
      if (bestGap == null || gap < bestGap) {
        best = message;
        bestGap = gap;
      }
    }
    // Only hits are memoised: a message that has not synced yet must still be
    // picked up on a later build.
    if (best != null) _previewMessages[n.id] = best;
    return best;
  }

  bool _hasPreview(ChatMessage message) => switch (message.kind) {
    ChatMessageKind.postShare => message.sharedPostId != null,
    ChatMessageKind.event => message.eventId != null,
    ChatMessageKind.photo => message.attachmentPath != null,
    _ => false,
  };

  Widget? _eventThumb(String? eventId, Color accent) {
    final idx = eventId == null
        ? -1
        : events.indexWhere((e) => e.id == eventId);
    if (idx < 0) return null;
    final Event event = events[idx];
    return ClipRRect(
      borderRadius: _thumbRadius,
      child: IgnorePointer(
        child: EventCoverImage(
          event: event,
          color: accent,
          width: _thumbSize,
          height: _thumbSize,
          borderRadius: _thumbRadius,
        ),
      ),
    );
  }

  Widget? _postThumb(String? postId, Color accent) {
    final idx = postId == null
        ? -1
        : newsPosts.indexWhere((p) => p.id == postId);
    if (idx < 0) return null;
    final NewsPost post = newsPosts[idx];
    final path = post.imagePath;
    if (path != null && path.isNotEmpty && !path.startsWith('tpl:')) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return ClipRRect(
          borderRadius: _thumbRadius,
          child: AppNetworkImage(
            url: path,
            width: _thumbSize,
            height: _thumbSize,
            cacheWidth: 140,
            fit: BoxFit.cover,
            placeholderBuilder: (_) =>
                _StripeTile(accent: accent, icon: _kindIcon[_Kind.photo]!),
            errorBuilder: (_) =>
                _StripeTile(accent: accent, icon: _kindIcon[_Kind.photo]!),
          ),
        );
      }
      if (photoFileCache.existsSync(path)) return _photoThumb(path, accent);
    }
    return _StripeTile(accent: accent, icon: _kindIcon[_Kind.comment]!);
  }

  Widget _photoThumb(String path, Color accent) {
    return ClipRRect(
      borderRadius: _thumbRadius,
      child: Image.file(
        File(path),
        width: _thumbSize,
        height: _thumbSize,
        // Decoded at tile size rather than at the full camera resolution.
        cacheWidth: 140,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _StripeTile(accent: accent, icon: _kindIcon[_Kind.photo]!),
      ),
    );
  }

  // ── "Updated just now" toast ───────────────────────────────────────────────
  Widget _buildToast() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 14,
      child: IgnorePointer(
        // The design slides the toast by a flat 8px, so the travel is tweened
        // in logical pixels rather than as a fraction of the pill's height.
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _toastVisible ? 0 : 8),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          builder: (context, dy, child) =>
              Transform.translate(offset: Offset(0, dy), child: child),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _toastVisible ? 1 : 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.text,
                  borderRadius: const BorderRadius.all(Radius.circular(99)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      key: const ValueKey('refresh-success-check'),
                      size: 15,
                      color: AppColors.background,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)!.updatedJustNow,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.background,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Caught-up footer ───────────────────────────────────────────────────────
  Widget _buildFooter() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 34),
      child: Column(
        children: [
          Text(
            l10n.allCaughtUp,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 3),
          Text(
            l10n.notificationsAutoCleared,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.secondaryText.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sticky group header ───────────────────────────────────────────────────────
class _GroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;

  const _GroupHeaderDelegate({required this.label});

  @override
  double get minExtent => 30;

  @override
  double get maxExtent => 30;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 30,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.fromLTRB(18, 9, 18, 7),
          color: AppColors.background.withValues(alpha: 0.85),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              height: 1.0,
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _GroupHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}

// ── Overlapping avatar stack (request strip + "and N others" faces) ───────────
class _AvatarStack extends StatelessWidget {
  final List<String> userIds;
  final String Function(String id) nameFor;
  final double size;
  final double overlap;
  final double fontSize;

  const _AvatarStack({
    required this.userIds,
    required this.nameFor,
    required this.size,
    required this.overlap,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (userIds.isEmpty) return const SizedBox.shrink();
    final step = size - overlap;
    final width = size + step * (userIds.length - 1);
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = userIds.length - 1; i >= 0; i--)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: IgnorePointer(
                  child: UserAvatar(
                    userId: userIds[i],
                    name: nameFor(userIds[i]),
                    size: size - 4,
                    fontSize: fontSize,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Follow / Following accessory button ───────────────────────────────────────
class _FollowAccessory extends StatelessWidget {
  final String userId;
  final VoidCallback onTap;

  const _FollowAccessory({required this.userId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPending = userState.hasPendingRequest(userId);
    final isFollowing = userState.isFollowingUser(userId);
    final label = isPending
        ? l10n.requested
        : isFollowing
        ? l10n.following
        : l10n.follow;
    final filled = !isFollowing && !isPending;

    return AppPressable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      pressedScale: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 88),
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: filled ? AppColors.primaryRed : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: filled ? null : Border.all(color: AppColors.borderStrong),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            label,
            key: ValueKey(label),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : AppColors.bodyText,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Striped content-preview placeholder ───────────────────────────────────────
class _StripeTile extends StatelessWidget {
  final Color accent;
  final IconData icon;

  const _StripeTile({required this.accent, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(9)),
        border: Border.all(color: accent.withValues(alpha: 0.133)),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _StripePainter(accent: accent),
        child: Center(
          child: Icon(icon, size: 15, color: accent.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color accent;

  const _StripePainter({required this.accent});

  /// `repeating-linear-gradient(135deg, accent14 0 7px, accent07 7px 14px)`:
  /// bands measured along a 135° axis, so they read as "/" stripes with a 7px
  /// band inside a 14px period — and because the band width is measured
  /// perpendicular to a 45° line, the horizontal step has to be 14·√2 for the
  /// gaps to come out the same 7px as the stripes.
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = accent.withValues(alpha: 0.027),
    );
    final stripe = Paint()
      ..color = accent.withValues(alpha: 0.078)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;
    const step = 14 * math.sqrt2;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) =>
      oldDelegate.accent != accent;
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
            GentleFloat(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                child: Icon(
                  Icons.done_all_rounded,
                  size: 36,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.nothingHereNotif,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.noNotificationsFor(''),
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

class _BLoading extends StatelessWidget {
  const _BLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          for (var index = 0; index < 4; index++)
            StaggeredEntrance(
              index: index,
              child: const _NotificationSkeletonRow(),
            ),
        ],
      ),
    );
  }
}

class _NotificationSkeletonRow extends StatelessWidget {
  const _NotificationSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          const SkeletonBox.circle(size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 170, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
