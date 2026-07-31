import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_message.dart';
import '../models/club.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/app_presence_service.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/calendar_rsvp_helper.dart';
import '../services/chat_store.dart';
import '../services/club_admin_access.dart';
import '../services/club_chat_prefs.dart';
import '../services/club_community_info_controller.dart';
import '../services/locale_service.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/rsvp_store.dart';
import '../services/student_club_role_service.dart';
import '../services/theme_service.dart';
import '../services/user_state.dart';
import '../widgets/chat_campus_backdrop.dart';
import '../widgets/club_avatar.dart';
import '../widgets/club_chat_theme.dart';
import '../widgets/club_community_header.dart';
import '../widgets/club_community_sheet.dart';
import '../widgets/club_composer.dart';
import '../widgets/club_follow_button.dart';
import '../widgets/club_stream_items.dart';
import '../widgets/user_avatar.dart';
import '../widgets/shared_post_message_card.dart';
import 'chat_thread_screen.dart';
import 'club_profile_screen.dart';
import 'event_detail_screen.dart';
import 'user_profile_screen.dart';

/// The club community: one stream carrying chat, announcements, polls, events,
/// and attachments, with Members / Events / Notices panels behind the header.
class ClubCommunityScreen extends StatefulWidget {
  const ClubCommunityScreen({
    super.key,
    required this.threadId,
    this.embedded = false,
  });

  final String threadId;
  final bool embedded;

  @override
  State<ClubCommunityScreen> createState() => _ClubCommunityScreenState();
}

