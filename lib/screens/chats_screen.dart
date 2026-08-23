import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/user.dart';
import '../navigation/chat_page_route.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/locale_service.dart';
import '../services/mock_data.dart';
import '../services/moderation_service.dart';
import '../services/people_service.dart';
import '../services/theme_service.dart';
import '../onboarding/onboarding_anchors.dart';
import '../services/user_state.dart';
import '../widgets/chats_design.dart';
import '../widgets/club_avatar.dart';
import '../widgets/club_chat_design.dart';
import '../widgets/clubup_design.dart';
import '../widgets/group_avatar_stack.dart';
import '../widgets/user_avatar.dart';
import 'chat_thread_screen.dart';
import 'create_group_screen.dart';

/// Lets the main navigation reset Chats to its default student view whenever
/// the tab is selected again, while pushed standalone inboxes remain simple.
class ChatsController extends ChangeNotifier {
  void showStudents() => notifyListeners();
}

enum _ChatInboxFilter { students, clubs }

/// The main Chats inbox: direct messages plus one public community room per
/// club the current user can access. Private club inboxes intentionally stay
/// inside the club community's Solo Chat lane.
class ChatsScreen extends StatefulWidget {
  /// True only for the instance hosted in the main nav bar's IndexedStack, so
  /// the app tour's compose anchor attaches to a single widget.
  final bool isTutorialHost;
  final ChatsController? controller;

  /// Lets `club-chats-empty`'s "Explore Clubs" / "Browse Events" buttons reach
  /// the Search and This Week tabs. Null when the screen is hosted outside the
  /// main navigation, which simply disables them.
  final ValueChanged<int>? onSelectTab;

  const ChatsScreen({
    super.key,
    this.isTutorialHost = false,
    this.controller,
    this.onSelectTab,
  });

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String _query = '';
  _ChatInboxFilter _filter = _ChatInboxFilter.students;
  bool _filterMenuOpen = false;

