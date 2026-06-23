import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/group_chat_service.dart';
import '../services/message_service.dart';
import '../services/mock_data.dart';
import '../services/presence_service.dart';
import '../services/user_state.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  bool _isStudentUserId(String id) => users.any((u) => u.id == id);
  bool get _canUseMessages =>
      authService.isStudentSession && _isStudentUserId(_myId);

  // All contacts: every student user except self.
  List<_Contact> get _allContacts {
    final myId = _myId;
    return [
      ...users
          .where((u) => u.id != myId)
          .map(
            (u) => _Contact(
              id: u.id,
              name: userState.displayNameFor(u.id, u.name),
              isAdmin: u.role == 'admin',
            ),
          ),
    ];
  }

  // All student-to-student messages from both mock seed data and Hive.
  List<Message> get _allMessages {
    final hiveMessages = messageService.getAllMessages();
    final hiveIds = hiveMessages.map((m) => m.id).toSet();
    final merged = [...hiveMessages];
    for (final m in messages) {
      if (!hiveIds.contains(m.id)) merged.add(m);
    }
    return merged
        .where(
          (m) => _isStudentUserId(m.senderId) && _isStudentUserId(m.receiverId),
        )
        .toList();
  }

  // Existing conversation partner IDs, sorted by last message time
  List<String> get _conversationPartnerIds {
    if (!_isStudentUserId(_myId)) return [];
    final all = _allMessages;
    final ids = <String>{};
    for (final m in all) {
      if (m.senderId == _myId) ids.add(m.receiverId);
      if (m.receiverId == _myId) ids.add(m.senderId);
    }
    final sorted = ids.toList();
    sorted.sort((a, b) {
      final lastA = _lastMessage(a)?.sentAt ?? DateTime(2000);
      final lastB = _lastMessage(b)?.sentAt ?? DateTime(2000);
      return lastB.compareTo(lastA);
    });
    return sorted;
  }

  Message? _lastMessage(String otherId) {
    final convo =
        _allMessages
            .where(
              (m) =>
                  (m.senderId == _myId && m.receiverId == otherId) ||
                  (m.senderId == otherId && m.receiverId == _myId),
            )
            .toList()
          ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return convo.isEmpty ? null : convo.first;
  }

  String _nameFor(String otherId) {
    try {
      final u = users.firstWhere((u) => u.id == otherId);
      return userState.displayNameFor(u.id, u.name);
    } catch (_) {}
    return 'Unknown';
  }

  void _openChat(String otherId, String otherName) {
    if (!_isStudentUserId(_myId) || !_isStudentUserId(otherId)) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(otherUserId: otherId, otherUserName: otherName),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _groupTitle(GroupChat g) {
    if (g.name != null && g.name!.isNotEmpty) return g.name!;
    final others = g.memberIds.where((id) => id != _myId).toList();
    final names = others.map((id) {
      try {
        final u = users.firstWhere((u) => u.id == id);
        return userState.displayNameFor(u.id, u.name).split(' ').first;
      } catch (_) {
        return 'User';
      }
    }).toList();
    if (names.isEmpty) return 'Just you';
    if (names.length <= 3) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  String _lastGroupPreview(GroupChat g) {
    final msg = g.lastMessage;
    if (msg == null) return '';
    final body = _previewBody(msg.content);
    final name = msg.senderId == _myId
        ? 'You'
        : (() {
            try {
              return users
                  .firstWhere((u) => u.id == msg.senderId)
                  .name
                  .split(' ')
                  .first;
            } catch (_) {
              return 'Someone';
            }
          })();
    return '$name: $body';
  }

  // Collapses special content payloads into a short preview label.
  String _previewBody(String content) {
    if (content.startsWith('kupost:')) return '📄 Shared a post';
    if (content.startsWith('kuevent:')) return '📅 Shared an event';
    if (isPhotoContent(content)) return '📷 Photo';
    if (isVoiceContent(content)) return '🎤 Voice note';
    return content;
  }

  // ── Compose / new conversation ────────────────────────────────────────────
  void _openComposeSheet() async {
    if (!_canUseMessages) return;
    final myId = _myId;
    final contacts = _allContacts;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewConversationSheet(
        myId: myId,
        contacts: contacts,
        onStartDm: (otherId, otherName) {
          Navigator.pop(context);
          _openChat(otherId, otherName);
        },
        onCreateGroup: (memberIds, groupName) {
          Navigator.pop(context);
          final group = groupChatService.createGroup(
            creatorId: myId,
            memberIds: memberIds,
            initialContent: '👋 Group created',
            groupName: groupName,
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
          ).then((_) => setState(() {}));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_canUseMessages) _buildSearch(),
            Expanded(
              child: _canUseMessages
                  ? ListenableBuilder(
                      listenable: Listenable.merge([
                        groupChatService,
                        presenceService,
                        userState,
                      ]),
                      builder: (context, _) => _buildBody(),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Messaging is only available between students.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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

  // ── Header: title · compose ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: 'Back',
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.text,
              ),
            ),
          ),
          Text(
            'Messages',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.3,
            ),
          ),
          if (_canUseMessages)
            GestureDetector(
              onTap: _openComposeSheet,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryRed.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(
                  Icons.edit_outlined,
                  size: 19,
                  color: AppColors.primaryRed,
                ),
              ),
            )
          else
            const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.secondaryText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search students…',
                  hintStyle: TextStyle(color: AppColors.secondaryText),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.secondaryText,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final q = _query.trim().toLowerCase();
    final searching = q.isNotEmpty;
    final partnerIds = _conversationPartnerIds;
    final groups = groupChatService.groupsForUser(_myId);

    bool matchId(String id) => _nameFor(id).toLowerCase().contains(q);

    final dmPeople = searching
        ? partnerIds.where(matchId).toList()
        : partnerIds;
    final dmGroups = searching
        ? groups.where((g) => _groupTitle(g).toLowerCase().contains(q)).toList()
        : groups;

    // Students you could start a NEW chat with.
    final existing = {...partnerIds};
    final newContacts = searching
        ? _allContacts
              .where(
                (c) =>
                    !existing.contains(c.id) &&
                    c.name.toLowerCase().contains(q),
              )
              .toList()
        : <_Contact>[];

    final nothing =
        searching &&
        dmPeople.isEmpty &&
        dmGroups.isEmpty &&
        newContacts.isEmpty;

    if (nothing) return _EmptyState(query: _query);

    final onlinePeople = users
        .where((u) => u.id != _myId && presenceService.isOnline(u.id))
        .toList();

    final hasVisibleConversations = partnerIds.isNotEmpty || groups.isNotEmpty;
    if (!searching && !hasVisibleConversations) {
      return _ColdStart(onCompose: _openComposeSheet);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (!searching && onlinePeople.isNotEmpty) _activeRail(onlinePeople),
        if (dmPeople.isNotEmpty) ...[
          const _SectionLabel('Direct messages'),
          ...dmPeople.map(_personRow),
        ],
        if (dmGroups.isNotEmpty) ...[
          const _SectionLabel('Group chats'),
          ...dmGroups.map(_groupRow),
        ],
        if (newContacts.isNotEmpty) ...[
          const _SectionLabel('Start a new chat'),
          ...newContacts.map(
            (c) => _ContactResultTile(
              contact: c,
              onTap: () => _openChat(c.id, c.name),
            ),
          ),
        ],
      ],
    );
  }

  // ── Active-now rail ─────────────────────────────────────────────────────────
  Widget _activeRail(List<dynamic> onlinePeople) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Active now'),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
            itemCount: onlinePeople.length,
            separatorBuilder: (_, i) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final u = onlinePeople[i];
              final name = userState.displayNameFor(u.id, u.name);
              return GestureDetector(
                onTap: () => _openChat(u.id, name),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        UserAvatar(
                          userId: u.id,
                          name: name,
                          size: 54,
                          fontSize: 21,
                        ),
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: kOnlineGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.background,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 58,
                      child: Text(
                        name.split(' ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText,
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
    );
  }

  // ── Conversation rows ───────────────────────────────────────────────────────
  Widget _personRow(String id) {
    final name = _nameFor(id);
    final last = _lastMessage(id);
    final fromMe = last != null && last.senderId == _myId;
    final all = _allMessages;
    final unread =
        !fromMe && last != null && messageService.hasUnread(_myId, id, all);
    final unreadCount = unread ? messageService.unreadCount(_myId, id, all) : 0;
    final online = presenceService.isOnline(id);
    final typing = presenceService.isTyping(id);

    return _ConvoRow(
      leading: _dottedAvatar(
        UserAvatar(userId: id, name: name, size: 52, fontSize: 20),
        online: online,
      ),
      name: name,
      nameUserId: id,
      preview: last == null
          ? 'Tap to start chatting'
          : _previewBody(last.content),
      time: last == null ? '' : _timeLabel(last.sentAt),
      fromMe: fromMe,
      typing: typing,
      unread: unreadCount,
      onTap: () => _openChat(id, name),
    );
  }

  Widget _groupRow(GroupChat g) {
    final title = _groupTitle(g);
    final preview = _lastGroupPreview(g);
    final ts = g.lastMessage?.sentAt ?? g.createdAt;
    final activeCount = g.memberIds
        .where((m) => presenceService.isOnline(m))
        .length;
    final fromMe = g.lastMessage?.senderId == _myId;

    return _ConvoRow(
      leading: _groupLeading(g, activeCount),
      name: title,
      memberCount: g.memberIds.length,
      preview: preview.isEmpty ? '${g.memberIds.length} members' : preview,
      time: _timeLabel(ts),
      fromMe: fromMe,
      typing: presenceService.isTyping(g.id),
      unread: 0,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(group: g)),
      ).then((_) => setState(() {})),
    );
  }

  // Avatar + online presence dot.
  Widget _dottedAvatar(Widget avatar, {required bool online}) {
    if (!online) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: kOnlineGreen,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }

  // Overlapping member avatars + green "active members" count badge.
  Widget _groupLeading(GroupChat g, int activeCount) {
    final shown = g.memberIds.take(3).toList();
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 13.0,
              top: i * 7.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: UserAvatar(
                  userId: shown[i],
                  name: _nameFor(shown[i]),
                  size: 30,
                  fontSize: 12,
                ),
              ),
            ),
          if (activeCount > 0)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: kOnlineGreen,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final daysDiff = today.difference(msgDay).inDays;
    if (daysDiff == 1) return 'Yesterday';
    if (daysDiff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    }
    const months = [
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
    if (dt.year == now.year) return '${months[dt.month - 1]} ${dt.day}';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}

