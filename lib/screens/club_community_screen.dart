import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_media_selection.dart';
import '../models/chat_message.dart';
import '../models/club.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../navigation/chat_page_route.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/calendar_rsvp_helper.dart';
import '../services/chat_attachment_staging.dart';
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
import '../widgets/club_board_lane.dart';
import '../widgets/club_chat_theme.dart';
import '../widgets/club_community_header.dart';
import '../widgets/club_community_sheet.dart';
import '../widgets/club_composer.dart';
import '../widgets/club_follow_button.dart';
import '../widgets/club_stream_items.dart';
import '../widgets/user_avatar.dart';
import '../widgets/shared_post_message_card.dart';
import '../widgets/sent_message_entrance.dart';
import 'chat_thread_screen.dart';
import 'club_profile_screen.dart';
import 'event_detail_screen.dart';
import 'media_preview_screen.dart';
import 'user_profile_screen.dart';

/// The club room, in the Club Board + Chat handoff plus a private Solo Chat
/// surface.
///
/// **Board** is the official notice area and the landing lane: one grouped list,
/// one row per notice, and a composer only for members holding a role in the
/// club. **Chat** is the room — board-member replies, polls, photos and mentions live here,
/// and a notice appears as a card so the conversation around it still reads.
/// **Solo Chat** is the private inbox: one thread for a regular member, or all
/// student-to-club threads for board members and the linked club admin.
///
/// A notice is one object: the record published on the Board is the same message
/// that shows as a card in Chat. Replies never sit under a notice — "Reply in
/// chat" carries it across the lanes as a quote instead.
class ClubCommunityScreen extends StatefulWidget {
  const ClubCommunityScreen({
    super.key,
    required this.threadId,
    this.embedded = false,
    this.initialLane = ClubChatLane.board,
  });

  final String threadId;
  final bool embedded;

  /// Board is where a club room lands; deep links can open Chat directly.
  final ClubChatLane initialLane;

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
  /// moment the Chat lane is marked read.
  int _unreadAtOpen = 0;
  String? _unreadAnchorMessageId;

  /// Notices that were new when the Board was opened — the row dots survive the
  /// lane being marked read a frame later.
  Set<String> _unreadNoticeIds = const {};

  /// Which room tab is showing. Board is the landing tab.
  late ClubCommunityTab _tab = widget.initialLane == ClubChatLane.board
      ? ClubCommunityTab.board
      : ClubCommunityTab.chat;

  bool _showJumpButton = false;
  String? _animatingSentMessageId;
  ChatMessage? _replyingTo;

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

  /// Only members holding a role in this club get the Board's composer.
  bool get _canPostNotice => chatStore.canPostNotice(widget.threadId, _myId);