  /// Gates `club-chats-loading` 140:94. Cleared as soon as the first sync
  /// future settles or the store notifies, whichever lands first.
  bool _firstLoadDone = false;
  final Set<String> _requestedProfileIds = {};
  final ScrollController _summaryScrollController = ScrollController();

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
    if (authService.currentAdmin != null) {
      _filter = _ChatInboxFilter.clubs;
    }
    localeService.addListener(_onEnvChanged);
    themeService.addListener(_onEnvChanged);
    chatStore.addListener(_onChatStoreChanged);
    _summaryScrollController.addListener(_onSummaryScroll);
    widget.controller?.addListener(_showStudentChats);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // No fallback timer here on purpose: a pending `Future.delayed` fails
      // every widget test that mounts this screen. The sync future always
      // completes, and `_onChatStoreChanged` is a second path out of the
      // skeleton.
      unawaited(
        chatStore.startChatV2Sync(_myId).whenComplete(_markFirstLoadDone),
      );
      // Club inbox rows are visible to the club admin as well as the student.
      // Hydrate the student profile for both sessions so the private thread
      // has an identity and the private label, not an empty title.
      unawaited(_hydrateDmProfiles());
    });
  }

  @override
  void dispose() {
    localeService.removeListener(_onEnvChanged);
    themeService.removeListener(_onEnvChanged);
    chatStore.removeListener(_onChatStoreChanged);
    _summaryScrollController.removeListener(_onSummaryScroll);
    _summaryScrollController.dispose();
    widget.controller?.removeListener(_showStudentChats);
    super.dispose();
  }

  void _markFirstLoadDone() {
    if (!mounted || _firstLoadDone) return;
    setState(() => _firstLoadDone = true);
  }

  void _onEnvChanged() {
    if (mounted) setState(() {});
  }

  void _onChatStoreChanged() {
    if (!mounted) return;
    _markFirstLoadDone();
    unawaited(_hydrateDmProfiles());
  }

  void _onSummaryScroll() {
    if (!_summaryScrollController.hasClients || _query.isNotEmpty) return;
    final position = _summaryScrollController.position;
    if (position.maxScrollExtent - position.pixels <=
        position.viewportDimension) {
      unawaited(chatStore.loadMoreConversationSummariesV2());
    }
  }

  void _showStudentChats() {
    if (!mounted) return;
    setState(() {
      _filter = authService.currentAdmin == null
          ? _ChatInboxFilter.students
          : _ChatInboxFilter.clubs;
      _query = '';
      _filterMenuOpen = false;
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
    // Chat v2 summaries already carry exactly the participant metadata used by
    // inbox rows. Avoid racing that one request with the legacy directory and
    // profile hydrators; the guard keeps this helper available for fallback
    // state loaded before v2 starts.
    if (chatStore.isChatV2Active) return;
    final memberIds = <String>{};
    for (final thread in chatStore.threadsFor(_myId)) {
      if (thread.peerId case final peerId?) {
        memberIds.add(peerId);
      }
      if (thread.isGroup) {
        memberIds.addAll(
          chatStore
              .groupParticipants(thread.threadId)
              .where((id) => id != _myId),
        );
      }
    }
    memberIds
      ..removeWhere((id) => _userForId(id) != null)
      ..removeAll(_requestedProfileIds);
    if (memberIds.isNotEmpty) {
      _requestedProfileIds.addAll(memberIds);
      await peopleService.hydrateProfilesByIds(memberIds);
      _requestedProfileIds.removeAll(memberIds);
    }
    if (mounted) setState(() {});
  }

  // ── Time helper ─────────────────────────────────────────────────────────────
  /// `time-ago` 243:497 — the rows read "15m ago" / "3h ago" / "1d ago", not a
  /// clock time, so a glance down the inbox sorts itself.
  String _rowTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return S.chatsJustNow;
    if (diff.inMinutes < 60) return S.chatsTimeAgo('${diff.inMinutes}m');
    if (diff.inHours < 24) return S.chatsTimeAgo('${diff.inHours}h');
    if (diff.inDays < 7) return S.chatsTimeAgo('${diff.inDays}d');
    return S.chatsTimeAgo('${(diff.inDays / 7).floor()}w');
  }

  User? _userForId(String userId) {
    final cachedIndex = peopleService.cachedPeople.indexWhere(
      (user) => user.id == userId,
    );
    if (cachedIndex != -1) return peopleService.cachedPeople[cachedIndex];
    final knownIndex = users.indexWhere((user) => user.id == userId);
    if (knownIndex != -1) return users[knownIndex];
    return null;
  }

  String _nameForUser(String userId) {
    return userState.displayNameFor(userId, _userForId(userId)?.name ?? '');
  }

  /// Student-facing club sections contain only the shared community rooms.
  /// Club accounts have no personal/club switch, so their private student
  /// inboxes remain visible in their single messaging list.
  bool _belongsToClubSection(ChatThreadSummary thread) =>
      thread.isClub || (!authService.isStudentSession && thread.isClubInbox);

  String _preview(ChatThreadSummary t) {
    // A club room previews its Chat lane: a notice belongs to the Board, so it
    // never becomes the inbox line. The badge still counts both lanes.
    final last = ChatStore.isClubThread(t.threadId)
        ? (chatStore.lastChatLaneMessageIn(t.threadId) ?? t.lastMessage)
        : t.lastMessage;
    if (last == null) return '';
    final body = switch (last.kind) {
      ChatMessageKind.postShare => S.sharedPost,
      ChatMessageKind.photo => S.attachPhoto,
      ChatMessageKind.file =>
        _isVideoAttachment(last) ? S.attachVideo : S.attachFile,
      ChatMessageKind.announcement =>
        (last.title ?? '').trim().isEmpty ? last.content : last.title!,
      _ => last.content,
    };
    final senderId = chatStore.senderIdForViewer(last, _myId);
    if (senderId == _myId) return '${S.you}: $body';
    if (t.isClub || t.isGroup) {
      final conversation = chatStore.clubInboxForThread(t.threadId);
      final senderName = conversation != null && senderId == conversation.clubId
          ? clubForId(conversation.clubId)?.name ?? ''
          : _nameForUser(senderId);
      return '$senderName: $body';
    }
    return body;
  }

  static bool _isVideoAttachment(ChatMessage message) {
    final value = (message.attachmentName ?? message.attachmentPath ?? '')
        .toLowerCase()
        .split('?')
        .first;
    return const {
      '.mp4',
      '.mov',
      '.m4v',
      '.avi',
      '.webm',
      '.mkv',
      '.3gp',
    }.any(value.endsWith);
  }

  String _threadSubtitle(ChatThreadSummary thread) => _preview(thread);

  void _openThread(String threadId, {User? recipient}) {
    Navigator.push(
      context,
      ChatPageRoute(
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
      ChatPageRoute(
        builder: (_) =>
            CreateGroupScreen(myId: _myId, initialMembers: recipients),
      ),
    );
    if (mounted && threadId != null) _openThread(threadId);
  }

  String _titleFor(ChatThreadSummary t) {
    if (t.isGroup) return chatStore.groupDisplayName(t.threadId, _myId);
    if (t.isClubInbox) {
      final conversation = chatStore.clubInboxForThread(t.threadId);
      if (conversation != null && conversation.profileId != _myId) {
        return _nameForUser(conversation.profileId);
      }
    }
    if (t.clubId != null) return clubForId(t.clubId!)?.name ?? '';
    return _nameForUser(t.peerId ?? '');
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // A club account owns one messaging destination: its community. Keep that
    // room embedded in the Chats tab so Board / Chat / Solo Chat all share the
    // main navigation's constraints and do not get pushed as a nested page.
    // Private student conversations are surfaced by the room's Solo Chat lane.
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
      backgroundColor: ChatsColors.background,
      body: ListenableBuilder(
        listenable: Listenable.merge([chatStore, userState, moderationService]),
        builder: (context, _) {
          final query = _query.trim().toLowerCase();
          final allThreads = chatStore.threadsFor(_myId).where((thread) {
            if (thread.isClubInbox) return false;
            final peerId = thread.peerId;
            return peerId == null || !moderationService.isUserBlocked(peerId);
          }).toList();
          final showingClubs = _filter == _ChatInboxFilter.clubs;
          // The frame only shows conversations, but searching the directory is
          // how a student starts a first DM with someone they have never
          // messaged. Kept, and drawn in the same row language.
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
              .where((thread) => _belongsToClubSection(thread) == showingClubs)
              .where(
                (t) =>
                    query.isEmpty || _titleFor(t).toLowerCase().contains(query),
              )
              .toList();
          final threadIds = threads.map((t) => t.peerId).toSet();
          final extraPeople = peopleResults
              .where((user) => !threadIds.contains(user.id))
              .toList();
          // `club-chats-search` 141:3 gives the Clubs tab its own results
          // layout, so a query there is not just a filtered inbox.
          final searchingClubs = showingClubs && query.isNotEmpty;
          if (searchingClubs) {
            return SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildClubSearchHeader(),
                  _buildClubSearchField(),
                  Expanded(child: _buildClubSearchResults(threads)),
                ],
              ),
            );
          }
          final loading =
              !_firstLoadDone && allThreads.isEmpty && query.isEmpty;
          return SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildDesignHeader(),
                    _buildDesignSearch(),
                    Expanded(
                      child: loading
                          ? const ClubChatsSkeleton()
                          : threads.isEmpty && extraPeople.isEmpty
                          ? _buildDesignEmpty(showingClubs)
                          : ListView.builder(
                              controller: _summaryScrollController,
                              padding: const EdgeInsets.only(bottom: 120),
                              itemCount: threads.length + extraPeople.length,
                              itemBuilder: (context, index) =>
                                  index < threads.length
                                  ? _designThreadRow(threads[index])
                                  : _designPersonRow(
                                      extraPeople[index - threads.length],
                                    ),
                            ),
                    ),
                  ],
                ),
                ..._buildFilterMenuOverlay(),
              ],
            ),
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
  // ── Header: title, the Clubs/Friends dropdown, compose ─────────────────────
  // A 64pt band with no rule under it: the pill owns the left side, the
  // compose pen owns the right, and there is no redundant title between them.

  String get _filterLabel =>
      _filter == _ChatInboxFilter.clubs ? S.chatsTabClubs : S.chatsTabFriends;

  Widget _buildDesignHeader() {
    return SizedBox(
      key: const ValueKey('chats-student-header'),
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                key: const ValueKey('chats-filter-dropdown'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _filterMenuOpen = !_filterMenuOpen),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _filterMenuOpen
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.16),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Text(
                            _filterLabel,
                            key: ValueKey(_filterLabel),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: figtree(
                              size: 18,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _filterMenuOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                key: widget.isTutorialHost
                    ? onboardingAnchors.keyFor(OnboardingAnchors.chatsCompose)
                    : const ValueKey('chats-compose-button'),
                behavior: HitTestBehavior.opaque,
                onTap: _openCompose,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.edit_rounded,
                      size: 26,
                      color: Colors.white,
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

  /// `dropdown-menu` 243:565 — a floating 160pt card under the pill.
  List<Widget> _buildFilterMenuOverlay() {
    return [
      Positioned.fill(
        child: IgnorePointer(
          ignoring: !_filterMenuOpen,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: _filterMenuOpen
                ? GestureDetector(
                    key: const ValueKey('chats-filter-dropdown-scrim'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _filterMenuOpen = false),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('chats-filter-dropdown-scrim-closed'),
                  ),
          ),
        ),
      ),
      Positioned(
        top: 60,
        left: 12,
        child: IgnorePointer(
          ignoring: !_filterMenuOpen,
          child: AnimatedSwitcher(
            key: const ValueKey('chats-filter-menu-transition'),
            duration: const Duration(milliseconds: 460),
            reverseDuration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.14),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
            child: _filterMenuOpen
                ? Container(
                    key: const ValueKey('chats-filter-menu-card'),
                    width: 160,
                    decoration: BoxDecoration(
                      color: ChatsColors.card,
                      borderRadius: BorderRadius.circular(kChatCardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _filterMenuOption(
                          _ChatInboxFilter.clubs,
                          S.chatsTabClubs,
                        ),
                        const ChatsCardDivider(),
                        _filterMenuOption(
                          _ChatInboxFilter.students,
                          S.chatsTabFriends,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('chats-filter-menu-card-closed'),
                  ),
          ),
        ),
      ),
    ];
  }

  Widget _filterMenuOption(_ChatInboxFilter filter, String label) {
    final selected = _filter == filter;
    return InkWell(
      key: ValueKey('chats-filter-option-${filter.name}'),
      onTap: () {
        setState(() => _filterMenuOpen = false);
        _selectFilter(filter);
      },
      child: SizedBox(
        height: 37,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: figtree(
                  size: 14,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: ChatsColors.text,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 16, color: ChatsColors.accent),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────
  /// `search-section` 243:484 — one pill, no filter glyph.
  Widget _buildDesignSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 37,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: ChatsColors.fill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: ChatsColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: ValueKey('chat-search-${_filter.name}'),
                onChanged: (v) => setState(() => _query = v),
                style: figtree(
                  size: 13,
                  weight: FontWeight.w400,
                  color: ChatsColors.text,
                ),
                decoration: InputDecoration(
                  hintText: S.searchConversations,
                  hintStyle: figtree(
                    size: 13,
                    weight: FontWeight.w400,
                    color: ChatsColors.muted,
                  ),
                  isDense: true,
                  // The pill paints the fill; without this the global
                  // inputDecorationTheme stacks a second one on top.
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── One inbox row ──────────────────────────────────────────────────────────
  /// `chat-row` 243:491 — 72pt tall, a 44pt avatar, a hairline underneath and
  /// a faint wash when unread. No card, no outline, no shadow.
  Widget _designThreadRow(ChatThreadSummary t) {
    final unread = t.unread;
    final club = t.clubId == null ? null : clubForId(t.clubId!);
    final groupMembers = t.isGroup
        ? chatStore.groupParticipants(t.threadId)
        : const <String>[];
    final visibleGroupMembers = groupMembers
        .where((id) => id != _myId)
        .toList();
    final title = _titleFor(t);
    return _designRowShell(
      rowKey: ValueKey('chat-thread-row-${t.threadId}'),
      unread: unread > 0,
      onTap: () => _openThread(
        t.threadId,
        recipient: t.peerId == null ? null : _userForId(t.peerId!),
      ),
      avatar: club != null
          ? ClubAvatar(
              clubId: club.id,
              clubName: club.name,
              color: _colorForClub(club.id),
              imageUrl: club.logoUrl,
              size: 44,
              fontSize: 17,
              shape: 'circle',
            )
          : t.isGroup
          ? GroupAvatarStack(
              memberIds: visibleGroupMembers,
              nameForUser: _nameForUser,
              photoPath: chatStore.groupForThread(t.threadId)?.photoUrl,
              size: 44,
            )
          : UserAvatar(
              userId: t.peerId ?? '',
              name: title,
              size: 44,
              fontSize: 17,
            ),
      titleKey: ValueKey('chat-thread-profile-name-${t.threadId}'),
      title: title,
      subtitle: _threadSubtitle(t),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            t.lastMessage == null ? '' : _rowTime(t.lastMessage!.createdAt),
            style: figtree(
              size: 11,
              weight: unread > 0 ? FontWeight.w600 : FontWeight.w500,
              color: unread > 0 ? ChatsColors.accentText : ChatsColors.muted,
            ),
          ),
          const Spacer(),
          if (unread > 0)
            Container(
              key: ValueKey('chat-thread-unread-${t.threadId}'),
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: ChatsColors.accent,
                borderRadius: BorderRadius.circular(9),
              ),
              // Align with both factors, not Container.alignment: a bare
              // Align expands to the loose constraints the trailing column
              // hands down, which stretched the badge into a 60pt pill.
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: figtree(
                    size: 10,
                    weight: FontWeight.w700,
                    color: ChatsColors.onAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A directory hit with no thread yet. Same row, no time or badge.
  Widget _designPersonRow(User user) {
    final displayName = userState.displayNameFor(user.id, user.name);
    final academicSummary = userState.academicSummaryFor(user.id);
    return _designRowShell(
      rowKey: ValueKey('chat-person-result-${user.id}'),
      unread: false,
      onTap: () => _openDmWith(user),
      avatar: UserAvatar(
        userId: user.id,
        name: displayName,
        size: 44,
        fontSize: 17,
      ),
      title: displayName,
      subtitle: academicSummary.isEmpty ? user.email : academicSummary,
    );
  }

  Widget _designRowShell({
    required Key rowKey,
    required bool unread,
    required VoidCallback onTap,
    required Widget avatar,
    required String title,
    required String subtitle,
    Key? titleKey,
    Widget? trailing,
  }) {
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: figtree(
        size: 14,
        weight: unread ? FontWeight.w700 : FontWeight.w600,
        color: ChatsColors.text,
        letterSpacing: -0.1,
      ),
    );
    return Material(
      color: unread ? ChatsColors.unreadRow : Colors.transparent,
      child: InkWell(
        key: rowKey,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ChatsColors.border)),
          ),
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                const SizedBox(width: 20),
                SizedBox(width: 44, height: 44, child: avatar),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleKey == null
                          ? titleText
                          : KeyedSubtree(key: titleKey, child: titleText),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: figtree(
                          size: 13,
                          weight: unread ? FontWeight.w500 : FontWeight.w400,
                          color: unread ? ChatsColors.text : ChatsColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  SizedBox(width: 60, height: 37, child: trailing),
                ],
                const SizedBox(width: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Clubs-tab search ───────────────────────────────────────────────────────
  // `club-chats-search` 141:3 — the header collapses to a chevron, the tab
  // pill and a Cancel; the results are club rows with the matched run picked
  // out in the accent.

  Widget _buildClubSearchHeader() {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 16),
          GestureDetector(
            key: const ValueKey('club-search-back'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _query = ''),
            child: SizedBox(
              width: 24,
              height: 52,
              child: Icon(
                Icons.chevron_left_rounded,
                size: 24,
                color: ChatsColors.accentText,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _filterLabel,
                style: figtree(
                  size: 13,
                  weight: FontWeight.w700,
                  color: ChatsColors.accentText,
                ),
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('club-search-cancel'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _query = ''),
            child: Text(
              S.cancel,
              style: figtree(
                size: 13,
                weight: FontWeight.w600,
                color: ChatsColors.accentText,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  /// `search-field` 141:18 — same pill, now with a clear button.
  Widget _buildClubSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: ChatsColors.fill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: ChatsColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 13,
                  weight: FontWeight.w500,
                  color: ChatsColors.text,
                ),
              ),
            ),
            GestureDetector(
              key: const ValueKey('club-search-clear'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _query = ''),
              child: Icon(
                Icons.cancel_rounded,
                size: 18,
                color: ChatsColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `result-club` 141:34 — 64pt rows with the club logo, a member/unread line
  /// and a chevron.
  Widget _buildClubSearchResults(List<ChatThreadSummary> threads) {
    if (threads.isEmpty) {
      return Center(
        child: Text(
          S.noClubChats,
          style: figtree(
            size: 13,
            weight: FontWeight.w400,
            color: ChatsColors.muted,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: threads.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              S.clubSearchSectionLabel.toUpperCase(),
              style: figtree(
                size: 11,
                weight: FontWeight.w700,
                color: ChatsColors.muted,
                letterSpacing: 0.7,
              ),
            ),
          );
        }
        final thread = threads[index - 1];
        final club = thread.clubId == null ? null : clubForId(thread.clubId!);
        final title = _titleFor(thread);
        final memberCount = club == null ? 0 : clubMemberCount(club.id);
        return InkWell(
          key: ValueKey('club-search-result-${thread.threadId}'),
          onTap: () => _openThread(thread.threadId),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 16),
                if (club != null)
                  ClubAvatar(
                    clubId: club.id,
                    clubName: club.name,
                    color: _colorForClub(club.id),
                    imageUrl: club.logoUrl,
                    size: 44,
                    fontSize: 17,
                    shape: 'circle',
                  )
                else
                  const SizedBox(width: 44, height: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _highlightedTitle(title),
                      const SizedBox(height: 3),
                      Text(
                        S.clubMembersAndUnread(memberCount, thread.unread),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: figtree(
                          size: 11,
                          weight: FontWeight.w500,
                          color: ChatsColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ChatsColors.muted,
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  /// `141:37` — the part of the name that matched is accent-coloured.
  Widget _highlightedTitle(String title) {
    final needle = _query.trim().toLowerCase();
    final base = figtree(
      size: 14,
      weight: FontWeight.w600,
      color: ChatsColors.text,
    );
    final at = needle.isEmpty ? -1 : title.toLowerCase().indexOf(needle);
    if (at < 0) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          if (at > 0) TextSpan(text: title.substring(0, at)),
          TextSpan(
            text: title.substring(at, at + needle.length),
            style: base.copyWith(
              color: ChatsColors.accentText,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (at + needle.length < title.length)
            TextSpan(text: title.substring(at + needle.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  // The CHATS section has no empty frame for the student inbox, so this is a
  // quiet line in the area's own type and colors rather than an invention.
  Widget _buildDesignEmpty(bool showingClubs) {
    // `club-chats-empty` 140:31 — the Clubs tab has a designed empty state
    // with two routes out of it. The Friends tab has none, so it keeps a
    // quiet line.
    if (showingClubs && _query.trim().isEmpty) {
      return ClubChatsEmptyState(
        onExploreClubs: widget.onSelectTab == null
            ? null
            : () => widget.onSelectTab!(2),
        onBrowseEvents: widget.onSelectTab == null
            ? null
            : () => widget.onSelectTab!(1),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showingClubs
                  ? Icons.groups_outlined
                  : Icons.chat_bubble_outline_rounded,
              size: 40,
              color: ChatsColors.muted,
            ),
            const SizedBox(height: 14),
            Text(
              showingClubs ? S.noClubChats : S.noStudentChats,
              textAlign: TextAlign.center,
              style: figtree(
                size: 15,
                weight: FontWeight.w700,
                color: ChatsColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              showingClubs ? S.noClubChatsHint : S.noStudentChatsHint,
              textAlign: TextAlign.center,
              style: figtree(
                size: 13,
                weight: FontWeight.w400,
                color: ChatsColors.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
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

  // The handoff has no compose sheet, so this keeps its own structure and
  // borrows the area's palette, type and row shapes from `add-member`
  // (`105:329`) rather than handing the compose flow off into the old chrome.
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
        color: ChatsColors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kChatSheetRadius),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: ChatsColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            S.newChat,
            style: figtree(
              size: 17,
              weight: FontWeight.w700,
              color: ChatsColors.text,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: _selected.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 41,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _selected.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final user = _selected.values.elementAt(index);
                        return Container(
                          height: 29,
                          padding: const EdgeInsets.only(left: 12, right: 6),
                          decoration: BoxDecoration(
                            color: ChatsColors.accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              Text(
                                userState
                                    .displayNameFor(user.id, user.name)
                                    .split(' ')
                                    .first,
                                style: figtree(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: ChatsColors.accentText,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                key: ValueKey('remove-recipient-${user.id}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    setState(() => _selected.remove(user.id)),
                                child: Icon(
                                  Icons.cancel_rounded,
                                  size: 14,
                                  color: ChatsColors.accentText,
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: ChatsColors.fill,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: ChatsColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('new-chat-search'),
                      autofocus: false,
                      onChanged: (v) => setState(() => _query = v),
                      style: figtree(
                        size: 13,
                        weight: FontWeight.w500,
                        color: ChatsColors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: S.chatsSearchContacts,
                        hintStyle: figtree(
                          size: 13,
                          weight: FontWeight.w400,
                          color: ChatsColors.muted,
                        ),
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: candidates.isEmpty
                ? Center(
                    child: Text(
                      S.noOneMatches,
                      style: figtree(
                        size: 13,
                        weight: FontWeight.w400,
                        color: ChatsColors.muted,
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
                        child: SizedBox(
                          height: 54,
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              UserAvatar(
                                userId: user.id,
                                name: user.name,
                                size: 38,
                                fontSize: 14,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userState.displayNameFor(
                                        user.id,
                                        user.name,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: figtree(
                                        size: 14,
                                        weight: FontWeight.w600,
                                        color: ChatsColors.text,
                                      ),
                                    ),
                                    if (academicSummary.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        academicSummary,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: figtree(
                                          size: 11,
                                          weight: FontWeight.w400,
                                          color: ChatsColors.muted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? ChatsColors.accent
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? ChatsColors.accent
                                        : ChatsColors.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: ChatsColors.onAccent,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: ChatsPrimaryButton(
                key: const ValueKey('new-chat-continue'),
                label: _selected.length <= 1
                    ? AppLocalizations.of(context)!.startChat
                    : AppLocalizations.of(context)!.next,
                onTap: _selected.isEmpty
                    ? null
                    : () => widget.onContinue(_selected.values.toList()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