class _ClubCommunityScreenState extends State<ClubCommunityScreen>
    with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _unreadDividerKey = GlobalKey();
  final Set<String> _requestedParticipantProfileIds = {};
  final _memberDirectoryRevision = ValueNotifier<int>(0);

  ClubCommunityInfoController? _communityInfo;
  List<User> _memberUsers = const [];
  Future<void>? _memberDirectoryRequest;
  bool _membersLoading = false;
  bool _membersLoadFailed = false;

  /// Frozen on open so the "You left off here" divider does not vanish the
  /// moment the thread is marked read.
  int _unreadAtOpen = 0;
  String? _unreadAnchorMessageId;

  ClubSheetTab? _openSheet;
  bool _showJumpButton = false;

  static const List<Color> _clubColors = [
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  Club? get _club {
    final clubId = ChatStore.clubIdOf(widget.threadId);
    return clubId == null ? null : clubForId(clubId);
  }

  Color get _accent {
    final club = _club;
    if (club == null) return AppColors.primaryRed;
    final index = clubOrdinal(club.id);
    return _clubColors[(index < 0 ? 0 : index) % _clubColors.length];
  }

  ClubChatTheme get _t => ClubChatTheme.of(_accent);

  bool get _canModerate {
    final club = _club;
    if (club == null) return false;
    final id = _myId;
    if (id.isEmpty) return false;
    return club.adminUserIds.contains(id) ||
        club.boardMemberIds.contains(id) ||
        chatStore.managedCommunityThreadId(id) == widget.threadId;
  }

  /// Backgrounds affect the club's shared community identity, so board
  /// members retain moderation tools without receiving this admin setting.
  bool get _canChangeBackground {
    final club = _club;
    if (club == null || _myId.isEmpty) return false;
    return club.adminUserIds.contains(_myId) ||
        chatStore.managedCommunityThreadId(_myId) == widget.threadId;
  }

  @override
  void initState() {
    super.initState();
    final club = _club;
    if (club != null) {
      _memberUsers = peopleService.reconcileCurrentClubMember(
        fetchedMembers: const [],
        fallbackMembers: clubMembers(club.id),
        currentUser: authService.currentUser,
        currentUserIsFollowing: userState.isFollowing(club.id),
      );
      _communityInfo = ClubCommunityInfoController(
        clubId: club.id,
        fallbackMemberCount: clubMemberCount(club.id),
        fallbackMemberIds: clubMembers(club.id).map((member) => member.id),
      )..addListener(_onCommunityInfoChanged);
    }
    WidgetsBinding.instance.addObserver(this);
    themeService.addListener(_onEnvChanged);
    localeService.addListener(_onEnvChanged);
    clubChatPrefs.addListener(_onEnvChanged);
    chatStore.addListener(_onStoreChanged);
    _scrollController.addListener(_onScroll);
    // Post-frame: the community controller and the read receipt both notify
    // listeners, which is illegal while this route is still mounting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(chatStore.startClubMessageSync(_myId));
      final canAccess = chatStore.canAccessThread(widget.threadId, _myId);
      if (canAccess || authService.isStudentSession) {
        unawaited(_communityInfo?.start());
        unawaited(_loadMemberDirectory());
      }
      if (!canAccess) return;
      _captureUnreadAnchor();
      _hydrateVisibleParticipants();
      _markVisibleMessagesSeen();
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealUnread());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeService.removeListener(_onEnvChanged);
    localeService.removeListener(_onEnvChanged);
    clubChatPrefs.removeListener(_onEnvChanged);
    chatStore.removeListener(_onStoreChanged);
    _communityInfo?.removeListener(_onCommunityInfoChanged);
    chatStore.clearTyping(widget.threadId, _myId);
    _communityInfo?.dispose();
    _memberDirectoryRevision.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestedParticipantProfileIds.removeWhere(
          (id) => !_hasResolvedProfile(id),
        );
        _hydrateVisibleParticipants();
        _markVisibleMessagesSeen();
      });
    }
  }

  void _onEnvChanged() {
    if (mounted) setState(() {});
  }

  void _onCommunityInfoChanged() {
    if (mounted) setState(() {});
  }

  void _onStoreChanged() {
    if (!mounted) return;
    _hydrateVisibleParticipants();
    _markVisibleMessagesSeen();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // reverse:true — offset 0 is the newest message, at the bottom.
    final shouldShow = _scrollController.offset > 80;
    if (shouldShow != _showJumpButton) {
      setState(() => _showJumpButton = shouldShow);
    }
  }

  void _captureUnreadAnchor() {
    final unread = chatStore.unreadCountFor(widget.threadId, _myId);
    if (unread <= 0) return;
    final messages = chatStore.messagesFor(widget.threadId, viewerId: _myId);
    final incoming = messages
        .where((message) => message.senderId != _myId)
        .toList();
    if (incoming.length < unread) return;
    setState(() {
      _unreadAtOpen = unread;
      _unreadAnchorMessageId = incoming[incoming.length - unread].id;
    });
  }

  /// Brings the "left off here" divider into view when it is close enough to
  /// have been built; otherwise the stream stays pinned to the newest message.
  void _revealUnread() {
    final context = _unreadDividerKey.currentContext;
    if (context == null) return;
    unawaited(
      Scrollable.ensureVisible(
        context,
        alignment: 0.15,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      ),
    );
  }

  void _markVisibleMessagesSeen() {
    if (!mounted) return;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    chatStore.markThreadRead(widget.threadId, _myId);
  }

  void _hydrateVisibleParticipants() {
    if (!chatStore.canAccessThread(widget.threadId, _myId)) return;
    final participantIds =
        chatStore
            .messagesFor(widget.threadId, viewerId: _myId)
            .map((message) => message.senderId)
            .toSet()
          ..remove(_myId)
          ..removeAll(_requestedParticipantProfileIds);
    if (participantIds.isEmpty) return;
    _requestedParticipantProfileIds.addAll(participantIds);
    unawaited(
      peopleService.hydrateProfilesByIds(participantIds).then((_) {
        _requestedParticipantProfileIds.removeWhere(
          (id) => !_hasResolvedProfile(id),
        );
        if (mounted) setState(() {});
      }),
    );
  }

  bool _hasResolvedProfile(String userId) {
    return _memberUsers.any((user) => user.id == userId) ||
        peopleService.cachedPeople.any((user) => user.id == userId) ||
        users.any((user) => user.id == userId);
  }

  // ── People ──────────────────────────────────────────────────────────────────

  Future<void> _loadMemberDirectory({bool force = false}) {
    final existing = _memberDirectoryRequest;
    if (existing != null) return existing;

    final club = _club;
    if (club == null) return Future.value();
    if (force) peopleService.invalidateClubMembers(club.id);

    final request = _performMemberDirectoryLoad(club);
    _memberDirectoryRequest = request;
    return request.whenComplete(() {
      if (identical(_memberDirectoryRequest, request)) {
        _memberDirectoryRequest = null;
      }
    });
  }

  Future<void> _performMemberDirectoryLoad(Club club) async {
    if (mounted) {
      setState(() {
        _membersLoading = true;
        _membersLoadFailed = false;
      });
      _memberDirectoryRevision.value++;
    }

    try {
      final fetched = await peopleService.fetchClubMembers(club.id);
      if (!mounted) return;
      setState(() {
        _memberUsers = peopleService.reconcileCurrentClubMember(
          fetchedMembers: fetched,
          fallbackMembers: _memberUsers,
          currentUser: authService.currentUser,
          currentUserIsFollowing: userState.isFollowing(club.id),
        );
        _membersLoading = false;
      });
      _memberDirectoryRevision.value++;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _membersLoading = false;
        _membersLoadFailed = true;
      });
      _memberDirectoryRevision.value++;
    }
  }

  ClubPerson _personFor(String userId) {
    final club = _club;
    // Supabase stores messages sent by a linked club account with the club id
    // in `sender_club_id`. Local optimistic messages may still carry the
    // managed admin id until the remote row is reconciled. Both identities
    // represent the club in this stream, so always render the shared club
    // identity instead of an admin profile.
    if (club != null &&
        (userId == club.id ||
            club.adminUserIds.contains(userId) ||
            managedClubForAdmin(userId)?.id == club.id)) {
      return ClubPerson(
        id: club.id,
        name: club.name,
        role: S.adminLabel,
        isClubAccount: true,
        online: true,
      );
    }
    final adminIndex = clubAdmins.indexWhere((admin) => admin.id == userId);
    if (adminIndex != -1) {
      return ClubPerson(
        id: userId,
        name: clubAdmins[adminIndex].name,
        role: S.adminLabel,
        isClubAccount: true,
        online: true,
      );
    }
    if (userId == appAdmin.id) {
      return ClubPerson(
        id: userId,
        name: appAdmin.name,
        role: S.adminLabel,
        isClubAccount: true,
      );
    }
    final mine = userId == _myId;
    final memberIndex = _memberUsers.indexWhere((user) => user.id == userId);
    final cachedIndex = peopleService.cachedPeople.indexWhere(
      (user) => user.id == userId,
    );
    final knownIndex = users.indexWhere((user) => user.id == userId);
    final knownName = memberIndex != -1
        ? _memberUsers[memberIndex].name
        : (cachedIndex != -1
              ? peopleService.cachedPeople[cachedIndex].name
              : (knownIndex != -1 ? users[knownIndex].name : null));
    final fallbackName = mine
        ? (authService.currentUser?.name ?? S.you)
        : (knownName ?? '');
    return ClubPerson(
      id: userId,
      name: mine ? S.you : userState.displayNameFor(userId, fallbackName),
      role: club == null
          ? null
          : studentClubRoleService.roleTitleFor(club, userId),
      online: appPresenceService.onlineUserIds.contains(userId),
    );
  }

  /// Every member of the club, board members first, then A→Z.
  List<ClubPerson> get _members {
    final club = _club;
    if (club == null) return const [];
    final online = appPresenceService.onlineUserIds;
    final people = <ClubPerson>[];
    final seen = <String>{};
    for (final user in _memberUsers) {
      if (!seen.add(user.id)) continue;
      final mine = user.id == _myId;
      people.add(
        ClubPerson(
          id: user.id,
          name: mine ? S.you : userState.displayNameFor(user.id, user.name),
          role: studentClubRoleService.roleTitleFor(club, user.id),
          online: online.contains(user.id),
        ),
      );
    }
    people.sort((a, b) {
      final roleRank = (a.role == null ? 1 : 0).compareTo(
        b.role == null ? 1 : 0,
      );
      if (roleRank != 0) return roleRank;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return people;
  }

  Widget _avatarFor(ClubPerson person, double size) {
    final club = _club;
    if (person.isClubAccount && club != null) {
      return ClubAvatar(
        clubId: club.id,
        clubName: club.name,
        color: _accent,
        imageUrl: club.logoUrl,
        size: size,
        fontSize: size * 0.4,
        shape: 'circle',
      );
    }
    return UserAvatar(
      userId: person.id,
      name: person.name,
      size: size,
      fontSize: size * 0.38,
    );
  }

  // ── Events ──────────────────────────────────────────────────────────────────

  List<Event> get _clubEvents {
    final club = _club;
    if (club == null) return const [];
    final now = DateTime.now();
    final list =
        events
            .where(
              (event) => event.clubId == club.id && event.endTime.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  Event? _eventById(String? id) {
    if (id == null) return null;
    final index = events.indexWhere((event) => event.id == id);
    return index == -1 ? null : events[index];
  }

  void _toggleRsvp(Event event) {
    if (!authService.isStudentSession) return;
    unawaited(rsvpStore.toggle(event.id, _myId));
    syncRsvpToDeviceCalendar(context, event);
  }

  void _openEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(event: event, color: _accent),
      ),
    ).then((_) => _markVisibleMessagesSeen());
  }

  // ── Sending ─────────────────────────────────────────────────────────────────

  void _send(String text, List<String> mentions) {
    final sent = chatStore.sendMessage(
      threadId: widget.threadId,
      senderId: _myId,
      content: text,
      mentions: mentions,
    );
    if (sent == null) return;
    _scrollToLatest();
  }

  Future<void> _messageClubPrivately() async {
    final club = _club;
    final profileId = authService.currentUser?.id ?? '';
    if (club == null || profileId.isEmpty) return;
    final threadId = await chatStore.ensureClubInboxThread(
      profileId: profileId,
      clubId: club.id,
    );
    if (!mounted) return;
    if (threadId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.secureChatUnavailable)));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatThreadScreen(threadId: threadId)),
    );
  }

  Widget _buildFollowerActions(ClubChatTheme t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: t.sheet,
        border: Border(top: BorderSide(color: t.hair)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              S.clubChannelReadOnly,
              style: TextStyle(
                color: t.sub,
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            key: const ValueKey('message-club-privately'),
            onPressed: _messageClubPrivately,
            icon: const Icon(Icons.lock_outline_rounded, size: 16),
            label: Text(S.messageClub),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleAttachment(ClubAttachment attachment) async {
    switch (attachment) {
      case ClubAttachment.photo:
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 88,
        );
        if (picked == null) return;
        _sendAttachment(picked, ChatMessageKind.photo);
      case ClubAttachment.poll:
        await _composePoll();
      case ClubAttachment.event:
        await _shareEvent();
    }
  }

  void _sendAttachment(XFile file, ChatMessageKind kind) {
    var size = 0;
    try {
      size = File(file.path).lengthSync();
    } on FileSystemException {
      size = 0;
    }
    final draft = _inputController.text.trim();
    final sent = chatStore.sendMessage(
      threadId: widget.threadId,
      senderId: _myId,
      content: draft,
      kind: kind,
      mentions: ClubComposer.resolveMentions(draft, _members),
      attachmentPath: file.path,
      attachmentName: file.name,
      attachmentSize: size,
    );
    if (sent == null) return;
    _inputController.clear();
    _scrollToLatest();
  }

  Future<void> _composePoll() async {
    var question = '';
    final optionValues = <String>['', ''];
    var closesInHours = 24;
    final t = _t;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: t.sheet,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.borderB,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    S.newPollTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SheetField(
                    hint: S.pollQuestion,
                    t: t,
                    autofocus: true,
                    onChanged: (value) => question = value,
                  ),
                  for (var i = 0; i < optionValues.length; i++) ...[
                    const SizedBox(height: 8),
                    _SheetField(
                      key: ValueKey('club-poll-option-$i'),
                      hint: S.pollOptionLabel(i + 1),
                      t: t,
                      onChanged: (value) => optionValues[i] = value,
                    ),
                  ],
                  if (optionValues.length < 4) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () =>
                          setSheetState(() => optionValues.add('')),
                      icon: Icon(Icons.add_rounded, size: 18, color: t.red),
                      label: Text(
                        S.addOption,
                        style: TextStyle(
                          color: t.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        S.pollClosesIn,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: t.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      for (final option in const [24, 72, 168])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setSheetState(() => closesInHours = option),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: closesInHours == option
                                    ? t.ltRed
                                    : t.solid,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: closesInHours == option
                                      ? t.red
                                      : t.border,
                                ),
                              ),
                              child: Text(
                                option < 48
                                    ? S.pollHours(option)
                                    : S.pollDays(option ~/ 24),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: closesInHours == option
                                      ? t.red
                                      : t.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PrimaryAction(
                    label: S.post,
                    t: t,
                    onTap: () => Navigator.of(sheetContext).pop(true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final normalizedQuestion = question.trim();
    final options = optionValues
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (created != true || normalizedQuestion.isEmpty || options.length < 2) {
      return;
    }

    chatStore.sendMessage(
      threadId: widget.threadId,
      senderId: _myId,
      content: '',
      kind: ChatMessageKind.poll,
      title: normalizedQuestion,
      pollOptions: options,
      pollClosesAt: DateTime.now().add(Duration(hours: closesInHours)),
    );
    _scrollToLatest();
  }

  Future<void> _composeAnnouncement() async {
    var title = '';
    var body = '';
    var pinned = true;
    final t = _t;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: t.sheet,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.borderB,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.campaign_outlined, size: 18, color: t.red),
                      const SizedBox(width: 8),
                      Text(
                        S.postAsAnnouncement,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: t.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SheetField(
                    hint: S.announcementTitleHint,
                    t: t,
                    autofocus: true,
                    onChanged: (value) => title = value,
                  ),
                  const SizedBox(height: 8),
                  _SheetField(
                    hint: S.typeMessage,
                    t: t,
                    maxLines: 4,
                    onChanged: (value) => body = value,
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile.adaptive(
                    value: pinned,
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: t.red,
                    title: Text(
                      S.pinToTop,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    onChanged: (value) => setSheetState(() => pinned = value),
                  ),
                  const SizedBox(height: 8),
                  _PrimaryAction(
                    label: S.post,
                    t: t,
                    onTap: () => Navigator.of(sheetContext).pop(true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();
    if (created != true || normalizedTitle.isEmpty) return;

    chatStore.sendMessage(
      threadId: widget.threadId,
      senderId: _myId,
      content: normalizedBody,
      kind: ChatMessageKind.announcement,
      title: normalizedTitle,
      pinned: pinned,
    );
    _scrollToLatest();
  }

  Future<void> _shareEvent() async {
    final upcoming = _clubEvents;
    final t = _t;
    final selected = await showModalBottomSheet<Event>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: t.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.borderB,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  S.shareEvent,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 12),
                if (upcoming.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      S.noUpcomingEvents,
                      style: TextStyle(fontSize: 13, color: t.sub),
                    ),
                  ),
                for (final event in upcoming.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _eventCard(
                      event,
                      compact: true,
                      onOpen: () => Navigator.of(sheetContext).pop(event),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null) return;
    chatStore.sendMessage(
      threadId: widget.threadId,
      senderId: _myId,
      content: '',
      kind: ChatMessageKind.event,
      eventId: selected.id,
    );
    _scrollToLatest();
  }

  // ── Message actions ─────────────────────────────────────────────────────────

  static const _quickReactions = ['👍', '❤️', '🎉', '👏', '😂', '🙌'];

  Future<void> _confirmDeleteMessage(ChatMessage message) async {
    final t = _t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.sheet,
        title: Text(S.deleteMessage, style: TextStyle(color: t.text)),
        content: Text(S.deleteMessageMsg, style: TextStyle(color: t.sub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(S.cancel, style: TextStyle(color: t.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(S.delete, style: TextStyle(color: t.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      chatStore.deleteMessage(messageId: message.id, userId: _myId);
    }
  }

  void _showMessageActions(ChatMessage message) {
    final t = _t;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: t.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: t.borderB,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final emoji in _quickReactions)
                  GestureDetector(
                    onTap: () {
                      chatStore.toggleReaction(
                        messageId: message.id,
                        userId: _myId,
                        emoji: emoji,
                      );
                      Navigator.of(sheetContext).pop();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            message.reactions[emoji]?.contains(_myId) ?? false
                            ? t.ltRed
                            : t.solid,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.border),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (message.content.isNotEmpty)
              _ActionRow(
                icon: Icons.copy_rounded,
                label: S.copyText,
                t: t,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(S.copied)));
                },
              ),
            if (chatStore.isMessageOwner(message, _myId))
              _ActionRow(
                key: ValueKey('club-delete-message-${message.id}'),
                icon: Icons.delete_outline_rounded,
                label: S.deleteMessage,
                t: t,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_confirmDeleteMessage(message));
                },
              ),
            if (_canModerate)
              _ActionRow(
                icon: message.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: message.pinned ? S.unpin : S.pinToTop,
                t: t,
                onTap: () {
                  chatStore.setPinned(message.id, !message.pinned);
                  Navigator.of(sheetContext).pop();
                },
              ),
            _ActionRow(
              icon: Icons.person_outline_rounded,
              label: S.viewProfile,
              t: t,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openProfile(message.senderId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openProfile(String userId) {
    final index = peopleService.cachedPeople.indexWhere(
      (user) => user.id == userId,
    );
    if (index == -1) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            UserProfileScreen(user: peopleService.cachedPeople[index]),
      ),
    ).then((_) => _markVisibleMessagesSeen());
  }

  void _openClubProfile() {
    final club = _club;
    if (club == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubProfileScreen(club: club, color: _accent),
      ),
    ).then((_) => _markVisibleMessagesSeen());
  }

  void _openSettingsSheet() {
    final t = _t;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: t.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: t.borderB,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _ActionRow(
              icon: Icons.groups_2_outlined,
              label: S.openClubProfile,
              t: t,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openClubProfile();
              },
            ),
            if (_canModerate)
              _ActionRow(
                icon: Icons.campaign_outlined,
                label: S.postAsAnnouncement,
                t: t,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_composeAnnouncement());
                },
              ),
            if (_canChangeBackground)
              _ActionRow(
                icon: Icons.wallpaper_rounded,
                label: S.changeChatBackground,
                t: t,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openBackgroundSheet();
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Sheets ──────────────────────────────────────────────────────────────────

  String _backgroundLabel(ClubChatBackground background) =>
      switch (background) {
        ClubChatBackground.classic => S.backgroundClassic,
        ClubChatBackground.warm => S.backgroundWarm,
        ClubChatBackground.ocean => S.backgroundOcean,
        ClubChatBackground.forest => S.backgroundForest,
        ClubChatBackground.midnight => S.backgroundMidnight,
      };

  LinearGradient _backgroundGradient(
    ClubChatBackground background,
    ClubChatTheme t,
  ) {
    final colors = switch (background) {
      ClubChatBackground.classic => [
        t.body,
        Color.lerp(t.body, t.accent, t.isDark ? 0.10 : 0.055)!,
      ],
      ClubChatBackground.warm =>
        t.isDark
            ? const [Color(0xFF241A18), Color(0xFF321D22)]
            : const [Color(0xFFFFF8F0), Color(0xFFFDE9E8)],
      ClubChatBackground.ocean =>
        t.isDark
            ? const [Color(0xFF111D2B), Color(0xFF132C38)]
            : const [Color(0xFFF2F8FF), Color(0xFFE5F3F8)],
      ClubChatBackground.forest =>
        t.isDark
            ? const [Color(0xFF13221C), Color(0xFF1D2D24)]
            : const [Color(0xFFF2FAF5), Color(0xFFE5F3E9)],
      ClubChatBackground.midnight =>
        t.isDark
            ? const [Color(0xFF0B1020), Color(0xFF1B1730)]
            : const [Color(0xFFF0F2FC), Color(0xFFE8E6F7)],
    };
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  void _openBackgroundSheet() {
    if (!_canChangeBackground) return;
    final t = _t;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: t.sheet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.borderB,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  S.chatBackground,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final optionWidth = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final background in ClubChatBackground.values)
                          SizedBox(
                            width: optionWidth,
                            child: _backgroundOption(
                              background,
                              t,
                              selected:
                                  clubChatPrefs.backgroundFor(
                                    widget.threadId,
                                  ) ==
                                  background,
                              onTap: () {
                                clubChatPrefs.setBackground(
                                  widget.threadId,
                                  background,
                                );
                                setSheetState(() {});
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: t.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(S.done),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _backgroundOption(
    ClubChatBackground background,
    ClubChatTheme t, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: _backgroundLabel(background),
      child: GestureDetector(
        key: ValueKey('club-background-option-${background.name}'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: selected ? t.ltRed : t.solid,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? t.red : t.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: _backgroundGradient(background, t),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.chat_rounded,
                  size: 20,
                  color: selected ? t.red : t.sub,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _backgroundLabel(background),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: t.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSheetTab(ClubSheetTab tab) {
    setState(() => _openSheet = tab);
    if (tab == ClubSheetTab.members) {
      unawaited(_loadMemberDirectory(force: _membersLoadFailed));
    }
    final t = _t;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListenableBuilder(
        listenable: Listenable.merge([
          chatStore,
          userState,
          appPresenceService,
          rsvpStore,
          _memberDirectoryRevision,
        ]),
        builder: (sheetContext, _) => ClubCommunitySheet(
          t: t,
          initialTab: tab,
          builders: {
            ClubSheetTab.members: (context) => _membersPanel(t),
            ClubSheetTab.events: (context) => _eventsPanel(t),
            ClubSheetTab.notices: (context) => _noticesPanel(t),
          },
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _openSheet = null);
    });
  }

  Widget _membersPanel(ClubChatTheme t) {
    final people = _members;
    final online = people.where((person) => person.online).toList();
    final offline = people.where((person) => !person.online).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_membersLoading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: t.red,
              backgroundColor: t.border,
            ),
          ),
        if (_membersLoadFailed && people.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 4),
            child: Center(
              child: TextButton.icon(
                onPressed: () => unawaited(_loadMemberDirectory(force: true)),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(S.retryMembers),
                style: TextButton.styleFrom(foregroundColor: t.red),
              ),
            ),
          ),
        ClubSheetLabel(label: S.activeNowGroup(online.length), t: t),
        for (final person in online) _memberRow(person, t),
        ClubSheetLabel(label: S.offlineGroup(offline.length), t: t, top: true),
        for (final person in offline) _memberRow(person, t),
      ],
    );
  }

  Widget _memberRow(ClubPerson person, ClubChatTheme t) {
    return Padding(
      key: ValueKey('club-member-row-${person.id}'),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _avatarFor(person, 38),
              if (person.online)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: t.online,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.sheet, width: 2.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ClubRoleChip(
                      person: person,
                      t: t,
                      show: clubChatPrefs.showRoles,
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  person.online ? S.activeNowLabel : S.offlineLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: person.online ? t.online : t.sub,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              _openProfile(person.id);
            },
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.solid,
                shape: BoxShape.circle,
                border: Border.all(color: t.border),
              ),
              child: Icon(Icons.edit_outlined, size: 15, color: t.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventsPanel(ClubChatTheme t) {
    final upcoming = _clubEvents;
    if (upcoming.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            S.noUpcomingEvents,
            style: TextStyle(fontSize: 13, color: t.sub),
          ),
        ),
      );
    }
    return Column(
      children: [
        const SizedBox(height: 10),
        for (final event in upcoming)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _eventCard(event, compact: true),
          ),
      ],
    );
  }

  Widget _noticesPanel(ClubChatTheme t) {
    final notices = chatStore.announcementsIn(widget.threadId);
    if (notices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            S.nothingHere,
            style: TextStyle(fontSize: 13, color: t.sub),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final notice in notices)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.hair)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.ltRed,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    notice.pinned
                        ? Icons.push_pin_outlined
                        : Icons.campaign_outlined,
                    size: 15,
                    color: t.red,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title ?? notice.content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_personFor(notice.senderId).name} · '
                        '${_dayLabel(notice.createdAt)} · '
                        '${S.seenCount(chatStore.seenCountFor(notice))}',
                        style: TextStyle(fontSize: 11.5, color: t.sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.body,
      body: ListenableBuilder(
        listenable: Listenable.merge([
          chatStore,
          userState,
          appPresenceService,
          rsvpStore,
          ?_communityInfo,
        ]),
        builder: (context, _) {
          final club = _club;
          final canAccess = chatStore.canAccessThread(widget.threadId, _myId);
          final canOfferStudentJoin =
              club != null && !canAccess && authService.isStudentSession;
          if (club == null || (!canAccess && !canOfferStudentJoin)) {
            return SafeArea(bottom: false, child: _buildUnavailable(t));
          }
          return SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                _buildHeader(club, t),
                _buildContextBar(t),
                if (canAccess) ...[
                  _buildPinnedStrip(t),
                  Expanded(child: _buildStream(t)),
                  if (_canModerate)
                    ClubComposer(
                      controller: _inputController,
                      t: t,
                      hintText: S.communityComposerHint,
                      people: _members,
                      avatarBuilder: _avatarFor,
                      onSend: _send,
                      onAttach: (attachment) =>
                          unawaited(_handleAttachment(attachment)),
                      onTypingChanged: () =>
                          chatStore.setTyping(widget.threadId, _myId),
                    )
                  else
                    _buildFollowerActions(t),
                ] else
                  Expanded(child: _buildJoinPrompt(club, t)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Club club, ClubChatTheme t) {
    final memberCount =
        supabaseClubMemberCounts[club.id] ??
        _communityInfo?.memberCount ??
        clubMemberCount(club.id);
    return ClubCommunityHeader(
      club: club,
      avatarColor: _accent,
      memberCount: memberCount,
      onOpenClub: _openClubProfile,
      t: t,
      topInset: widget.embedded ? 0 : MediaQuery.viewPaddingOf(context).top,
      muted: clubChatPrefs.isMuted(widget.threadId),
      onBack: widget.embedded ? null : () => Navigator.maybePop(context),
      onToggleMute: () => clubChatPrefs.setMuted(
        widget.threadId,
        !clubChatPrefs.isMuted(widget.threadId),
      ),
      onOpenSettings: _openSettingsSheet,
    );
  }

  Widget _buildContextBar(ClubChatTheme t) {
    return ClubContextBar(
      t: t,
      onlinePeople: _members.where((person) => person.online).toList(),
      avatarBuilder: _avatarFor,
      eventCount: _clubEvents.length,
      noticeCount: chatStore.announcementsIn(widget.threadId).length,
      activeTab: _openSheet,
      onOpen: _openSheetTab,
    );
  }

  Widget _buildPinnedStrip(ClubChatTheme t) {
    final pinned = chatStore.pinnedMessageIn(widget.threadId);
    if (pinned == null || clubChatPrefs.isPinDismissed(pinned.id)) {
      return const SizedBox.shrink();
    }
    final headline = pinned.title ?? pinned.content;
    return ClubPinnedStrip(
      text: headline,
      t: t,
      onOpen: () => _openSheetTab(ClubSheetTab.notices),
      onDismiss: () => clubChatPrefs.dismissPin(pinned.id),
    );
  }

  Widget _withChatBackground(ClubChatTheme t, Widget child) {
    final background = clubChatPrefs.backgroundFor(widget.threadId);
    return Container(
      key: ValueKey('club-chat-background-${background.name}'),
      decoration: BoxDecoration(gradient: _backgroundGradient(background, t)),
      // The same campus wallpaper the student threads use, painted over the
      // club's chosen gradient so every option keeps its own tint. The ink
      // follows the club accent, matching the rest of the community theme.
      child: ChatCampusBackdrop(
        isDark: t.isDark,
        accent: t.accent,
        child: child,
      ),
    );
  }

  Widget _buildStream(ClubChatTheme t) {
    final messages = chatStore.messagesFor(widget.threadId, viewerId: _myId);
    final typing = chatStore
        .typingUserIds(widget.threadId, excluding: _myId)
        .map(_personFor)
        .toList();

    if (messages.isEmpty && typing.isEmpty) {
      final club = _club;
      // Same composition as an empty student thread: the room's own face, its
      // name, and one quiet line — no card on top of the wallpaper.
      return _withChatBackground(
        t,
        Stack(
          children: [
            _glow(t),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  key: const ValueKey('club-empty-conversation'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: t.red.withValues(alpha: t.isDark ? 0.13 : 0.07),
                        shape: BoxShape.circle,
                      ),
                      child: club == null
                          ? Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: t.red,
                              size: 40,
                            )
                          : ClubAvatar(
                              clubId: club.id,
                              clubName: club.name,
                              color: _accent,
                              imageUrl: club.logoUrl,
                              size: 72,
                              fontSize: 27,
                              shape: 'circle',
                            ),
                    ),
                    if (club != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        club.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.25,
                          color: t.text,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      S.sayHello,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final items = _buildStreamItems(messages, typing, t);
    return _withChatBackground(
      t,
      Stack(
        children: [
          _glow(t),
          ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
            itemCount: items.length,
            itemBuilder: (context, index) => items[items.length - 1 - index],
          ),
          if (_showJumpButton)
            Positioned(
              right: 14,
              bottom: 14,
              child: Semantics(
                button: true,
                label: S.jumpToLatest,
                child: GestureDetector(
                  key: const ValueKey('club-jump-to-latest'),
                  onTap: _scrollToLatest,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.sheet,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.borderB),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: t.red,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _glow(ClubChatTheme t) => Positioned(
    top: -20,
    left: 0,
    right: 0,
    height: 150,
    child: IgnorePointer(
      child: Center(
        child: Container(
          width: 280,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [t.glow, t.glow.withValues(alpha: 0)],
              stops: const [0, 0.7],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _buildStreamItems(
    List<ChatMessage> messages,
    List<ClubPerson> typing,
    ClubChatTheme t,
  ) {
    final items = <Widget>[];
    final style = clubChatPrefs.messageStyle;
    final showRoles = clubChatPrefs.showRoles;

    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final previous = i > 0 ? messages[i - 1] : null;
      final newDay =
          previous == null || !_sameDay(previous.createdAt, message.createdAt);
      if (newDay) {
        items.add(ClubDayMark(label: _dayLabel(message.createdAt), t: t));
      }
      if (_unreadAtOpen > 0 && message.id == _unreadAnchorMessageId) {
        items.add(
          KeyedSubtree(
            key: _unreadDividerKey,
            child: ClubUnreadDivider(count: _unreadAtOpen, t: t),
          ),
        );
      }

      switch (message.kind) {
        case ChatMessageKind.system:
          items.add(ClubSystemLine(label: message.content, t: t));
        case ChatMessageKind.announcement:
          final author = _personFor(message.senderId);
          items.add(
            ClubAnnouncementCard(
              message: message,
              author: author,
              avatar: _avatarFor(author, 24),
              t: t,
              emphasis: clubChatPrefs.announcementEmphasis,
              showRoles: showRoles,
              seenCount: chatStore.seenCountFor(message),
              timeLabel: _timeLabel(message.createdAt),
              onLongPress: () => _showMessageActions(message),
              reactions: message.reactions.isEmpty
                  ? null
                  : _reactionsFor(message, t),
            ),
          );
        case ChatMessageKind.poll:
          final author = _personFor(message.senderId);
          items.add(
            ClubPollMessageCard(
              message: message,
              author: author,
              avatar: _avatarFor(author, 20),
              t: t,
              myId: _myId,
              showRoles: showRoles,
              closesLabel: _pollClosesLabel(message),
              onVote: (index) => chatStore.votePoll(
                messageId: message.id,
                userId: _myId,
                optionIndex: index,
              ),
              onLongPress: () => _showMessageActions(message),
            ),
          );
        case ChatMessageKind.event:
          final event = _eventById(message.eventId);
          if (event != null) {
            items.add(_eventCard(event));
            break;
          }
          items.add(_messageGroup(message, previous, style, showRoles, t));
        case ChatMessageKind.text:
        case ChatMessageKind.postShare:
        case ChatMessageKind.photo:
        case ChatMessageKind.file:
          items.add(_messageGroup(message, previous, style, showRoles, t));
      }
    }

    if (typing.isNotEmpty) {
      items.add(
        ClubTypingRow(
          avatars: [
            for (final person in typing.take(2)) _avatarFor(person, 22),
          ],
          label: typing.length == 1
              ? S.typingOne(_firstName(typing.first.name))
              : S.typingMany(
                  typing.take(2).map((p) => _firstName(p.name)).join(' & '),
                ),
          t: t,
        ),
      );
    }
    return items;
  }

  Widget _reactionsFor(ChatMessage message, ClubChatTheme t) =>
      ClubReactionsRow(
        message: message,
        myId: _myId,
        t: t,
        onToggle: (emoji) => chatStore.toggleReaction(
          messageId: message.id,
          userId: _myId,
          emoji: emoji,
        ),
        onPick: () => _showMessageActions(message),
      );

  Widget _messageGroup(
    ChatMessage message,
    ChatMessage? previous,
    ClubMessageStyle style,
    bool showRoles,
    ClubChatTheme t,
  ) {
    final mine = chatStore.isMessageOwner(message, _myId);
    final sender = _personFor(message.senderId);
    final head =
        !mine ||
        previous == null ||
        previous.senderId != message.senderId ||
        previous.kind != ChatMessageKind.text ||
        message.kind != ChatMessageKind.text ||
        message.mentions.isNotEmpty ||
        !_sameDay(previous.createdAt, message.createdAt);

    return ClubMessageGroup(
      key: ValueKey('club-message-${message.id}'),
      message: message,
      sender: sender,
      avatar: _avatarFor(sender, 30),
      mine: mine,
      head: head,
      style: style,
      showRoles: showRoles,
      timeLabel: _timeLabel(message.createdAt),
      flagged: message.mentionsUser(_myId) && !mine,
      t: t,
      onLongPress: () => _showMessageActions(message),
      statusLabel: mine
          ? (chatStore.seenCountFor(message) > 1 ? S.seen : S.delivered)
          : null,
      attachments: [
        if (message.kind == ChatMessageKind.photo &&
            message.attachmentPath != null)
          ClubPhotoAttachment(path: message.attachmentPath!, t: t),
        if (message.kind == ChatMessageKind.file &&
            message.attachmentPath != null)
          ClubFileChip(
            message: message,
            t: t,
            onOpen: () => _showMessageActions(message),
          ),
        if (message.kind == ChatMessageKind.postShare &&
            message.sharedPostId != null)
          SharedPostMessageCard(postId: message.sharedPostId!),
      ],
      reactions: message.reactions.isEmpty ? null : _reactionsFor(message, t),
    );
  }

  Widget _eventCard(Event event, {bool compact = false, VoidCallback? onOpen}) {
    final t = _t;
    return ClubEventCard(
      key: ValueKey('club-event-${event.id}'),
      title: event.title,
      dayLabel: S.weekdayShort(event.dateTime.weekday),
      dateLabel: '${event.dateTime.day} ${S.monthShort(event.dateTime.month)}',
      clockLabel: _timeLabel(event.dateTime),
      place: event.location,
      goingCount: event.attendeeUserIds.length,
      going: rsvpStore.isAttending(event.id),
      t: t,
      compact: compact,
      onToggleRsvp: () => _toggleRsvp(event),
      onOpen: onOpen ?? () => _openEvent(event),
    );
  }

  Widget _buildJoinPrompt(Club club, ClubChatTheme t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClubAvatar(
              clubId: club.id,
              clubName: club.name,
              color: _accent,
              imageUrl: club.logoUrl,
              size: 72,
              fontSize: 28,
              shape: 'circle',
            ),
            const SizedBox(height: 18),
            Text(
              S.joinToChat,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.joinToChatHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: t.textMuted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              height: 44,
              child: ClubFollowButton(clubId: club.id, size: 'large'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailable(ClubChatTheme t) {
    return Column(
      key: const ValueKey('chat-unavailable'),
      children: [
        if (!widget.embedded)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: t.textMuted,
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 44, color: t.sub),
                  const SizedBox(height: 14),
                  Text(
                    'Conversation unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    "You don't have access to this conversation.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Labels ──────────────────────────────────────────────────────────────────

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _firstName(String name) => name.split(RegExp(r'\s+')).first;

  String _dayLabel(DateTime value) {
    final now = DateTime.now();
    if (_sameDay(value, now)) return S.today;
    if (_sameDay(value, now.subtract(const Duration(days: 1)))) {
      return S.yesterday;
    }
    return '${value.day} ${S.monthShort(value.month)}';
  }

  String _timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  String _pollClosesLabel(ChatMessage message) {
    final closes = message.pollClosesAt;
    if (closes == null) return '';
    if (message.pollIsClosed) return S.pollClosed;
    final remaining = closes.difference(DateTime.now());
    if (remaining.inHours < 24) {
      return S.pollCloses(S.pollHours(remaining.inHours.clamp(1, 23)));
    }
    return S.pollCloses(S.pollDays(remaining.inDays.clamp(1, 365)));
  }
}

// ── Small shared pieces ──────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  const _SheetField({
    super.key,
    required this.hint,
    required this.t,
    required this.onChanged,
    this.maxLines = 1,
    this.autofocus = false,
  });

  final String hint;
  final ClubChatTheme t;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: TextField(
        autofocus: autofocus,
        maxLines: maxLines,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: 14.5, color: t.text),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14.5, color: t.sub),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.t,
    required this.onTap,
  });

  final String label;
  final ClubChatTheme t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: t.meGradient,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.t,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ClubChatTheme t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: t.red),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