// ─── Conversation row ─────────────────────────────────────────────────────────
class _ConvoRow extends StatefulWidget {
  final Widget leading;
  final String name;

  /// When set, [name] is resolved through the user's current display name so a
  /// renamed person shows their new name here. Null for group chats.
  final String? nameUserId;
  final int? memberCount; // groups
  final String preview;
  final String time;
  final bool fromMe;
  final bool typing;
  final int unread;
  final VoidCallback onTap;

  const _ConvoRow({
    required this.leading,
    required this.name,
    this.nameUserId,
    this.memberCount,
    required this.preview,
    required this.time,
    required this.fromMe,
    required this.typing,
    required this.unread,
    required this.onTap,
  });

  @override
  State<_ConvoRow> createState() => _ConvoRowState();
}

class _ConvoRowState extends State<_ConvoRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final unread = widget.unread > 0;
    return InkWell(
      onTap: widget.onTap,
      onHighlightChanged: (v) => setState(() => _hover = v),
      child: Container(
        color: _hover ? AppColors.surfaceAlt : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            widget.leading,
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.nameUserId == null
                              ? widget.name
                              : userState.displayNameFor(
                                  widget.nameUserId!,
                                  widget.name,
                                ),
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: AppColors.text,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.memberCount != null) ...[
                        const SizedBox(width: 7),
                        Text(
                          '· ${widget.memberCount}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (widget.fromMe && !widget.typing) ...[
                        const ReadTicks(status: 'read', size: 14),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          widget.typing ? 'typing…' : widget.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontStyle: widget.typing
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontWeight: (unread || widget.typing)
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: widget.typing
                                ? AppColors.primaryRed
                                : (unread
                                      ? AppColors.text
                                      : AppColors.secondaryText),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.time,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    color: unread
                        ? AppColors.primaryRed
                        : AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                if (unread)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        widget.unread > 99 ? '99+' : '${widget.unread}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 20, height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Warm empty state (search) ──────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 44,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'No matches for “$query”',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try a friend's name or a club. Start a new chat to connect with people across campus.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cold start (no conversations yet) ──────────────────────────────────────
class _ColdStart extends StatelessWidget {
  final VoidCallback onCompose;
  const _ColdStart({required this.onCompose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 72,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new chat to connect with people across campus.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onCompose,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_square, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'New conversation',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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
  }
}

// ─── Contact data class ────────────────────────────────────────────────────────
class _Contact {
  final String id;
  final String name;
  final bool isAdmin;

  const _Contact({required this.id, required this.name, this.isAdmin = false});
}

// ─── Contact result tile (search → start new chat) ──────────────────────────
class _ContactResultTile extends StatelessWidget {
  final _Contact contact;
  final VoidCallback onTap;

  const _ContactResultTile({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatar = UserAvatar(
      userId: contact.id,
      name: contact.name,
      size: 48,
      fontSize: 18,
    );
    final badge = contact.isAdmin ? 'Admin' : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: avatar,
      title: Row(
        children: [
          Flexible(
            child: Text(
              userState.displayNameFor(contact.id, contact.name),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primaryRed,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Message',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

// ─── New Conversation Sheet ───────────────────────────────────────────────────
class _NewConversationSheet extends StatefulWidget {
  final String myId;
  final List<_Contact> contacts;
  final void Function(String otherId, String otherName) onStartDm;
  final void Function(List<String> memberIds, String groupName) onCreateGroup;

  const _NewConversationSheet({
    required this.myId,
    required this.contacts,
    required this.onStartDm,
    required this.onCreateGroup,
  });

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  final _searchCtrl = TextEditingController();
  final _groupNameCtrl = TextEditingController();
  String _query = '';
  final List<_Contact> _selected = [];
  bool _showGroupName = false;

  List<_Contact> get _results {
    if (_query.isEmpty) return widget.contacts;
    final q = _query.toLowerCase();
    return widget.contacts
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  bool _isSelected(_Contact c) => _selected.any((s) => s.id == c.id);

  void _toggle(_Contact c) {
    setState(() {
      if (_isSelected(c)) {
        _selected.removeWhere((s) => s.id == c.id);
      } else {
        _selected.add(c);
      }
      _showGroupName = _selected.length >= 2;
    });
  }

  void _onStart() {
    if (_selected.isEmpty) return;
    if (_selected.length == 1) {
      widget.onStartDm(_selected.first.id, _selected.first.name);
    } else {
      final groupName = _groupNameCtrl.text.trim();
      if (groupName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a group name')),
        );
        return;
      }
      widget.onCreateGroup(_selected.map((c) => c.id).toList(), groupName);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = _selected.length >= 2;
    final canStart =
        _selected.isNotEmpty &&
        (!isGroup || _groupNameCtrl.text.trim().isNotEmpty);
    final height = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'New Conversation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              ],
            ),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _selected
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppColors.primaryRed.withValues(
                            alpha: 0.12,
                          ),
                          label: Text(
                            c.name.split(' ').first,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          deleteIconColor: AppColors.primaryRed,
                          onDeleted: () => _toggle(c),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (_showGroupName) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _groupNameCtrl,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Group name',
                  hintStyle: TextStyle(color: AppColors.secondaryText),
                  prefixIcon: Icon(
                    Icons.group_rounded,
                    color: AppColors.secondaryText,
                  ),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Search by name...',
                hintStyle: TextStyle(color: AppColors.secondaryText),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.secondaryText,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      'No results',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (ctx, i) => Divider(
                      height: 1,
                      indent: 64,
                      color: AppColors.divider,
                    ),
                    itemBuilder: (ctx, i) {
                      final c = _results[i];
                      final selected = _isSelected(c);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: UserAvatar(
                          userId: c.id,
                          name: c.name,
                          size: 44,
                          fontSize: 16,
                        ),
                        title: Text(
                          userState.displayNameFor(c.id, c.name),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        trailing: selected
                            ? Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              )
                            : Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.divider,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                        onTap: () => _toggle(c),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: canStart ? _onStart : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.divider,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? 'Select someone'
                        : isGroup
                        ? 'Create Group'
                        : 'Start Chat with ${_selected.first.name.split(' ').first}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
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