  /// Only the club's yönetim kurulu may talk in the Chat lane.
  bool get _canWrite => chatStore.canWriteThread(widget.threadId, _myId);

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
    if (chatStore.takeAttachmentUploadFailure()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(S.photoSavedLocallyUploadFailed)),
        );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // reverse:true — offset 0 is the newest message, at the bottom.
    final shouldShow = _scrollController.offset > 80;
    if (shouldShow != _showJumpButton) {
      setState(() => _showJumpButton = shouldShow);
    }
  }

  /// Snapshots what was new in each lane before either is marked read: the
  /// Board's row dots and the Chat lane's "You left off here" divider both need
  /// to survive the read receipt this same open writes.
  void _captureUnreadAnchor() {
    final unreadNotices = chatStore.unreadIdsInClubLane(
      widget.threadId,
      _myId,
      ClubChatLane.board,
    );
    final unreadChat = chatStore.unreadIdsInClubLane(
      widget.threadId,
      _myId,
      ClubChatLane.chat,
    );
    setState(() {
      _unreadNoticeIds = unreadNotices.toSet();
      _unreadAtOpen = unreadChat.length;
      _unreadAnchorMessageId = unreadChat.isEmpty ? null : unreadChat.first;
    });
  }

  void _switchTab(ClubCommunityTab tab) {
    if (_tab == tab) return;
    if (tab == ClubCommunityTab.solo) {
      setState(() => _tab = tab);
      return;
    }
    final lane = tab == ClubCommunityTab.board
        ? ClubChatLane.board
        : ClubChatLane.chat;
    // Whatever arrived in the other lane while it was hidden is still new to
    // this reader, so it keeps its dot / divider on the way in.
    final incoming = chatStore.unreadIdsInClubLane(
      widget.threadId,
      _myId,
      lane,
    );
    setState(() {
      _tab = tab;
      if (lane == ClubChatLane.board) {
        _unreadNoticeIds = {..._unreadNoticeIds, ...incoming};
      } else if (incoming.isNotEmpty) {
        _unreadAtOpen = incoming.length;
        _unreadAnchorMessageId = incoming.first;
      }
    });
    _markVisibleMessagesSeen();
    if (lane == ClubChatLane.chat) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealUnread());
    }
  }

  void _switchLane(ClubChatLane lane) {
    _switchTab(
      lane == ClubChatLane.board
          ? ClubCommunityTab.board
          : ClubCommunityTab.chat,
    );
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
    // One count per public segment: reading the Board never clears what is
    // waiting in Chat, and the other way round. Solo Chat owns separate inbox
    // threads, whose receipts are handled by ChatThreadScreen.
    if (_tab == ClubCommunityTab.board) {
      chatStore.markClubLaneRead(widget.threadId, _myId, ClubChatLane.board);
    } else if (_tab == ClubCommunityTab.chat) {
      chatStore.markClubLaneRead(widget.threadId, _myId, ClubChatLane.chat);
    }
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
      );
    }
    final adminIndex = clubAdmins.indexWhere((admin) => admin.id == userId);
    if (adminIndex != -1) {
      return ClubPerson(
        id: userId,
        name: clubAdmins[adminIndex].name,
        role: S.adminLabel,
        isClubAccount: true,
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
    );
  }

  /// Every member of the club, board members first, then A→Z.
  List<ClubPerson> get _members {
    final club = _club;
    if (club == null) return const [];
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
  //
  // Events left this surface with the Board + Chat design: the club's Events tab
  // owns them and nothing here can post one. Event cards that a club shared
  // before the change still render, so no history disappears from the room.

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
      ChatPageRoute(
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
      replyToMessageId: _replyingTo?.id,
    );
    if (sent == null) return;
    if (mounted) {
      setState(() {
        _replyingTo = null;
        _animatingSentMessageId = sent.id;
      });
    }
    _scrollToLatest();
  }

  void _finishSentMessageEntrance(String messageId) {
    if (!mounted || _animatingSentMessageId != messageId) return;
    setState(() => _animatingSentMessageId = null);
  }

  Future<String?> _ensureClubInboxThread() async {
    final club = _club;
    final profileId = authService.currentUser?.id ?? '';
    if (club == null || profileId.isEmpty) return null;
    return chatStore.ensureClubInboxThread(
      profileId: profileId,
      clubId: club.id,
    );
  }

  Future<void> _messageClubPrivately() async {
    final threadId = await _ensureClubInboxThread();
    if (!mounted) return;
    if (threadId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.secureChatUnavailable)));
      return;
    }
    await Navigator.push(
      context,
      ChatPageRoute(builder: (_) => ChatThreadScreen(threadId: threadId)),
    );
  }

  Future<void> _openSoloChatThread(String threadId) async {
    await Navigator.push(
      context,
      ChatPageRoute(builder: (_) => ChatThreadScreen(threadId: threadId)),
    );
    if (!mounted) return;
    _requestedParticipantProfileIds.removeWhere(
      (id) => !_hasResolvedProfile(id),
    );
    _hydrateVisibleParticipants();
  }

  List<ClubSoloChatEntry> _soloChatEntries() {
    final club = _club;
    if (club == null) return const [];
    final entries = <ClubSoloChatEntry>[];
    final summaries = chatStore
        .threadsFor(_myId)
        .where((thread) => thread.isClubInbox && thread.clubId == club.id);
    for (final summary in summaries) {
      final conversation = chatStore.clubInboxForThread(summary.threadId);
      if (conversation == null) continue;
      // A regular member sees only their own club inbox. Board members and
      // the linked club account see every student conversation for this club.
      if (!_canModerate && conversation.profileId != _myId) continue;
      final isOwnConversation = conversation.profileId == _myId;
      final person = isOwnConversation
          ? null
          : _personFor(conversation.profileId);
      final title = isOwnConversation
          ? club.name
          : (person?.name.trim().isNotEmpty == true
                ? person!.name
                : S.studentProfile);
      final last = summary.lastMessage;
      final preview = _soloChatPreview(last);
      entries.add(
        ClubSoloChatEntry(
          threadId: summary.threadId,
          title: title,
          preview: preview,
          whenLabel: last == null ? '' : _timeLabel(last.createdAt),
          unread: summary.unread,
          avatar: isOwnConversation
              ? ClubAvatar(
                  clubId: club.id,
                  clubName: club.name,
                  color: _accent,
                  imageUrl: club.logoUrl,
                  size: 46,
                  fontSize: 17,
                  shape: 'circle',
                )
              : UserAvatar(
                  userId: conversation.profileId,
                  name: title,
                  size: 46,
                  fontSize: 17,
                ),
        ),
      );
    }
    return entries;
  }

  String _soloChatPreview(ChatMessage? message) {
    if (message == null) return S.chatNoMessagesYet;
    final body = switch (message.kind) {
      ChatMessageKind.postShare => S.sharedPost,
      ChatMessageKind.photo => S.attachPhoto,
      ChatMessageKind.file => S.attachFile,
      ChatMessageKind.announcement =>
        (message.title ?? '').trim().isEmpty ? message.content : message.title!,
      _ => message.content,
    };
    final senderId = chatStore.senderIdForViewer(message, _myId);
    final sender = senderId == _myId ? S.you : _personFor(senderId).name;
    return sender.trim().isEmpty ? body : '$sender: $body';
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      // Flying back from deep in the history is an unreadable blur at this
      // duration, so close the gap first and animate only the last screenful.
      final animatedTravel = position.viewportDimension * 1.5;
      if (position.pixels > animatedTravel) {
        _scrollController.jumpTo(animatedTravel);
      }
      _scrollController.animateTo(
        0,
        duration: sentMessageEntranceDuration,
        curve: sentMessageEntranceCurve,
      );
    });
  }

  Future<void> _handleAttachment(ClubAttachment attachment) async {
    switch (attachment) {
      case ClubAttachment.photo:
        late final List<XFile> picked;
        try {
          picked = await ImagePicker().pickMultipleMedia(
            maxWidth: 2048,
            maxHeight: 2048,
            imageQuality: 88,
            limit: 30,
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(S.mediaSelectionFailed)));
          }
          return;
        }
        if (picked.isEmpty) return;
        final inspected = await inspectChatMediaFiles(picked);
        if (!mounted) return;
        if (inspected.rejectedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.mediaSelectionRejected(inspected.rejectedCount)),
            ),
          );
        }
        if (inspected.items.isEmpty) return;
        final result = await Navigator.of(context).push<MediaPreviewResult>(
          ChatPageRoute(
            builder: (_) => MediaPreviewScreen(
              initialMedia: inspected.items,
              initialCaption: _inputController.text.trim(),
            ),
          ),
        );
        if (!mounted || result == null) return;
        await _sendAttachments(result);
      case ClubAttachment.poll:
        await _composePoll();
    }
  }

  Future<void> _sendAttachments(MediaPreviewResult result) async {
    final sentMessages = <ChatMessage>[];
    var stagingFailed = false;
    for (final media in result.items) {
      late final String stagedPath;
      try {
        stagedPath = await stageChatAttachment(
          media.file.path,
          sourceName: media.file.name,
        );
      } on Object {
        stagingFailed = true;
        continue;
      }
      final isFirst = sentMessages.isEmpty;
      final caption = isFirst ? result.caption : '';
      final sent = chatStore.sendMessage(
        threadId: widget.threadId,
        senderId: _myId,
        content: caption,
        kind: media.type == ChatMediaType.image
            ? ChatMessageKind.photo
            : ChatMessageKind.file,
        mentions: isFirst
            ? ClubComposer.resolveMentions(caption, _members)
            : const [],
        attachmentPath: stagedPath,
        attachmentName: media.file.name,
        attachmentSize: media.sizeBytes,
        replyToMessageId: isFirst ? _replyingTo?.id : null,
      );
      if (sent != null) sentMessages.add(sent);
    }
    if (!mounted) return;
    if (sentMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stagingFailed ? S.couldNotAttachPhoto : S.mediaSendFailed,
          ),
        ),
      );
      return;
    }
    _inputController.clear();
    if (mounted) {
      setState(() {
        _replyingTo = null;
        _animatingSentMessageId = sentMessages.last.id;
      });
    }
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
    // One object: the notice is now both the newest row on the Board and a card
    // in Chat. Land the author on the Board, where they published it.
    if (mounted) setState(() => _tab = ClubCommunityTab.board);
  }

  // ── Message actions ─────────────────────────────────────────────────────────

  /// "Reply in chat": switches lanes and carries the message into the composer
  /// as a quote, so the Board never grows a comment thread of its own.
  void _replyInChat(ChatMessage message) {
    if (!_canWrite) return;
    setState(() {
      _replyingTo = message;
      _tab = ClubCommunityTab.chat;
    });
    _markVisibleMessagesSeen();
    _scrollToLatest();
  }

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
            if (_canWrite)
              _ActionRow(
                key: ValueKey('club-reply-message-${message.id}'),
                icon: Icons.reply_rounded,
                label: message.kind == ChatMessageKind.announcement
                    ? S.boardReplyInChat
                    : S.reply,
                t: t,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _replyInChat(message);
                },
              ),
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
    final currentUser = authService.currentUser;
    User? user = currentUser?.id == userId ? currentUser : null;
    final memberIndex = _memberUsers.indexWhere(
      (person) => person.id == userId,
    );
    if (user == null && memberIndex != -1) user = _memberUsers[memberIndex];
    final cachedIndex = peopleService.cachedPeople.indexWhere(
      (person) => person.id == userId,
    );
    if (user == null && cachedIndex != -1) {
      user = peopleService.cachedPeople[cachedIndex];
    }
    final knownIndex = users.indexWhere((person) => person.id == userId);
    if (user == null && knownIndex != -1) user = users[knownIndex];
    if (user == null) return;
    Navigator.push(
      context,
      ChatPageRoute(builder: (_) => UserProfileScreen(user: user!)),
    ).then((_) => _markVisibleMessagesSeen());
  }

  void _openParticipantProfile(ClubPerson person) {
    if (person.isClubAccount) {
      _openClubProfile();
      return;
    }
    _openProfile(person.id);
  }

  void _openClubProfile() {
    final club = _club;
    if (club == null) return;
    Navigator.push(
      context,
      ChatPageRoute(
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
            // Members and About moved behind this menu with the Board + Chat
            // design — the segments own navigation now.
            _ActionRow(
              key: const ValueKey('club-open-members'),
              icon: Icons.people_outline_rounded,
              label: S.communityMembersButton,
              t: t,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openMembersSheet();
              },
            ),
            _ActionRow(
              icon: Icons.groups_2_outlined,
              label: S.openClubProfile,
              t: t,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openClubProfile();
              },
            ),
            if (_canPostNotice)
              _ActionRow(
                icon: Icons.campaign_outlined,
                label: S.boardPostNotice,
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

  void _openMembersSheet() {
    unawaited(_loadMemberDirectory(force: _membersLoadFailed));
    final t = _t;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListenableBuilder(
        listenable: Listenable.merge([
          chatStore,
          userState,
          _memberDirectoryRevision,
        ]),
        builder: (sheetContext, _) => ClubCommunitySheet(
          t: t,
          title: S.communityMembersButton,
          builder: (context) => _membersPanel(t),
        ),
      ),
    );
  }

  Widget _membersPanel(ClubChatTheme t) {
    final people = _members;
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
        ClubSheetLabel(label: S.chatMembers(people.length), t: t),
        for (final person in people) _memberRow(person, t),
      ],
    );
  }

  Widget _memberRow(ClubPerson person, ClubChatTheme t) {
    return Padding(
      key: ValueKey('club-member-row-${person.id}'),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          _avatarFor(person, 38),
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

  // ── Build ───────────────────────────────────────────────────────────────────

  Widget _clubComposerReplyPreview(ChatMessage message, ClubChatTheme t) {
    // A quoted notice keeps its own treatment: "Reply in chat" is a lane jump,
    // so the composer says which notice this message is answering.
    if (message.kind == ChatMessageKind.announcement) {
      return ClubNoticeQuoteBar(
        title: (message.title ?? '').trim().isEmpty
            ? message.content
            : message.title!,
        t: t,
        onClear: () => setState(() => _replyingTo = null),
      );
    }
    final sender = _personFor(message.senderId).name;
    return Container(
      key: const ValueKey('club-reply-composer-preview'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: t.body,
        border: Border(
          top: BorderSide(color: t.hair),
          left: BorderSide(color: t.red, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.replyingTo(sender),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: t.red,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ChatStore.replyPreviewFor(message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: t.sub),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('club-cancel-reply'),
            tooltip: S.cancelReply,
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _replyingTo = null),
            icon: Icon(Icons.close_rounded, size: 18, color: t.sub),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.body,
      body: ListenableBuilder(
        listenable: Listenable.merge([
          chatStore,
          userState,
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
          if (!canAccess) {
            // Non-members get no Board and no Chat — only the invitation to
            // join, which is what the club profile offers them too.
            return SafeArea(
              top: false,
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(club, t),
                  Expanded(child: _buildJoinPrompt(club, t)),
                ],
              ),
            );
          }
          return SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                _buildHeader(club, t),
                ClubLaneSwitch(
                  tab: _tab,
                  onTab: _switchTab,
                  boardUnread: _laneUnread(ClubChatLane.board),
                  chatUnread: _laneUnread(ClubChatLane.chat),
                  soloUnread: _soloChatEntries().fold<int>(
                    0,
                    (total, entry) => total + entry.unread,
                  ),
                  t: t,
                ),
                Expanded(
                  child: _tab == ClubCommunityTab.board
                      ? _buildBoardLane(t)
                      : _tab == ClubCommunityTab.chat
                      ? _buildChatLane(t)
                      : _buildSoloChatLane(t),
                ),
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
      viewerRoleTitle: studentClubRoleService.roleTitleFor(club, _myId),
      // Inside the room the identity is not a link out: tapping it opens the
      // Chat lane. The club profile lives behind the ••• menu.
      onOpenClub: () => _switchTab(ClubCommunityTab.chat),
      t: t,
      topInset: widget.embedded ? 0 : MediaQuery.viewPaddingOf(context).top,
      muted: clubChatPrefs.isMuted(widget.threadId),
      onBack: widget.embedded ? null : () => Navigator.maybePop(context),
      onToggleMute: () => clubChatPrefs.setMuted(
        widget.threadId,
        !clubChatPrefs.isMuted(widget.threadId),
      ),
      onMessagePrivately: authService.isStudentSession && !_canPostNotice
          ? () => unawaited(_messageClubPrivately())
          : null,
      onOpenSettings: _openSettingsSheet,
    );
  }

  /// The count on a segment: what is waiting in the lane the reader is not
  /// looking at. The lane on screen is being read, so it shows nothing.
  int _laneUnread(ClubChatLane lane) {
    final tab = lane == ClubChatLane.board
        ? ClubCommunityTab.board
        : ClubCommunityTab.chat;
    if (_tab == tab) return 0;
    return chatStore.unreadInClubLane(widget.threadId, _myId, lane);
  }

  Widget _buildSoloChatLane(ClubChatTheme t) {
    final entries = _soloChatEntries();
    return ClubSoloChatLane(
      showAll: _canModerate,
      entries: entries,
      t: t,
      onOpen: (threadId) => unawaited(_openSoloChatThread(threadId)),
      onStart: _canModerate ? null : () => unawaited(_messageClubPrivately()),
    );
  }

  // ── Board lane ──────────────────────────────────────────────────────────────

  /// One grouped list of notices — pinned ("Always here"), then new, then
  /// earlier — with the composer or the route into Chat underneath.
  Widget _buildBoardLane(ClubChatTheme t) {
    final notices = chatStore.noticesIn(widget.threadId);
    final pinned = notices.where((notice) => notice.pinned).toList();
    final rest = notices.where((notice) => !notice.pinned).toList();
    final fresh = rest
        .where((notice) => _unreadNoticeIds.contains(notice.id))
        .toList();
    final earlier = rest
        .where((notice) => !_unreadNoticeIds.contains(notice.id))
        .toList();

    return Column(
      children: [
        Expanded(
          child: notices.isEmpty
              ? ClubBoardEmpty(t: t, canPost: _canPostNotice)
              : ListView(
                  key: const ValueKey('club-board-list'),
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                  children: [
                    if (pinned.isNotEmpty) ...[
                      ClubBoardLabel(label: S.boardGroupPinned, t: t),
                      _noticeGroup(pinned, t),
                    ],
                    if (fresh.isNotEmpty) ...[
                      ClubBoardLabel(
                        label: S.boardGroupNew(fresh.length),
                        t: t,
                        top: pinned.isNotEmpty,
                      ),
                      _noticeGroup(fresh, t),
                    ],
                    if (earlier.isNotEmpty) ...[
                      ClubBoardLabel(
                        label: S.boardGroupEarlier,
                        t: t,
                        top: pinned.isNotEmpty || fresh.isNotEmpty,
                      ),
                      _noticeGroup(earlier, t),
                    ],
                  ],
                ),
        ),
        if (_canPostNotice)
          ClubBoardPostBar(
            t: t,
            onPost: () => unawaited(_composeAnnouncement()),
          )
        else
          // No disabled button for a member without a role — the strip states
          // the rule and doubles as the doorway into Chat.
          ClubBoardLockedStrip(
            t: t,
            onGoToChat: () => _switchLane(ClubChatLane.chat),
          ),
      ],
    );
  }

  Widget _noticeGroup(List<ChatMessage> notices, ClubChatTheme t) {
    return ClubNoticeGroup(
      t: t,
      rows: [
        for (var i = 0; i < notices.length; i++)
          _noticeRow(notices[i], t, last: i == notices.length - 1),
      ],
    );
  }

  Widget _noticeRow(ChatMessage notice, ClubChatTheme t, {required bool last}) {
    final author = _personFor(notice.senderId);
    return ClubNoticeRow(
      key: ValueKey('club-notice-row-${notice.id}'),
      message: notice,
      author: author,
      avatar: _avatarFor(author, 22),
      whenLabel:
          '${_dayLabel(notice.createdAt)} · '
          '${_timeLabel(notice.createdAt)}',
      unread: _unreadNoticeIds.contains(notice.id),
      replyCount: chatStore.replyCountFor(notice.id),
      replyEnabled: _canWrite,
      showRoles: clubChatPrefs.showRoles,
      last: last,
      t: t,
      onReplyInChat: () => _replyInChat(notice),
      onLongPress: () => _showMessageActions(notice),
      onOpenAuthor: () => _openParticipantProfile(author),
      attachments: [
        if (notice.kind == ChatMessageKind.announcement &&
            notice.attachmentPath != null)
          notice.attachmentName != null &&
                  _looksLikeImage(notice.attachmentName!)
              ? ClubPhotoAttachment(path: notice.attachmentPath!, t: t)
              : ClubFileChip(
                  message: notice,
                  t: t,
                  onOpen: () => _showMessageActions(notice),
                ),
      ],
      reactions: notice.reactions.isEmpty ? null : _reactionsFor(notice, t),
    );
  }

  static bool _looksLikeImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');
  }

  // ── Chat lane ───────────────────────────────────────────────────────────────

  Widget _buildChatLane(ClubChatTheme t) {
    return Column(
      children: [
        Expanded(child: _buildStream(t)),
        if (_canWrite)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyingTo case final replied?)
                _clubComposerReplyPreview(replied, t),
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
              ),
            ],
          )
        else
          Container(
            key: const ValueKey('club-chat-locked-strip'),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 13, 18, 16),
            decoration: BoxDecoration(
              color: t.body,
              border: Border(top: BorderSide(color: t.hair)),
            ),
            child: SafeArea(
              top: false,
              child: Text(
                S.clubChannelReadOnly,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t.sub,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
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
              timeLabel: _timeLabel(message.createdAt),
              replyCount: chatStore.replyCountFor(message.id),
              onReplyInChat: _canWrite ? () => _replyInChat(message) : null,
              onLongPress: () => _showMessageActions(message),
              onOpenAuthor: () => _openParticipantProfile(author),
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
              onOpenAuthor: () => _openParticipantProfile(author),
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
    final sender = _personFor(message.senderId);
    // A club admin is the authenticated actor, but the public community
    // message is authored by the club. Keep ownership separate for actions
    // such as delete, while rendering the club account as an incoming sender
    // so its logo and identity remain visible to everyone — including the
    // admin who sent it.
    final isClubAuthoredMessage =
        ChatStore.isClubThread(message.threadId) && sender.isClubAccount;
    final mine =
        !isClubAuthoredMessage && chatStore.isMessageOwner(message, _myId);
    final head =
        !mine ||
        previous == null ||
        previous.senderId != message.senderId ||
        previous.kind != ChatMessageKind.text ||
        message.kind != ChatMessageKind.text ||
        message.replyToMessageId != null ||
        message.mentions.isNotEmpty ||
        !_sameDay(previous.createdAt, message.createdAt);

    return SentMessageEntrance(
      key: ValueKey('sent-message-entrance-${message.id}'),
      animate: message.id == _animatingSentMessageId,
      onCompleted: () => _finishSentMessageEntrance(message.id),
      child: ClubMessageGroup(
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
        replySenderName: message.replyToSenderId == null
            ? null
            : _personFor(message.replyToSenderId!).name,
        onLongPress: () => _showMessageActions(message),
        onOpenSender: () => _openParticipantProfile(sender),
        statusLabel: mine
            ? (chatStore.seenCountFor(message) > 1 ? S.seen : S.delivered)
            : null,
        attachments: [
          if (message.kind == ChatMessageKind.photo &&
              message.attachmentPath != null)
            ClubPhotoAttachment(path: message.attachmentPath!, t: t),
          if (message.kind == ChatMessageKind.file &&
              message.attachmentPath != null &&
              isVideoMediaPath(
                message.attachmentName ?? message.attachmentPath!,
              ))
            ClubVideoAttachment(path: message.attachmentPath!, t: t),
          if (message.kind == ChatMessageKind.file &&
              message.attachmentPath != null &&
              !isVideoMediaPath(
                message.attachmentName ?? message.attachmentPath!,
              ))
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
      ),
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
          // The container above paints the club-tinted input background; the
          // global inputDecorationTheme would stack a neutral grey over it.
          filled: false,
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
