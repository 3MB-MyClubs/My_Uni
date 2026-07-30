import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/app_presence_service.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/club_community_info_controller.dart';
import '../services/locale_service.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/theme_service.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
import '../widgets/group_avatar_stack.dart';
import '../widgets/presence_avatar.dart';
import '../widgets/user_avatar.dart';
import 'club_community_screen.dart';
import 'club_profile_screen.dart';
import 'group_info_screen.dart';
import 'user_profile_screen.dart';

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

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  bool get _isClub => ChatStore.isClubThread(widget.threadId);
  bool get _isGroup => ChatStore.isGroupThread(widget.threadId);
  bool get _isDirect => ChatStore.isDirectThread(widget.threadId);

  Club? get _club {
    final clubId = ChatStore.clubIdOf(widget.threadId);
    return clubId == null ? null : clubForId(clubId);
  }

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
      if (_isDirect) {
        final peerId = ChatStore.dmPeerOf(widget.threadId, _myId);
        if (peerId != null) {
          chatStore.ensureDirectThread(_myId, peerId);
          unawaited(_hydratePeerProfile(peerId));
        }
      } else if (_isClub || _isGroup) {
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
    if ((!_isClub && !_isGroup) ||
        !chatStore.canAccessThread(widget.threadId, _myId)) {
      return;
    }
    final participantIds =
        <String>{
            if (_isGroup) ...chatStore.groupParticipants(widget.threadId),
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

  void _send() {
    final sent = chatStore.sendMessage(
      threadId: widget.threadId,
      senderId: _myId,
      content: _inputController.text,
    );
    if (sent == null) return;
    _inputController.clear();
    // reverse:true list — offset 0 is the newest message at the bottom.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Sender identity ─────────────────────────────────────────────────────────

  /// Display name + whether the sender is a club-admin account.
  (String, bool) _senderInfo(String senderId) {
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
    final club = _club;
    if (club != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ClubProfileScreen(club: club, color: _colorForClub(club.id)),
        ),
      ).then((_) => _markVisibleMessagesSeen());
      return;
    }
    if (_isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GroupInfoScreen(threadId: widget.threadId, myId: _myId),
        ),
      ).then((_) => _markVisibleMessagesSeen());
      return;
    }
    final peer = _peer;
    if (peer != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(user: peer)),
      ).then((_) => _markVisibleMessagesSeen());
    }
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
              accent: _club == null
                  ? AppColors.primaryRed
                  : _colorForClub(_club!.id),
              isCommunity: _isClub || _isGroup,
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
              return SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildMessageList()),
                    _buildInputBar(enabled: canAccess),
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
    final peer = _peer;
    final peerId = ChatStore.dmPeerOf(widget.threadId, _myId);
    final name = peer != null
        ? userState.displayNameFor(peer.id, peer.name)
        : '';
    final online = appPresenceService.onlineUserIds.contains(peerId ?? '');
    final academicSummary = userState.academicSummaryFor(peerId ?? '');
    final status = [
      academicSummary,
      if (online) S.onlineNow,
    ].where((value) => value.isNotEmpty).join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(
          alpha: themeService.isDark ? 0.94 : 0.97,
        ),
        border: Border(bottom: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!widget.embedded) ...[
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: InkWell(
              onTap: _openHeaderProfile,
              child: Row(
                children: [
                  PresenceAvatar(
                    userId: peer?.id ?? peerId ?? '',
                    name: peer?.name ?? '',
                    size: 38,
                    fontSize: 15,
                    online: online,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: online
                                ? const Color(0xFF2E7D32)
                                : AppColors.secondaryText,
                          ),
                        ),
                      ],
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

  Widget _buildGroupHeader() {
    final memberIds = chatStore.groupParticipants(widget.threadId);
    final visibleIds = memberIds.where((id) => id != _myId).toList();
    final title = chatStore.groupDisplayName(widget.threadId, _myId);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(
          alpha: themeService.isDark ? 0.94 : 0.97,
        ),
        border: Border(bottom: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!widget.embedded) ...[
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: InkWell(
              key: const ValueKey('group-chat-header'),
              onTap: _openHeaderProfile,
              child: Row(
                children: [
                  GroupAvatarStack(
                    memberIds: visibleIds,
                    nameForUser: (id) => _senderInfo(id).$1,
                    photoPath: chatStore
                        .groupForThread(widget.threadId)
                        ?.photoUrl,
                    size: 40,
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
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.secondaryText,
                  ),
                ],
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

  // ── Profile peek (DM only) ──────────────────────────────────────────────────

  // ── Message list ────────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    final messages = chatStore.messagesFor(widget.threadId, viewerId: _myId);
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Container(
            key: const ValueKey('chat-empty-conversation-card'),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(
                alpha: themeService.isDark ? 0.90 : 0.94,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.glassEdge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primaryRed,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  _isDirect ? S.startConversation : S.sayHello,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                if (_isDirect) ...[
                  const SizedBox(height: 7),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          S.privateConversationHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

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
        _buildBubbleRow(m, firstOfRun: firstOfRun, lastOfRun: lastOfRun),
      );
    }
    return items;
  }

  Widget _buildBubbleRow(
    ChatMessage m, {
    required bool firstOfRun,
    required bool lastOfRun,
  }) {
    final mine = m.senderId == _myId;
    final (senderName, senderIsAdmin) = _senderInfo(m.senderId);
    final club = _club;
    final isMultiParticipant = _isClub || _isGroup;
    final showHeader = isMultiParticipant && !mine;
    final showAvatar = isMultiParticipant;
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

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
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
                colors: [AppColors.darkRed, AppColors.primaryRed],
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
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
      child: Text(
        m.content,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.35,
          color: mine ? Colors.white : AppColors.text,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: firstOfRun ? 10 : 2),
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
              child: senderAvatar,
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
                          child: Text(
                            senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondaryText,
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
                bubble,
                // Every outgoing DM carries a delivery receipt. Incoming and
                // club messages keep the compact timestamp-only treatment.
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timeLabel(m.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      if (mine && _isDirect) ...[
                        const SizedBox(width: 4),
                        Text(
                          '·',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            m.status == MessageDeliveryStatus.seen
                                ? S.seen
                                : S.delivered,
                            key: ValueKey(
                              'message-status-${m.id}-${m.status.name}',
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: m.status == MessageDeliveryStatus.seen
                                  ? AppColors.primaryRed
                                  : AppColors.secondaryText,
                            ),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: const BorderRadius.all(Radius.circular(22)),
                  border: Border.all(color: AppColors.divider),
                ),
                child: TextField(
                  controller: _inputController,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 14, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: S.typeMessage,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Circular send button — fills red as soon as there is a draft.
            ListenableBuilder(
              listenable: _inputController,
              builder: (context, _) {
                final hasDraft =
                    enabled && _inputController.text.trim().isNotEmpty;
                return GestureDetector(
                  onTap: enabled ? _send : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: hasDraft
                          ? AppColors.primaryRed
                          : AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                      border: hasDraft
                          ? null
                          : Border.all(color: AppColors.divider),
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      size: 18,
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

class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(
            alpha: themeService.isDark ? 0.88 : 0.94,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.glassEdge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _ConversationBackdrop extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final bool isCommunity;

  const _ConversationBackdrop({
    required this.isDark,
    required this.accent,
    required this.isCommunity,
  });

  @override
  Widget build(BuildContext context) {
    final middle = Color.lerp(
      isDark ? const Color(0xFF180B10) : const Color(0xFFF7EFEC),
      accent,
      isDark ? 0.12 : 0.055,
    )!;
    return IgnorePointer(
      child: Container(
        key: const ValueKey('chat-conversation-backdrop'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF13090D), middle, const Color(0xFF10070A)]
                : [const Color(0xFFFBF7F5), middle, const Color(0xFFF8F1EE)],
            stops: const [0, 0.52, 1],
          ),
        ),
        child: CustomPaint(
          painter: _ConversationPatternPainter(
            accent: accent,
            isDark: isDark,
            isCommunity: isCommunity,
          ),
        ),
      ),
    );
  }
}

class _ConversationPatternPainter extends CustomPainter {
  final Color accent;
  final bool isDark;
  final bool isCommunity;

  const _ConversationPatternPainter({
    required this.accent,
    required this.isDark,
    required this.isCommunity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.14 : 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round;
    final softPaint = Paint()
      ..color = (isDark ? Colors.white : accent).withValues(
        alpha: isDark ? 0.045 : 0.035,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    const cellWidth = 112.0;
    const cellHeight = 98.0;
    for (var row = -1; row * cellHeight < size.height + cellHeight; row++) {
      final horizontalOffset = row.isEven ? -32.0 : 24.0;
      for (
        var column = -1;
        column * cellWidth < size.width + cellWidth;
        column++
      ) {
        final x = horizontalOffset + column * cellWidth;
        final y = row * cellHeight + (isCommunity ? 16 : 0);
        final alternate = (row + column).isEven;

        if (alternate) {
          final bubble = RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 18, y + 22, 34, 24),
            const Radius.circular(8),
          );
          canvas.drawRRect(bubble, linePaint);
          final tail = Path()
            ..moveTo(x + 26, y + 46)
            ..lineTo(x + 22, y + 52)
            ..lineTo(x + 34, y + 46);
          canvas.drawPath(tail, linePaint);
          canvas.drawCircle(Offset(x + 29, y + 34), 1.2, softPaint);
          canvas.drawCircle(Offset(x + 35, y + 34), 1.2, softPaint);
          canvas.drawCircle(Offset(x + 41, y + 34), 1.2, softPaint);
        } else {
          canvas.drawCircle(Offset(x + 36, y + 34), 15, softPaint);
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x + 36, y + 34), radius: 10),
            0.35,
            2.1,
            false,
            linePaint,
          );
          canvas.drawCircle(Offset(x + 58, y + 57), 2.2, linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConversationPatternPainter oldDelegate) {
    return accent != oldDelegate.accent ||
        isDark != oldDelegate.isDark ||
        isCommunity != oldDelegate.isCommunity;
  }
}
