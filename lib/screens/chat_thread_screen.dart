import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_message.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../navigation/chat_page_route.dart';
import '../services/app_colors.dart';
import '../services/app_presence_service.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/club_admin_access.dart';
import '../services/club_community_info_controller.dart';
import '../services/locale_service.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/theme_service.dart';
import '../services/user_state.dart';
import '../widgets/chat_campus_backdrop.dart';
import '../widgets/club_avatar.dart';
import '../widgets/group_avatar_stack.dart';
import '../widgets/presence_avatar.dart';
import '../widgets/user_avatar.dart';
import '../widgets/shared_post_message_card.dart';
import '../widgets/sent_message_entrance.dart';
import 'club_community_screen.dart';
import 'club_profile_screen.dart';
import 'group_info_screen.dart';
import 'user_profile_screen.dart';

/// What the composer's "+" sheet can attach to a student message.
enum _ChatAttachment { photo, camera }

/// The presence green shared by the header dot and the avatar dots.
const Color _onlineGreen = Color(0xFF2E7D32);

/// A single direct message, student-created group, or club community thread.
class ChatThreadScreen extends StatefulWidget {
  final String threadId;
  final User? recipient;
  final bool embedded;

  const ChatThreadScreen({
    super.key,
    required this.threadId,
    this.recipient,
    this.embedded = false,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen>
    with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<String> _requestedParticipantProfileIds = {};
  ClubCommunityInfoController? _communityInfo;
  String? _animatingSentMessageId;

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  bool get _isClub => ChatStore.isClubThread(widget.threadId);
  bool get _isClubInbox => ChatStore.isClubInboxThread(widget.threadId);
  bool get _isGroup => ChatStore.isGroupThread(widget.threadId);
  bool get _isDirect => ChatStore.isDirectThread(widget.threadId);

  Club? get _club {
    final clubId =
        ChatStore.clubIdOf(widget.threadId) ??
        chatStore.clubInboxForThread(widget.threadId)?.clubId;
    return clubId == null ? null : clubForId(clubId);
  }

  ClubInboxConversation? get _clubInbox =>
      chatStore.clubInboxForThread(widget.threadId);

  User? _userForId(String userId) {
    final passedRecipient = widget.recipient;
    if (passedRecipient != null && passedRecipient.id == userId) {
      return passedRecipient;
    }
    final currentUser = authService.currentUser;
    if (currentUser != null && currentUser.id == userId) return currentUser;
    final cachedIndex = peopleService.cachedPeople.indexWhere(
      (user) => user.id == userId,
    );
    if (cachedIndex != -1) return peopleService.cachedPeople[cachedIndex];
    final knownIndex = users.indexWhere((user) => user.id == userId);
    if (knownIndex != -1) return users[knownIndex];
    return null;
  }

  User? get _peer {
    final peerId = ChatStore.dmPeerOf(widget.threadId, _myId);
    return peerId == null ? null : _userForId(peerId);
  }

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
    final club = _club;
    if (club != null) {
      _communityInfo = ClubCommunityInfoController(
        clubId: club.id,
        fallbackMemberCount: clubMemberCount(club.id),
        fallbackMemberIds: clubMembers(club.id).map((member) => member.id),
      );
    }
    WidgetsBinding.instance.addObserver(this);
    themeService.addListener(_onEnvChanged);
    localeService.addListener(_onEnvChanged);
    chatStore.addListener(_onStoreChanged);
    // Post-frame: both can notifyListeners, which is illegal while this
    // route is still mounting mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final canAccess = chatStore.canAccessThread(widget.threadId, _myId);
      if (_isClub && (canAccess || authService.isStudentSession)) {
        unawaited(_communityInfo?.start());
      }
      if (!canAccess) return;
      if (_isDirect || _isGroup) {
        unawaited(chatStore.startDirectMessageSync(_myId));
      }
      if (_isClub || _isClubInbox) {
        unawaited(chatStore.startClubMessageSync(_myId));
      }
      if (_isDirect) {
        final peerId = ChatStore.dmPeerOf(widget.threadId, _myId);
        if (peerId != null) {
          chatStore.ensureDirectThread(_myId, peerId);
          unawaited(_hydratePeerProfile(peerId));
        }
      } else if (_isClub || _isGroup || _isClubInbox) {
        _hydrateVisibleParticipants();
      }
      // Only a visible, foreground conversation may create Seen receipts.
      _markVisibleMessagesSeen();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeService.removeListener(_onEnvChanged);
    localeService.removeListener(_onEnvChanged);
    chatStore.removeListener(_onStoreChanged);
    _communityInfo?.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isDirect) {
          final peerId = ChatStore.dmPeerOf(widget.threadId, _myId);
          if (peerId != null && _userForId(peerId) == null) {
            unawaited(_hydratePeerProfile(peerId));
          }
        } else {
          _requestedParticipantProfileIds.removeWhere(
            (id) => _userForId(id) == null,
          );
          _hydrateVisibleParticipants();
        }
        _markVisibleMessagesSeen();
      });
    }
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

  void _onEnvChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _hydratePeerProfile(String peerId) async {
    await peopleService.hydrateProfilesByIds([peerId]);
    if (mounted) setState(() {});
  }

  void _hydrateVisibleParticipants() {
    if ((!_isClub && !_isGroup && !_isClubInbox) ||
        !chatStore.canAccessThread(widget.threadId, _myId)) {
      return;
    }
    final participantIds =
        <String>{
            if (_isGroup) ...chatStore.groupParticipants(widget.threadId),
            if (_clubInbox case final inbox?) inbox.profileId,
            ...chatStore
                .messagesFor(widget.threadId, viewerId: _myId)
                .map((message) => message.senderId),
          }
          ..remove(_myId)
          ..removeAll(_requestedParticipantProfileIds);
    if (participantIds.isEmpty) return;
    _requestedParticipantProfileIds.addAll(participantIds);
    unawaited(
      peopleService.hydrateProfilesByIds(participantIds).then((_) {
        _requestedParticipantProfileIds.removeWhere(
          (id) => _userForId(id) == null,
        );
        if (mounted) setState(() {});
      }),
    );
  }

  /// Messages arriving while the thread is open are read immediately.
  /// Safe from notify loops: markThreadRead only notifies when something
  /// actually was unread.
  void _onStoreChanged() {
    if (!mounted) return;
    _hydrateVisibleParticipants();
    _markVisibleMessagesSeen();
  }

  /// Sends the composer draft, or [text] when a starter chip was tapped.
  void _send({String? text}) {
    final sent = chatStore.sendMessage(
      threadId: widget.threadId,
      senderId: _myId,
      content: text ?? _inputController.text,
    );
    if (sent == null) return;
    if (text == null) _inputController.clear();
    if (text == null && mounted) {
      setState(() => _animatingSentMessageId = sent.id);
    }
    _scrollToLatest();
  }

  void _finishSentMessageEntrance(String messageId) {
    if (!mounted || _animatingSentMessageId != messageId) return;
    setState(() => _animatingSentMessageId = null);
  }

  void _scrollToLatest() {
    // reverse:true list — offset 0 is the newest message at the bottom.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 440),
          curve: const Cubic(0.20, 0.72, 0.24, 1),
        );
      }
    });
  }

  // ── Attachments ─────────────────────────────────────────────────────────────

  Future<void> _openAttachSheet() async {
    final picked = await showModalBottomSheet<_ChatAttachment>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        key: const ValueKey('chat-attach-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: AppColors.card,
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
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              S.attachToMessage,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 6),
            for (final (attachment, icon, label) in [
              (_ChatAttachment.photo, Icons.image_outlined, S.attachPhoto),
              (
                _ChatAttachment.camera,
                Icons.photo_camera_outlined,
                S.takePhoto,
              ),
            ])
              InkWell(
                key: ValueKey('chat-attach-${attachment.name}'),
                onTap: () => Navigator.pop(sheetContext, attachment),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.lightRed,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          icon,
                          size: 17,
                          color: AppColors.primaryRed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _pickAttachment(picked);
  }

  Future<void> _pickAttachment(_ChatAttachment attachment) async {
    final XFile? picked = switch (attachment) {
      _ChatAttachment.photo => await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      ),
      _ChatAttachment.camera => await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      ),
    };
    if (picked == null || !mounted) return;
    _sendAttachment(picked, ChatMessageKind.photo);
  }

  void _sendAttachment(XFile file, ChatMessageKind kind) {
    var size = 0;
    try {
      size = File(file.path).lengthSync();
    } on FileSystemException {
      size = 0;
    }
    final sent = chatStore.sendMessage(
      threadId: widget.threadId,
      senderId: _myId,
      content: _inputController.text.trim(),
      kind: kind,
      attachmentPath: file.path,
      attachmentName: file.name,
      attachmentSize: size,
    );
    if (sent == null) return;
    _inputController.clear();
    if (mounted) setState(() => _animatingSentMessageId = sent.id);
    _scrollToLatest();
  }

  // ── Reactions ───────────────────────────────────────────────────────────────

  static const _quickReactions = ['👍', '❤️', '🎉', '👏', '😂', '🙌'];

  Future<void> _confirmDeleteMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.deleteMessage),
        content: Text(S.deleteMessageMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              S.delete,
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      chatStore.deleteMessage(messageId: message.id, userId: _myId);
    }
  }

  void _openReactionPicker(ChatMessage message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        key: const ValueKey('chat-reaction-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final emoji in _quickReactions)
                  GestureDetector(
                    key: ValueKey('chat-reaction-option-$emoji'),
                    onTap: () {
                      chatStore.toggleReaction(
                        messageId: message.id,
                        userId: _myId,
                        emoji: emoji,
                      );
                      Navigator.pop(sheetContext);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            (message.reactions[emoji] ?? const []).contains(
                              _myId,
                            )
                            ? AppColors.lightRed
                            : AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.glassEdge),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
            if (chatStore.isMessageOwner(message, _myId)) ...[
              const SizedBox(height: 8),
              Divider(color: AppColors.divider),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  key: ValueKey('chat-delete-message-${message.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.primaryRed,
                  ),
                  title: Text(
                    S.deleteMessage,
                    style: TextStyle(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_confirmDeleteMessage(message));
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Sender identity ─────────────────────────────────────────────────────────

  /// Display name + whether the sender is a club-admin account.
  (String, bool) _senderInfo(String senderId) {
    final club = _club;
    if (club != null &&
        (senderId == club.id ||
            club.adminUserIds.contains(senderId) ||
            managedClubForAdmin(senderId)?.id == club.id)) {
      return (club.name, true);
    }
    final user = _userForId(senderId);
    if (user != null) {
      return (userState.displayNameFor(senderId, user.name), false);
    }
    final aIdx = clubAdmins.indexWhere((a) => a.id == senderId);
    if (aIdx != -1) return (clubAdmins[aIdx].name, true);
    if (senderId == appAdmin.id) return (appAdmin.name, true);
    return (userState.displayNameFor(senderId, ''), false);
  }

  void _openHeaderProfile() {
    if (_isClubInbox) {
      final conversation = _clubInbox;
      if (conversation != null && conversation.profileId != _myId) {
        _openUserProfileById(conversation.profileId);
        return;
      }
    }
    final club = _club;
    if (club != null) {
      Navigator.push(
        context,
        ChatPageRoute(
          builder: (_) =>
              ClubProfileScreen(club: club, color: _colorForClub(club.id)),
        ),
      ).then((_) => _markVisibleMessagesSeen());
      return;
    }
    if (_isGroup) {
      Navigator.push(
        context,
        ChatPageRoute(
          builder: (_) =>
              GroupInfoScreen(threadId: widget.threadId, myId: _myId),
        ),
      ).then((leftGroup) {
        if (leftGroup == true && mounted) {
          Navigator.pop(context);
        } else {
          _markVisibleMessagesSeen();
        }
      });
      return;
    }
    final peer = _peer;
    if (peer != null) {
      Navigator.push(
        context,
        ChatPageRoute(builder: (_) => UserProfileScreen(user: peer)),
      ).then((_) => _markVisibleMessagesSeen());
    }
  }

  void _openUserProfileById(String userId) {
    final user = _userForId(userId);
    if (user == null) return;
    Navigator.push(
      context,
      ChatPageRoute(builder: (_) => UserProfileScreen(user: user)),
    ).then((_) => _markVisibleMessagesSeen());
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Club rooms get the dedicated community layout (single stream with
    // announcements, polls, events, and the members / notices panels).
    if (_isClub) {
      return ClubCommunityScreen(
        threadId: widget.threadId,
        embedded: widget.embedded,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: _ConversationBackdrop(
              isDark: themeService.isDark,
              accent: AppColors.primaryRed,
            ),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([
              chatStore,
              userState,
              appPresenceService,
              ?_communityInfo,
            ]),
            builder: (context, _) {
              final canAccess = chatStore.canAccessThread(
                widget.threadId,
                _myId,
              );
              if (!canAccess) {
                return SafeArea(
                  bottom: false,
                  child: _buildUnavailableConversation(),
                );
              }
              final messages = chatStore.messagesFor(
                widget.threadId,
                viewerId: _myId,
              );
              // The header takes the status-bar inset itself, so the solid bar
              // runs to the top of the screen rather than leaving a patterned
              // band above it.
              return SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildMessageList(messages)),
                    _buildInputBar(
                      enabled: chatStore.canWriteThread(widget.threadId, _myId),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Header (back + identity + status, tap for profile peek) ────────────────

  Widget _buildHeader() {
    if (_isGroup) return _buildGroupHeader();
    if (_isClubInbox) return _buildClubInboxHeader();
    final peer = _peer;
    final peerId = ChatStore.dmPeerOf(widget.threadId, _myId);
    final name = peer != null
        ? userState.displayNameFor(peer.id, peer.name)
        : '';
    final online = appPresenceService.onlineUserIds.contains(peerId ?? '');
    final academicSummary = userState.academicSummaryFor(peerId ?? '');

    return _headerShell(
      leading: PresenceAvatar(
        userId: peer?.id ?? peerId ?? '',
        name: peer?.name ?? '',
        size: 38,
        fontSize: 15,
        online: online,
      ),
      title: name,
      // Presence leads, and the peer's programme trails it so the header still
      // says who you are talking to.
      subtitle: Row(
        children: [
          if (online) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: _onlineGreen,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            online ? S.activeNowLabel : S.lastSeenRecently,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: online ? _onlineGreen : AppColors.secondaryText,
            ),
          ),
          if (academicSummary.isNotEmpty) ...[
            _subtitleDot(),
            Flexible(
              child: Text(
                academicSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClubInboxHeader() {
    final conversation = _clubInbox;
    final club = _club;
    final showingStudent =
        conversation != null && conversation.profileId != _myId;
    final student = showingStudent ? _userForId(conversation.profileId) : null;
    final title = showingStudent
        ? userState.displayNameFor(conversation.profileId, student?.name ?? '')
        : club?.name ?? '';
    final subtitle = showingStudent ? S.clubInbox : S.privateClubMessage;
    return Container(
      padding: EdgeInsets.fromLTRB(
        10,
        (widget.embedded ? 0 : MediaQuery.viewPaddingOf(context).top) + 6,
        12,
        8,
      ),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(
          alpha: themeService.isDark ? 0.94 : 0.97,
        ),
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          if (!widget.embedded) ...[
            IconButton(
              key: const ValueKey('chat-thread-back'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
              color: AppColors.secondaryText,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: InkWell(
              key: const ValueKey('club-inbox-profile-header'),
              onTap: _openHeaderProfile,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    if (showingStudent)
                      PresenceAvatar(
                        userId: conversation.profileId,
                        name: title,
                        size: 40,
                        fontSize: 15,
                        online: appPresenceService.onlineUserIds.contains(
                          conversation.profileId,
                        ),
                      )
                    else if (club != null)
                      ClubAvatar(
                        clubId: club.id,
                        clubName: club.name,
                        color: _colorForClub(club.id),
                        imageUrl: club.logoUrl,
                        size: 40,
                        fontSize: 15,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.lock_rounded, size: 17, color: AppColors.secondaryText),
        ],
      ),
    );
  }

  Widget _buildGroupHeader() {
    final memberIds = chatStore.groupParticipants(widget.threadId);
    final visibleIds = memberIds.where((id) => id != _myId).toList();
    final title = chatStore.groupDisplayName(widget.threadId, _myId);
    return _headerShell(
      tapKey: const ValueKey('group-chat-header'),
      // The stacked avatars bleed ~10% past their own box on both axes, so
      // reserve the extra room instead of letting them crowd the back button
      // and the title, or sit low against the subtitle.
      leading: const SizedBox(width: 43, height: 43),
      leadingOverlay: GroupAvatarStack(
        memberIds: visibleIds,
        nameForUser: (id) => _senderInfo(id).$1,
        photoPath: chatStore.groupForThread(widget.threadId)?.photoUrl,
        size: 38,
      ),
      title: title,
      subtitle: Text(
        S.chatPeopleCount(memberIds.length),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryText,
        ),
      ),
      showChevron: true,
    );
  }

  Widget _subtitleDot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Text(
      '·',
      style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
    ),
  );

  /// One bar for both thread kinds: back button, identity, optional drill-in
  /// chevron. Keeping the metrics in a single place stops the direct-message
  /// and group headers from drifting apart.
  Widget _headerShell({
    required Widget leading,
    required String title,
    required Widget subtitle,
    Widget? leadingOverlay,
    Key? tapKey,
    bool showChevron = false,
  }) {
    return Container(
      // A solid bar, so the campus wallpaper stops cleanly at the header edge
      // instead of showing through behind the name.
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        10,
        // viewPadding remains stable even if an ancestor SafeArea has already
        // consumed MediaQuery.padding, keeping the controls below the status
        // bar and Dynamic Island on every pushed chat route.
        (widget.embedded ? 0 : MediaQuery.viewPaddingOf(context).top) + 6,
        12,
        8,
      ),
      child: Row(
        children: [
          if (!widget.embedded) ...[
            // Circular and tinted, rhyming with the composer's buttons — a bare
            // chevron at the screen edge reads as detached.
            Semantics(
              button: true,
              label: MaterialLocalizations.of(context).backButtonTooltip,
              child: GestureDetector(
                key: const ValueKey('chat-thread-back'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.maybePop(context),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: InkWell(
              key: tapKey,
              onTap: _openHeaderProfile,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  children: [
                    if (leadingOverlay == null)
                      leading
                    else
                      Stack(
                        clipBehavior: Clip.none,
                        children: [leading, leadingOverlay],
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: 1.15,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          subtitle,
                        ],
                      ),
                    ),
                    if (showChevron) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 19,
                        color: AppColors.secondaryText,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableConversation() {
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
                color: AppColors.secondaryText,
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
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 44,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Conversation unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'You don\'t have access to this conversation.',
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
      ],
    );
  }

  // ── New-chat intro card ─────────────────────────────────────────────────────

  /// Headline for an empty thread: who you are about to talk to.
  String _introHeadline() {
    if (_isGroup) return chatStore.groupDisplayName(widget.threadId, _myId);
    final peer = _peer;
    final name = peer == null
        ? ''
        : userState.displayNameFor(peer.id, peer.name);
    return name.isEmpty ? S.startConversation : name;
  }

  /// The single quiet line under the name: what you already have in common
  /// with a peer, or who is in a new group. Falls back to plainly naming the
  /// state without adding another instruction to the empty conversation.
  String _introContext() {
    if (_isGroup) {
      final group = chatStore.groupForThread(widget.threadId);
      final count = chatStore.groupParticipants(widget.threadId).length;
      final people = S.chatPeopleCount(count);
      return group?.creatorId == _myId
          ? '$people · ${S.chatCreatedByYou}'
          : people;
    }
    final peer = _peer;
    if (peer == null) return S.chatNoMessagesYet;
    final parts = <String>[];
    final sharedClubId = peer.subscribedClubIds.firstWhere(
      (clubId) => userState.followedClubIds.contains(clubId),
      orElse: () => '',
    );
    final sharedClub = sharedClubId.isEmpty ? null : clubForId(sharedClubId);
    if (sharedClub != null) {
      parts.add(S.chatAlsoIn(_shortClubName(sharedClub)));
    }
    final mutuals = userState.followedUserIds
        .intersection(peer.followingUserIds.toSet())
        .length;
    if (mutuals > 0) parts.add(S.chatMutualFriends(mutuals));
    return parts.isEmpty ? S.chatNoMessagesYet : parts.join(' · ');
  }

  static String _shortClubName(Club club) {
    final shortName = club.shortName?.trim() ?? '';
    if (shortName.isNotEmpty) return shortName;
    final parenthetical = RegExp(r'\(([^)]+)\)').firstMatch(club.name);
    return parenthetical?.group(1) ?? club.name;
  }

  Widget _buildNewChatIntro() {
    final memberIds = _isGroup
        ? chatStore
              .groupParticipants(widget.threadId)
              .where((id) => id != _myId)
              .toList()
        : const <String>[];
    final peer = _peer;
    final peerId = ChatStore.dmPeerOf(widget.threadId, _myId);
    final context_ = _introContext();

    // No panel, no border, no divider: the backdrop already gives the area
    // texture, so a boxed card here read as a stranded dialog. What is left is
    // who you are talking to, and one quiet line of context.
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            key: const ValueKey('chat-empty-conversation-card'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isGroup)
                // The stack is wider than it is tall, so a circular halo would
                // sit visibly off-centre behind it — the overlap already reads
                // as a deliberate shape on its own.
                GroupAvatarStack(
                  memberIds: memberIds,
                  nameForUser: (id) => _senderInfo(id).$1,
                  photoPath: chatStore
                      .groupForThread(widget.threadId)
                      ?.photoUrl,
                  size: 62,
                )
              else
                // A soft accent halo keeps the avatar from floating unanchored
                // now that the card behind it is gone.
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryRed.withValues(
                      alpha: themeService.isDark ? 0.13 : 0.07,
                    ),
                  ),
                  child: PresenceAvatar(
                    userId: peer?.id ?? peerId ?? '',
                    name: peer?.name ?? '',
                    size: 72,
                    fontSize: 27,
                    online: appPresenceService.onlineUserIds.contains(
                      peerId ?? '',
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                _introHeadline(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.text,
                ),
              ),
              if (context_.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  context_,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Message list ────────────────────────────────────────────────────────────

  Widget _buildMessageList(List<ChatMessage> messages) {
    if (messages.isEmpty) return _buildNewChatIntro();

    final items = _buildItems(messages);
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      itemCount: items.length,
      itemBuilder: (context, i) => items[items.length - 1 - i],
    );
  }

  List<Widget> _buildItems(List<ChatMessage> messages) {
    final items = <Widget>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      final next = i < messages.length - 1 ? messages[i + 1] : null;
      final newDay = prev == null || !_sameDay(prev.createdAt, m.createdAt);
      if (newDay) items.add(_DateChip(label: _dayLabel(m.createdAt)));
      final firstOfRun = newDay || prev.senderId != m.senderId;
      final lastOfRun =
          next == null ||
          next.senderId != m.senderId ||
          !_sameDay(next.createdAt, m.createdAt);
      items.add(
        SentMessageEntrance(
          key: ValueKey('sent-message-entrance-${m.id}'),
          animate: m.id == _animatingSentMessageId,
          onCompleted: () => _finishSentMessageEntrance(m.id),
          child: _buildBubbleRow(
            m,
            firstOfRun: firstOfRun,
            lastOfRun: lastOfRun,
          ),
        ),
      );
    }
    return items;
  }

  Widget _buildBubbleRow(
    ChatMessage m, {
    required bool firstOfRun,
    required bool lastOfRun,
  }) {
    final mine = chatStore.isMessageOwner(m, _myId);
    final (senderName, senderIsAdmin) = _senderInfo(m.senderId);
    final club = _club;
    final isMultiParticipant = _isClub || _isGroup;
    final showHeader = isMultiParticipant && !mine;
    final showAvatar = isMultiParticipant;
    final VoidCallback? openSenderProfile =
        !mine && !senderIsAdmin && _userForId(m.senderId) != null
        ? () => _openUserProfileById(m.senderId)
        : null;
    final senderAvatar = Container(
      key: _isGroup ? ValueKey('group-message-avatar-${m.id}') : null,
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.glassEdge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 7,
            spreadRadius: -2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: senderIsAdmin && club != null
          ? ClubAvatar(
              clubId: club.id,
              clubName: club.name,
              color: _colorForClub(club.id),
              imageUrl: club.logoUrl,
              size: 28,
              fontSize: 11,
              shape: 'circle',
            )
          : UserAvatar(
              userId: m.senderId,
              name: senderName,
              size: 28,
              fontSize: 11,
            ),
    );

    final hasText = m.content.trim().isNotEmpty;
    final photoPath = m.kind == ChatMessageKind.photo ? m.attachmentPath : null;
    final filePath = m.kind == ChatMessageKind.file ? m.attachmentPath : null;
    final hasMedia = photoPath != null || filePath != null;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.76,
      ),
      padding: hasMedia
          ? const EdgeInsets.all(5)
          : const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: mine
            ? null
            : AppColors.card.withValues(
                alpha: themeService.isDark ? 0.96 : 0.98,
              ),
        gradient: mine
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryRed, AppColors.darkRed],
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(mine ? 20 : 6),
          bottomRight: Radius.circular(mine ? 6 : 20),
        ),
        border: mine ? null : Border.all(color: AppColors.glassEdge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: mine ? 0.14 : 0.08),
            blurRadius: 10,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: m.kind == ChatMessageKind.postShare && m.sharedPostId != null
          ? SharedPostMessageCard(
              postId: m.sharedPostId!,
              onDarkBackground: mine,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photoPath != null) _photoAttachment(photoPath),
                if (filePath != null) _fileAttachment(m, mine: mine),
                if (hasText)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      hasMedia ? 8 : 0,
                      hasMedia ? 7 : 0,
                      hasMedia ? 8 : 0,
                      hasMedia ? 3 : 0,
                    ),
                    child: Text(
                      m.content,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        letterSpacing: -0.1,
                        color: mine ? Colors.white : AppColors.text,
                      ),
                    ),
                  ),
              ],
            ),
    );

    return Padding(
      padding: EdgeInsets.only(top: firstOfRun ? 8 : 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (showAvatar && !mine)
            Padding(
              // Keep the sender identity beside every incoming message.
              padding: const EdgeInsets.only(right: 8, bottom: 15),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: openSenderProfile,
                child: senderAvatar,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: GestureDetector(
                            key: ValueKey('chat-sender-profile-name-${m.id}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: openSenderProfile,
                            child: Text(
                              senderName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                // Each speaker keeps a stable accent so a busy
                                // group stays readable at a glance.
                                color: senderIsAdmin
                                    ? AppColors.primaryRed
                                    : _accentForUser(m.senderId),
                              ),
                            ),
                          ),
                        ),
                        if (senderIsAdmin) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lightRed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              S.adminLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                GestureDetector(
                  key: ValueKey('chat-message-${m.id}'),
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => _openReactionPicker(m),
                  child: bubble,
                ),
                if (m.reactions.isNotEmpty) _reactionChips(m, alignEnd: mine),
                // Every outgoing DM carries a delivery receipt. Incoming and
                // group messages keep the compact timestamp-only treatment.
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timeLabel(m.createdAt),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      if (mine && _isDirect) ...[
                        const SizedBox(width: 5),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _MessageTicks(
                            key: ValueKey(
                              'message-status-${m.id}-${m.status.name}',
                            ),
                            seen: m.status == MessageDeliveryStatus.seen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showAvatar && mine)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 15),
              child: lastOfRun
                  ? senderAvatar
                  : const SizedBox(width: 32, height: 32),
            ),
        ],
      ),
    );
  }

  // ── Bubble parts ────────────────────────────────────────────────────────────

  static const List<Color> _senderAccents = [
    Color(0xFF00838F),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF2E7D32),
    Color(0xFFC62828),
  ];

  Color _accentForUser(String userId) {
    if (userId.isEmpty) return AppColors.secondaryText;
    return _senderAccents[userId.hashCode.abs() % _senderAccents.length];
  }

  /// Tapping a chip toggles your own reaction; long-pressing the bubble opens
  /// the picker.
  Widget _reactionChips(ChatMessage m, {required bool alignEnd}) {
    final entries = m.reactions.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Transform.translate(
      offset: const Offset(0, -6),
      child: Wrap(
        spacing: 5,
        alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
        children: [
          for (final entry in entries)
            GestureDetector(
              key: ValueKey('chat-reaction-${m.id}-${entry.key}'),
              onTap: () => chatStore.toggleReaction(
                messageId: m.id,
                userId: _myId,
                emoji: entry.key,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.value.contains(_myId)
                      ? AppColors.lightRed
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: entry.value.contains(_myId)
                        ? AppColors.primaryRed
                        : AppColors.glassEdge,
                  ),
                ),
                child: Text(
                  entry.value.length > 1
                      ? '${entry.key} ${entry.value.length}'
                      : entry.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoAttachment(String path) {
    final isRemote = path.startsWith('http://') || path.startsWith('https://');
    final file = isRemote ? null : File(path);
    final exists = isRemote || file!.existsSync();
    final imageProvider = isRemote
        ? NetworkImage(path) as ImageProvider
        : FileImage(file!);
    return GestureDetector(
      key: ValueKey('chat-photo-$path'),
      onTap: exists
          ? () => showDialog<void>(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.92),
              builder: (dialogContext) => GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Center(
                    child: Image(image: imageProvider, fit: BoxFit.contain),
                  ),
                ),
              ),
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 200,
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.glassEdge),
            borderRadius: BorderRadius.circular(15),
          ),
          child: exists
              ? Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _missingPhotoPlaceholder(),
                )
              : Container(
                  height: 140,
                  alignment: Alignment.center,
                  color: AppColors.surfaceAlt,
                  child: Icon(
                    Icons.image_outlined,
                    size: 26,
                    color: AppColors.secondaryText,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _missingPhotoPlaceholder() => Container(
    height: 140,
    alignment: Alignment.center,
    color: AppColors.surfaceAlt,
    child: Icon(Icons.image_outlined, size: 26, color: AppColors.secondaryText),
  );

  Widget _fileAttachment(ChatMessage m, {required bool mine}) {
    final name = m.attachmentName ?? S.attachFile;
    final size = _formatFileSize(m.attachmentSize);
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.fromLTRB(9, 8, 12, 8),
      decoration: BoxDecoration(
        color: mine
            ? Colors.white.withValues(alpha: 0.16)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: mine
              ? Colors.white.withValues(alpha: 0.22)
              : AppColors.glassEdge,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: mine
                  ? Colors.white.withValues(alpha: 0.18)
                  : AppColors.lightRed,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 17,
              color: mine ? Colors.white : AppColors.primaryRed,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: mine ? Colors.white : AppColors.text,
                  ),
                ),
                if (size.isNotEmpty)
                  Text(
                    size,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: mine
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Input bar ───────────────────────────────────────────────────────────────

  Widget _buildInputBar({required bool enabled}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card.withValues(
          alpha: themeService.isDark ? 0.96 : 0.98,
        ),
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // "+" — photo or camera.
            _composerCircleButton(
              key: const ValueKey('chat-attach-button'),
              size: 40,
              icon: Icons.add_rounded,
              iconSize: 21,
              iconColor: AppColors.primaryRed,
              onTap: enabled ? _openAttachSheet : null,
              semanticLabel: S.attachToMessage,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: const BorderRadius.all(Radius.circular(22)),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: enabled,
                        minLines: 1,
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        textAlignVertical: TextAlignVertical.center,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: enabled ? (_) => _send() : null,
                        style: TextStyle(fontSize: 14.5, color: AppColors.text),
                        decoration: InputDecoration(
                          hintText: S.typeMessage,
                          hintStyle: TextStyle(
                            fontSize: 14.5,
                            color: AppColors.secondaryText,
                          ),
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            4,
                            0,
                          ),
                        ),
                      ),
                    ),
                    // Quick camera capture, docked inside the pill.
                    _composerCircleButton(
                      key: const ValueKey('chat-camera-button'),
                      size: 34,
                      icon: Icons.photo_camera_outlined,
                      iconSize: 19,
                      iconColor: AppColors.secondaryText,
                      filled: false,
                      onTap: enabled
                          ? () => _pickAttachment(_ChatAttachment.camera)
                          : null,
                      semanticLabel: S.takePhoto,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            // Send once there is a draft. The disabled send affordance keeps
            // the composer layout stable without offering voice notes.
            ListenableBuilder(
              listenable: _inputController,
              builder: (context, _) {
                final hasDraft =
                    enabled && _inputController.text.trim().isNotEmpty;
                return GestureDetector(
                  key: const ValueKey('chat-send-button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled && hasDraft ? _send : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: hasDraft ? null : AppColors.surfaceAlt,
                      gradient: hasDraft
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.primaryRed, AppColors.darkRed],
                            )
                          : null,
                      shape: BoxShape.circle,
                      border: hasDraft
                          ? null
                          : Border.all(color: AppColors.divider),
                      boxShadow: hasDraft
                          ? [
                              BoxShadow(
                                color: AppColors.primaryRed.withValues(
                                  alpha: 0.33,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      size: 21,
                      color: hasDraft ? Colors.white : AppColors.secondaryText,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _composerCircleButton({
    required Key key,
    required double size,
    required IconData icon,
    required double iconSize,
    required Color iconColor,
    required VoidCallback? onTap,
    required String semanticLabel,
    bool filled = true,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: filled
              ? BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider),
                )
              : null,
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }

  // ── Time helpers ────────────────────────────────────────────────────────────

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    if (_sameDay(dt, now)) return S.today;
    if (_sameDay(dt, now.subtract(const Duration(days: 1)))) {
      return S.yesterday;
    }
    return '${_months[dt.month - 1]} ${dt.day}';
  }

  String _timeLabel(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// The design's day marker: a hairline rule on each side of a small caps label.
class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: AppColors.divider)),
        ],
      ),
    );
  }
}

/// Double check-mark receipt: muted once delivered, red once seen.
class _MessageTicks extends StatelessWidget {
  final bool seen;

  const _MessageTicks({super.key, required this.seen});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: seen ? S.seen : S.delivered,
      child: CustomPaint(
        size: const Size(17, 11),
        painter: _TicksPainter(
          color: seen ? AppColors.primaryRed : AppColors.secondaryText,
        ),
      ),
    );
  }
}

class _TicksPainter extends CustomPainter {
  final Color color;

  const _TicksPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 19;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path tick(double dx) => Path()
      ..moveTo((1 + dx) * scale, 6 * scale)
      ..lineTo((4 + dx) * scale, 9 * scale)
      ..lineTo((10 + dx) * scale, 2 * scale);
    canvas.drawPath(tick(0), paint);
    canvas.drawPath(tick(6.5), paint);
  }

  @override
  bool shouldRepaint(covariant _TicksPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// The student thread canvas: a flat body under the design's campus wallpaper
/// and corner bloom.
class _ConversationBackdrop extends StatelessWidget {
  final bool isDark;
  final Color accent;

  const _ConversationBackdrop({required this.isDark, required this.accent});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        key: const ValueKey('chat-conversation-backdrop'),
        color: AppColors.background,
        child: ChatCampusBackdrop(isDark: isDark, accent: accent),
      ),
    );
  }
}
