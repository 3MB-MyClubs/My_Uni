import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/app_presence_service.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/locale_service.dart';
import '../services/mock_data.dart';
import '../services/moderation_service.dart';
import '../services/people_service.dart';
import '../services/theme_service.dart';
import '../onboarding/onboarding_anchors.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
import '../widgets/group_avatar_stack.dart';
import '../widgets/presence_avatar.dart';
import '../widgets/user_avatar.dart';
import 'chat_thread_screen.dart';
import 'create_group_screen.dart';

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

  @override
  void initState() {
    super.initState();
    localeService.addListener(_onEnvChanged);
    themeService.addListener(_onEnvChanged);
    widget.controller?.addListener(_showStudentChats);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authService.isStudentSession) {
        unawaited(chatStore.startDirectMessageSync(_myId));
        unawaited(_hydrateDmProfiles());
        unawaited(_hydratePeopleDirectory());
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
    final memberIds = <String>{};
    for (final thread in chatStore.threadsFor(_myId)) {
      if (thread.peerId case final peerId?) memberIds.add(peerId);
      if (thread.isGroup) {
        memberIds.addAll(
          chatStore
              .groupParticipants(thread.threadId)
              .where((id) => id != _myId),
        );
      }
    }
    await peopleService.hydrateProfilesByIds(memberIds);
    if (mounted) setState(() {});
  }

  Future<void> _hydratePeopleDirectory() async {
    try {
      await peopleService.fetchPeople(excludeId: _myId);
    } catch (_) {
      // Registered on-device profiles remain searchable while offline.
    }
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
    return null;
  }

  String _nameForUser(String userId) {
    return userState.displayNameFor(userId, _userForId(userId)?.name ?? userId);
  }

  String _preview(ChatThreadSummary t) {
    final last = t.lastMessage;
    if (last == null) return '';
    if (last.senderId == _myId) return '${S.you}: ${last.content}';
    if (t.isClub || t.isGroup) {
      return '${_nameForUser(last.senderId)}: ${last.content}';
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

  Future<void> _openCompose() async {
    final recipients = await showModalBottomSheet<List<User>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NewChatSheet(
        myId: _myId,
        onContinue: (users) => Navigator.pop(sheetContext, users),
      ),
    );
    if (!mounted || recipients == null || recipients.isEmpty) return;
    if (recipients.length == 1) {
      _openDmWith(recipients.single);
      return;
    }
    final threadId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateGroupScreen(myId: _myId, initialMembers: recipients),
      ),
    );
    if (mounted && threadId != null) _openThread(threadId);
  }

  String _titleFor(ChatThreadSummary t) {
    if (t.isGroup) return chatStore.groupDisplayName(t.threadId, _myId);
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
        listenable: Listenable.merge([
          chatStore,
          userState,
          appPresenceService,
          moderationService,
        ]),
        builder: (context, _) {
          final query = _query.trim().toLowerCase();
          final allThreads = chatStore.threadsFor(_myId).where((thread) {
            final peerId = thread.peerId;
            return peerId == null || !moderationService.isUserBlocked(peerId);
          }).toList();
          final showingClubs = _filter == _ChatInboxFilter.clubs;
          final searchingPeople = !showingClubs && query.isNotEmpty;
          final peopleResults = searchingPeople
              ? peopleService.cachedPeople.where((user) {
                  if (user.id == _myId ||
                      moderationService.isUserBlocked(user.id)) {
                    return false;
                  }
                  final displayName = userState.displayNameFor(
                    user.id,
                    user.name,
                  );
                  return displayName.toLowerCase().contains(query) ||
                      user.email.toLowerCase().contains(query);
                }).toList()
              : const <User>[];
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
              ? peopleService.cachedPeople
                    .where(
                      (u) =>
                          u.id != _myId &&
                          !moderationService.isUserBlocked(u.id) &&
                          appPresenceService.onlineUserIds.contains(u.id),
                    )
                    .toList()
              : const <User>[];
          final clubThreads = allThreads
              .where((thread) => thread.isClub)
              .toList();
          return Stack(
            children: [
              _buildInboxBackdrop(showingClubs),
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(totalUnread),
                    _buildChatFilters(allThreads),
                    _buildSearchBar(),
                    if (query.isEmpty && showingClubs && clubThreads.isNotEmpty)
                      _buildClubOnlineRail(clubThreads)
                    else if (query.isEmpty && onlineStudents.isNotEmpty)
                      _buildOnlineRail(onlineStudents),
                    Expanded(
                      child: searchingPeople
                          ? _buildPeopleSearchResults(peopleResults)
                          : threads.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                0,
                                12,
                                120,
                              ),
                              itemCount: threads.length + 1,
                              itemBuilder: (context, i) => i == 0
                                  ? Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        0,
                                        4,
                                        9,
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

  /// A KU-inspired ambient layer: People uses linked campus paths, while Clubs
  /// gets a more architectural burgundy-and-gold community pattern.
  Widget _buildInboxBackdrop(bool showingClubs) {
    final darkBase = const Color(0xFF13090D);
    final darkWash = showingClubs
        ? const Color(0xFF29101A)
        : const Color(0xFF211018);
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Container(
            key: ValueKey('chat-backdrop-${showingClubs ? 'clubs' : 'people'}'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: showingClubs
                    ? [
                        themeService.isDark ? darkBase : AppColors.background,
                        themeService.isDark
                            ? darkWash
                            : AppColors.primaryRed.withValues(alpha: 0.055),
                        themeService.isDark ? darkBase : AppColors.background,
                      ]
                    : [
                        themeService.isDark ? darkBase : AppColors.background,
                        themeService.isDark
                            ? darkWash
                            : AppColors.card.withValues(alpha: 0.72),
                        themeService.isDark
                            ? const Color(0xFF180B11)
                            : AppColors.primaryRed.withValues(alpha: 0.025),
                      ],
              ),
            ),
            child: CustomPaint(
              painter: _ChatBackdropPainter(
                clubs: showingClubs,
                burgundy: AppColors.primaryRed,
                gold: AppColors.accentGold,
                isDark: themeService.isDark,
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
                  ? onboardingAnchors.keyFor(OnboardingAnchors.chatsCompose)
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
            height: 84,
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
                        width: 88,
                        child: Text(
                          displayName,
                          maxLines: 2,
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
    return peopleService.cachedPeople.where((user) {
      return user.subscribedClubIds.contains(clubId) &&
          appPresenceService.onlineUserIds.contains(user.id);
    }).length;
  }

  Widget _buildClubOnlineRail(List<ChatThreadSummary> threads) {
    final communities = threads
        .map((thread) => (thread, clubForId(thread.clubId ?? '')))
        .where(
          (entry) => entry.$2 != null && _onlineCountForClub(entry.$2!.id) > 0,
        )
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
    final groupMembers = t.isGroup
        ? chatStore.groupParticipants(t.threadId)
        : const <String>[];
    final visibleGroupMembers = groupMembers
        .where((id) => id != _myId)
        .toList();
    final title = _titleFor(t);
    final clubColor = club == null
        ? AppColors.primaryRed
        : _colorForClub(club.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: unread > 0
            ? AppColors.card
            : AppColors.card.withValues(
                alpha: themeService.isDark ? 0.74 : 0.88,
              ),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openThread(
            t.threadId,
            recipient: t.peerId == null ? null : _userForId(t.peerId!),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: unread > 0
                    ? clubColor.withValues(alpha: 0.34)
                    : AppColors.glassEdge,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              boxShadow: [
                BoxShadow(
                  color: clubColor.withValues(alpha: unread > 0 ? 0.09 : 0.035),
                  blurRadius: 18,
                  spreadRadius: -8,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 11, 13, 11),
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
                else if (t.isGroup)
                  GroupAvatarStack(
                    memberIds: visibleGroupMembers,
                    nameForUser: _nameForUser,
                    photoPath: chatStore.groupForThread(t.threadId)?.photoUrl,
                    size: 48,
                  )
                else
                  PresenceAvatar(
                    userId: t.peerId ?? '',
                    name: title,
                    size: 48,
                    fontSize: 18,
                    online: appPresenceService.onlineUserIds.contains(
                      t.peerId ?? '',
                    ),
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _preview(t),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: unread > 0
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
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
        ),
      ),
    );
  }

  Widget _buildPeopleSearchResults(List<User> people) {
    if (people.isEmpty) {
      return Center(
        child: Text(
          S.noOneMatches,
          style: TextStyle(fontSize: 14, color: AppColors.secondaryText),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: people.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: _sectionLabel(S.studentChats),
          );
        }
        return _personSearchResult(people[index - 1]);
      },
    );
  }

  Widget _personSearchResult(User user) {
    final displayName = userState.displayNameFor(user.id, user.name);
    final academicSummary = userState.academicSummaryFor(user.id);
    final subtitle = academicSummary.isEmpty ? user.email : academicSummary;
    return InkWell(
      key: ValueKey('chat-person-result-${user.id}'),
      onTap: () => _openDmWith(user),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            PresenceAvatar(
              userId: user.id,
              name: displayName,
              size: 48,
              fontSize: 18,
              online: appPresenceService.onlineUserIds.contains(user.id),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
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

class _ChatBackdropPainter extends CustomPainter {
  final bool clubs;
  final Color burgundy;
  final Color gold;
  final bool isDark;

  const _ChatBackdropPainter({
    required this.clubs,
    required this.burgundy,
    required this.gold,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final burgundyPaint = Paint()
      ..color = burgundy.withValues(alpha: isDark ? 0.11 : 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final goldPaint = Paint()
      ..color = gold.withValues(alpha: isDark ? 0.12 : 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    if (clubs) {
      // Interlocking arches echo campus colonnades and club communities.
      for (var row = 0; row < 6; row++) {
        final y = 205.0 + (row * 116);
        final offset = row.isEven ? -34.0 : 24.0;
        for (var column = 0; column < 4; column++) {
          final x = offset + (column * 126);
          canvas.drawArc(
            Rect.fromLTWH(x, y, 92, 92),
            3.14,
            3.14,
            false,
            burgundyPaint,
          );
          canvas.drawCircle(Offset(x + 46, y + 47), 3.2, goldPaint);
        }
      }
      final ribbon = Path()
        ..moveTo(size.width * .68, 0)
        ..quadraticBezierTo(size.width * .94, 150, size.width * .74, 310)
        ..quadraticBezierTo(size.width * .56, 450, size.width, 590);
      canvas.drawPath(ribbon, goldPaint..strokeWidth = 1.4);
    } else {
      // A sparse network of paths and meeting points for direct conversations.
      final points = <Offset>[
        Offset(-18, size.height * .28),
        Offset(size.width * .22, size.height * .35),
        Offset(size.width * .72, size.height * .27),
        Offset(size.width + 18, size.height * .38),
        Offset(size.width * .12, size.height * .68),
        Offset(size.width * .55, size.height * .60),
        Offset(size.width * .91, size.height * .76),
      ];
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final previous = points[i - 1];
        final point = points[i];
        path.quadraticBezierTo(
          (previous.dx + point.dx) / 2,
          previous.dy - 34,
          point.dx,
          point.dy,
        );
      }
      canvas.drawPath(path, burgundyPaint);
      for (var i = 1; i < points.length - 1; i++) {
        canvas.drawCircle(points[i], i.isEven ? 5 : 3.5, goldPaint);
        canvas.drawCircle(
          points[i],
          1.4,
          burgundyPaint..style = PaintingStyle.fill,
        );
        burgundyPaint.style = PaintingStyle.stroke;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChatBackdropPainter oldDelegate) {
    return clubs != oldDelegate.clubs ||
        burgundy != oldDelegate.burgundy ||
        gold != oldDelegate.gold ||
        isDark != oldDelegate.isDark;
  }
}

// ── New-chat user picker sheet ────────────────────────────────────────────────

class _NewChatSheet extends StatefulWidget {
  final String myId;
  final ValueChanged<List<User>> onContinue;

  const _NewChatSheet({required this.myId, required this.onContinue});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  String _query = '';
  final Map<String, User> _selected = {};

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
      for (final user in peopleService.cachedPeople) user.id: user,
      ..._selected,
    }.values;
    final candidates = knownUsers.where((u) {
      if (u.id == widget.myId || moderationService.isUserBlocked(u.id)) {
        return false;
      }
      if (query.isEmpty) return true;
      return u.name.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          userState.displayNameFor(u.id, u.name).toLowerCase().contains(query);
    }).toList();

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
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
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: _selected.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 78,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      scrollDirection: Axis.horizontal,
                      itemCount: _selected.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final user = _selected.values.elementAt(index);
                        return SizedBox(
                          width: 54,
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  UserAvatar(
                                    userId: user.id,
                                    name: user.name,
                                    size: 44,
                                    fontSize: 16,
                                  ),
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: InkWell(
                                      key: ValueKey(
                                        'remove-recipient-${user.id}',
                                      ),
                                      onTap: () => setState(
                                        () => _selected.remove(user.id),
                                      ),
                                      child: Container(
                                        width: 19,
                                        height: 19,
                                        decoration: BoxDecoration(
                                          color: AppColors.text,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.card,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 12,
                                          color: AppColors.card,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                userState
                                    .displayNameFor(user.id, user.name)
                                    .split(' ')
                                    .first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
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
                      final selected = _selected.containsKey(user.id);
                      return InkWell(
                        key: ValueKey('recipient-${user.id}'),
                        onTap: () => setState(() {
                          if (selected) {
                            _selected.remove(user.id);
                          } else {
                            _selected[user.id] = user;
                          }
                        }),
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
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 23,
                                height: 23,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primaryRed
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primaryRed
                                        : AppColors.secondaryText,
                                    width: 1.5,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: const ValueKey('new-chat-continue'),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => widget.onContinue(_selected.values.toList()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    disabledBackgroundColor: AppColors.divider,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _selected.length <= 1 ? 'Start Chat' : 'Next',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
