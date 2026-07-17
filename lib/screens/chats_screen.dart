import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/locale_service.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/theme_service.dart';
import '../services/tutorial_anchors.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
import '../widgets/presence_avatar.dart';
import '../widgets/user_avatar.dart';
import 'chat_thread_screen.dart';

/// Lets the main navigation reset Chats to its default student view whenever
/// the tab is selected again, while pushed standalone inboxes remain simple.
class ChatsController extends ChangeNotifier {
  void showStudents() => notifyListeners();
}

enum _ChatInboxFilter { students, clubs }

/// The chats inbox: every conversation the current user can see — direct
/// messages plus one members-only room per club they follow (or manage, for
/// club-admin sessions). Hosted as a main-nav tab and also pushed from the
/// feed's paper-plane button.
class ChatsScreen extends StatefulWidget {
  /// True only for the instance hosted in the main nav bar's IndexedStack, so
  /// the app tour's compose anchor attaches to a single widget.
  final bool isTutorialHost;
  final ChatsController? controller;

  const ChatsScreen({super.key, this.isTutorialHost = false, this.controller});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String _query = '';
  _ChatInboxFilter _filter = _ChatInboxFilter.students;

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  static const List<Color> _clubColors = [
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  Color _colorForClub(String clubId) {
    final idx = clubOrdinal(clubId);
    return _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
  }

  Color _accentForUser(String userId) {
    var sum = 0;
    for (final unit in userId.codeUnits) {
      sum += unit;
    }
    return _clubColors[sum % _clubColors.length];
  }

  @override
  void initState() {
    super.initState();
    localeService.addListener(_onEnvChanged);
    themeService.addListener(_onEnvChanged);
    widget.controller?.addListener(_showStudentChats);
    // Belt and braces — MainNavScreen seeds after login, but this screen can
    // also be pushed directly (feed paper-plane, tests).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatStore.ensureSeededFor(_myId);
      if (authService.isStudentSession) {
        unawaited(chatStore.startDirectMessageSync(_myId));
        unawaited(_hydrateDmProfiles());
      }
    });
  }

  @override
  void dispose() {
    localeService.removeListener(_onEnvChanged);
    themeService.removeListener(_onEnvChanged);
    widget.controller?.removeListener(_showStudentChats);
    super.dispose();
  }

  void _onEnvChanged() {
    if (mounted) setState(() {});
  }

  void _showStudentChats() {
    if (!mounted) return;
    setState(() {
      _filter = _ChatInboxFilter.students;
      _query = '';
    });
  }

  void _selectFilter(_ChatInboxFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _query = '';
    });
  }

  Future<void> _hydrateDmProfiles() async {
    final peerIds = chatStore
        .threadsFor(_myId)
        .where((thread) => !thread.isClub)
        .map((thread) => thread.peerId)
        .whereType<String>();
    await peopleService.hydrateProfilesByIds(peerIds);
    if (mounted) setState(() {});
  }

  // ── Time helper ─────────────────────────────────────────────────────────────
  String _rowTime(DateTime dt) {
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final diff = now.difference(dt);
    if (diff.inDays <= 1) return S.yesterday;
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  User? _userForId(String userId) {
    final cachedIndex = peopleService.cachedPeople.indexWhere(
      (user) => user.id == userId,
    );
    if (cachedIndex != -1) return peopleService.cachedPeople[cachedIndex];
    final mockIndex = users.indexWhere((user) => user.id == userId);
    return mockIndex == -1 ? null : users[mockIndex];
  }

  String _nameForUser(String userId) {
    return userState.displayNameFor(userId, _userForId(userId)?.name ?? userId);
  }

  String _preview(ChatThreadSummary t) {
    final last = t.lastMessage;
    if (last == null) return S.sayHello;
    if (last.senderId == _myId) return '${S.you}: ${last.content}';
    if (t.isClub) {
      final first = _nameForUser(last.senderId).split(' ').first;
      return '$first: ${last.content}';
    }
    return last.content;
  }

  void _openThread(String threadId, {User? recipient}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatThreadScreen(threadId: threadId, recipient: recipient),
      ),
    );
  }

  void _openDmWith(User user) {
    final threadId = chatStore.ensureDirectThread(_myId, user.id);
    if (threadId != null) _openThread(threadId, recipient: user);
  }

  void _openCompose() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewChatSheet(
        myId: _myId,
        onPick: (user) {
          Navigator.pop(context);
          _openDmWith(user);
        },
      ),
    );
  }

  String _titleFor(ChatThreadSummary t) {
    if (t.clubId != null) return clubForId(t.clubId!)?.name ?? '';
    return _nameForUser(t.peerId ?? '');
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (authService.currentAdmin != null) {
      final communityThreadId = chatStore.managedCommunityThreadId(_myId);
      if (communityThreadId == null) return _buildNoCommunityAssigned();
      return ChatThreadScreen(
        key: const ValueKey('admin-community-thread'),
        threadId: communityThreadId,
        embedded: true,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: Listenable.merge([chatStore, userState]),
        builder: (context, _) {
          final query = _query.trim().toLowerCase();
          final allThreads = chatStore.threadsFor(_myId);
          final showingClubs = _filter == _ChatInboxFilter.clubs;
          final threads = allThreads
              .where((thread) => thread.isClub == showingClubs)
              .where(
                (t) =>
                    query.isEmpty || _titleFor(t).toLowerCase().contains(query),
              )
              .toList();
          final totalUnread = allThreads.fold<int>(
            0,
            (total, thread) => total + thread.unread,
          );
          final onlineStudents = authService.isStudentSession && !showingClubs
              ? users
                    .where((u) => u.id != _myId && ChatStore.isUserOnline(u.id))
                    .toList()
              : const <User>[];
          final clubThreads = allThreads
              .where((thread) => thread.isClub)
              .toList();
          return Stack(
            children: [
              _buildGlow(),
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(totalUnread),
                    _buildChatFilters(allThreads),
                    _buildSearchBar(),
                    if (showingClubs && clubThreads.isNotEmpty)
                      _buildClubOnlineRail(clubThreads)
                    else if (onlineStudents.isNotEmpty)
                      _buildOnlineRail(onlineStudents),
                    Expanded(
                      child: threads.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 120),
                              itemCount: threads.length + 1,
                              itemBuilder: (context, i) => i == 0
                                  ? Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        6,
                                      ),
                                      child: _sectionLabel(
                                        showingClubs
                                            ? S.clubChats
                                            : S.studentChats,
                                      ),
                                    )
                                  : _row(threads[i - 1]),
                            ),
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

  Widget _buildNoCommunityAssigned() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              key: const ValueKey('no-club-community-assigned'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 48,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  'No club community assigned',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This admin account does not have a club messaging space.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Soft radial glow bleeding from the top center, per the v5 design.
  Widget _buildGlow() {
    return Positioned(
      top: -80,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 300,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryRed.withValues(
                    alpha: themeService.isDark ? 0.22 : 0.08,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: AppColors.secondaryText,
      ),
    );
  }

  // ── Header (big title + unread pill + compose) ──────────────────────────────
  Widget _buildChatFilters(List<ChatThreadSummary> threads) {
    final studentThreads = threads.where((thread) => !thread.isClub).toList();
    final clubThreads = threads.where((thread) => thread.isClub).toList();
    final studentUnread = studentThreads.fold<int>(
      0,
      (total, thread) => total + thread.unread,
    );
    final clubUnread = clubThreads.fold<int>(
      0,
      (total, thread) => total + thread.unread,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: AppColors.divider),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              key: const ValueKey('chat-filter-liquid-indicator'),
              alignment: _filter == _ChatInboxFilter.students
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.card.withValues(alpha: 0.98),
                          AppColors.lightRed.withValues(alpha: 0.72),
                        ],
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      border: Border.all(color: AppColors.glassEdge),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withValues(alpha: 0.16),
                          blurRadius: 14,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.05),
                          blurRadius: 2,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildFilterButton(
                    key: const ValueKey('chat-filter-students'),
                    filter: _ChatInboxFilter.students,
                    label: S.studentChats,
                    icon: Icons.person_outline_rounded,
                    count: studentThreads.length,
                    unread: studentUnread,
                  ),
                ),
                Expanded(
                  child: _buildFilterButton(
                    key: const ValueKey('chat-filter-clubs'),
                    filter: _ChatInboxFilter.clubs,
                    label: S.clubChats,
                    icon: Icons.groups_outlined,
                    count: clubThreads.length,
                    unread: clubUnread,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required Key key,
    required _ChatInboxFilter filter,
    required String label,
    required IconData icon,
    required int count,
    required int unread,
  }) {
    final selected = _filter == filter;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectFilter(filter),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: selected ? 1 : 0),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => Transform.scale(
                  scale: 1 + (value * 0.10),
                  child: Icon(
                    icon,
                    size: 17,
                    color: Color.lerp(
                      AppColors.secondaryText,
                      AppColors.primaryRed,
                      value,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.text : AppColors.secondaryText,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unread > 0
                      ? AppColors.primaryRed
                      : selected
                      ? AppColors.lightRed
                      : AppColors.background,
                  borderRadius: const BorderRadius.all(Radius.circular(9)),
                ),
                child: Text(
                  unread > 0 ? (unread > 9 ? '9+' : '$unread') : '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: unread > 0
                        ? Colors.white
                        : selected
                        ? AppColors.primaryRed
                        : AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int totalUnread) {
    final canPop = Navigator.of(context).canPop();
    final showCompose =
        authService.isStudentSession && _filter == _ChatInboxFilter.students;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 5),
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: AppColors.text,
                ),
              ),
            ),
          Text.rich(
            TextSpan(
              text: S.chats,
              // The design's red full stop after the title.
              children: [
                TextSpan(
                  text: '.',
                  style: TextStyle(color: AppColors.primaryRed),
                ),
              ],
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: AppColors.text,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (totalUnread > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                border: Border.all(
                  color: AppColors.primaryRed.withValues(alpha: 0.27),
                ),
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                S.nNew(totalUnread),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
          const Spacer(),
          if (showCompose)
            GestureDetector(
              key: widget.isTutorialHost
                  ? tutorialAnchors.keyFor(TutorialAnchors.chatsCompose)
                  : null,
              onTap: _openCompose,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Icon(
                  Icons.edit_square,
                  size: 17,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Search bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: const BorderRadius.all(Radius.circular(13)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 17,
              color: AppColors.secondaryText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: ValueKey('chat-search-${_filter.name}'),
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 14, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: _query.isEmpty
                      ? (_filter == _ChatInboxFilter.students
                            ? S.searchPeople
                            : S.searchClubChats)
                      : null,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Online-now rail ─────────────────────────────────────────────────────────
  Widget _buildOnlineRail(List<User> online) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _sectionLabel(S.onlineNow),
          ),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: online.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final user = online[i];
                final displayName = userState.displayNameFor(
                  user.id,
                  user.name,
                );
                return GestureDetector(
                  onTap: () => _openDmWith(user),
                  child: Column(
                    children: [
                      PresenceAvatar(
                        userId: user.id,
                        name: user.name,
                        size: 52,
                        fontSize: 19,
                        online: true,
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: 56,
                        child: Text(
                          displayName.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── A single thread row ─────────────────────────────────────────────────────
  String _shortClubName(Club club) {
    final shortName = club.shortName?.trim();
    if (shortName != null && shortName.isNotEmpty) return shortName;
    final match = RegExp(r'\(([^)]+)\)').firstMatch(club.name);
    if (match != null) return match.group(1)!;
    return club.name;
  }

  int _onlineCountForClub(String clubId) {
    final knownOnline = users.where((user) {
      return user.subscribedClubIds.contains(clubId) &&
          ChatStore.isUserOnline(user.id);
    }).length;
    // The current session is itself online. This also gives remote clubs a
    // useful baseline before their full membership directory is hydrated.
    return knownOnline > 0 ? knownOnline : 1;
  }

  Widget _buildClubOnlineRail(List<ChatThreadSummary> threads) {
    final communities = threads
        .map((thread) => (thread, clubForId(thread.clubId ?? '')))
        .where((entry) => entry.$2 != null)
        .toList();
    if (communities.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _sectionLabel(S.onlineNow),
          ),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: communities.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final (thread, clubValue) = communities[index];
                final club = clubValue!;
                final onlineCount = _onlineCountForClub(club.id);
                return GestureDetector(
                  key: ValueKey('club-online-${club.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openThread(thread.threadId),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IgnorePointer(
                                child: ClubAvatar(
                                  clubId: club.id,
                                  clubName: club.name,
                                  color: _colorForClub(club.id),
                                  imageUrl: club.logoUrl,
                                  size: 50,
                                  fontSize: 18,
                                  shape: 'circle',
                                ),
                              ),
                              Positioned(
                                right: -1,
                                bottom: -1,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D32),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.background,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_shortClubName(club)} · ${S.onlineMembers(onlineCount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(ChatThreadSummary t) {
    final unread = t.unread;
    final club = t.clubId == null ? null : clubForId(t.clubId!);
    final title = club != null ? club.name : _nameForUser(t.peerId ?? '');
    final typing = !t.isClub && chatStore.isPeerTyping(t.threadId);
    final subtitle = club != null
        ? S.chatMembers(clubMemberCount(club.id))
        : userState.academicSummaryFor(t.peerId ?? '');
    final subtitleColor = club != null
        ? _colorForClub(club.id)
        : _accentForUser(t.peerId ?? '');

    return InkWell(
      onTap: () => _openThread(
        t.threadId,
        recipient: t.peerId == null ? null : _userForId(t.peerId!),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: unread > 0 ? AppColors.card : Colors.transparent,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: Row(
          children: [
            if (club != null)
              ClubAvatar(
                clubId: club.id,
                clubName: club.name,
                color: _colorForClub(club.id),
                imageUrl: club.logoUrl,
                size: 48,
                fontSize: 18,
                borderRadius: 15,
              )
            else
              PresenceAvatar(
                userId: t.peerId ?? '',
                name: title,
                size: 48,
                fontSize: 18,
                online: ChatStore.isUserOnline(t.peerId ?? ''),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: unread > 0
                                ? FontWeight.w800
                                : FontWeight.w700,
                            letterSpacing: -0.2,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.lastMessage == null
                            ? ''
                            : _rowTime(t.lastMessage!.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: unread > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: unread > 0
                              ? AppColors.primaryRed
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          typing ? S.typing : _preview(t),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: typing
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontWeight: typing || unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: typing
                                ? AppColors.primaryRed
                                : unread > 0
                                ? AppColors.text
                                : AppColors.secondaryText,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          height: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(9),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final showingClubs = _filter == _ChatInboxFilter.clubs;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            showingClubs
                ? Icons.groups_outlined
                : Icons.chat_bubble_outline_rounded,
            size: 52,
            color: AppColors.secondaryText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 14),
          Text(
            showingClubs ? S.noClubChats : S.noStudentChats,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            showingClubs ? S.noClubChatsHint : S.noStudentChatsHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── New-chat user picker sheet ────────────────────────────────────────────────

class _NewChatSheet extends StatefulWidget {
  final String myId;
  final ValueChanged<User> onPick;

  const _NewChatSheet({required this.myId, required this.onPick});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(_hydratePeople());
  }

  Future<void> _hydratePeople() async {
    try {
      await peopleService.fetchPeople(excludeId: widget.myId);
    } catch (_) {
      // Keep the locally available directory when the backend is offline or
      // has not been initialized yet (for example in widget previews/tests).
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final knownUsers = <String, User>{
      for (final user in users) user.id: user,
      for (final user in peopleService.cachedPeople) user.id: user,
    }.values;
    final candidates = knownUsers.where((u) {
      if (u.id == widget.myId) return false;
      if (query.isEmpty) return true;
      return u.name.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          userState.displayNameFor(u.id, u.name).toLowerCase().contains(query);
    }).toList();

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            S.newChat,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              key: const ValueKey('new-chat-search'),
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                hintText: _query.isEmpty ? S.searchPeople : null,
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.secondaryText,
                ),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: candidates.isEmpty
                ? Center(
                    child: Text(
                      S.noOneMatches,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 30),
                    itemCount: candidates.length,
                    itemBuilder: (context, i) {
                      final user = candidates[i];
                      final academicSummary = userState.academicSummaryFor(
                        user.id,
                      );
                      return InkWell(
                        onTap: () => widget.onPick(user),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                userId: user.id,
                                name: user.name,
                                size: 40,
                                fontSize: 15,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userState.displayNameFor(
                                        user.id,
                                        user.name,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    if (academicSummary.isNotEmpty)
                                      Text(
                                        academicSummary,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: AppColors.secondaryText,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
