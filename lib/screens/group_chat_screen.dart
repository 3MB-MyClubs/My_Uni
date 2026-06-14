import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/news_post.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/group_chat_service.dart';
import '../services/mock_data.dart';
import '../services/presence_service.dart';
import '../services/user_state.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/user_avatar.dart';
import 'create_post_screen.dart' show buildPostBanner;
import 'event_detail_screen.dart';
import 'post_detail_screen.dart';

const List<Color> _groupColors = [
  Color(0xFFB41C18), Color(0xFF1565C0), Color(0xFF2E7D32),
  Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  Color(0xFF558B2F), Color(0xFF283593), Color(0xFF6D4C41),
];

Color _colorForUser(String userId) {
  final idx = users.indexWhere((u) => u.id == userId);
  return _groupColors[(idx < 0 ? 0 : idx) % _groupColors.length];
}

const String _kGroupCreatedSentinel = '👋 Group created';

class GroupChatScreen extends StatefulWidget {
  final GroupChat group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  bool get _isCreator => widget.group.creatorId == _myId;

  String _nameFor(String uid) {
    try {
      final u = users.firstWhere((u) => u.id == uid);
      return userState.displayNameFor(u.id, u.name).split(' ').first;
    } catch (_) {
      return 'User';
    }
  }

  String get _groupTitle {
    if (widget.group.name != null && widget.group.name!.isNotEmpty) {
      return widget.group.name!;
    }
    final others =
        widget.group.memberIds.where((id) => id != _myId).map(_nameFor).toList();
    if (others.isEmpty) return 'Just you';
    if (others.length <= 3) return others.join(', ');
    return '${others.take(2).join(', ')} +${others.length - 2}';
  }

  int get _activeCount =>
      widget.group.memberIds.where((id) => presenceService.isOnline(id)).length;

  void _appendOwn(String content) {
    final msg = GroupMessage(
      id: 'grpmsg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myId,
      content: content,
      sentAt: DateTime.now(),
    );
    groupChatService.addMessage(widget.group.id, msg);
    setState(() {});
    _scrollToBottom();
    _simulateReply();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _appendOwn(text);
  }

  Future<void> _onAttach() async {
    final choice = await showAttachSheet(context);
    if (choice == 'photo') {
      _appendOwn('kuphoto:group_photo.jpg');
    } else if (choice == 'voice') {
      _appendOwn('kuvoice:0:09');
    }
  }

  void _onCamera() => _appendOwn('kuphoto:camera_shot.jpg');
  void _onMic() => _appendOwn('kuvoice:0:07');

  static const _autoReplies = [
    'Got it! 👍', 'Sounds good!', 'Thanks!',
    'Sure, let\'s do it! 🎉', 'I\'ll check it out!', 'Great share!',
  ];

  Future<void> _simulateReply() async {
    final others = widget.group.memberIds.where((id) => id != _myId).toList();
    if (others.isEmpty) return;
    final responderId =
        others[DateTime.now().millisecondsSinceEpoch % others.length];
    presenceService.startTyping(widget.group.id);
    await Future.delayed(const Duration(seconds: 3));
    presenceService.stopTyping(widget.group.id);
    if (!mounted) return;
    final reply =
        _autoReplies[DateTime.now().millisecondsSinceEpoch % _autoReplies.length];
    final msg = GroupMessage(
      id: 'grpmsg_sim_${DateTime.now().millisecondsSinceEpoch}',
      senderId: responderId,
      content: reply,
      sentAt: DateTime.now(),
    );
    groupChatService.addMessage(widget.group.id, msg);
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _closeGroup() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Close Group', style: TextStyle(color: AppColors.text)),
        content: Text(
          'This will permanently delete the group and all messages for everyone.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              groupChatService.closeGroup(widget.group.id, _myId);
              Navigator.pop(context);
            },
            child: Text('Close Group',
                style: TextStyle(
                    color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    presenceService.clearTypingQuietly(widget.group.id);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _GroupHeader(
              title: _groupTitle,
              memberIds: widget.group.memberIds,
              activeCount: _activeCount,
              nameFor: _nameFor,
              isCreator: _isCreator,
              onBack: () => Navigator.pop(context),
              onClose: _closeGroup,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([groupChatService, presenceService]),
                builder: (context, _) => _buildMessageList(),
              ),
            ),
            ChatComposer(
              controller: _controller,
              onSend: _send,
              onAttach: _onAttach,
              onCamera: _onCamera,
              onMic: _onMic,
              hint: 'Message group…',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    final msgs = widget.group.messages;
    if (msgs.isEmpty) {
      return Center(
        child: Text('No messages yet',
            style: TextStyle(color: AppColors.secondaryText)),
      );
    }

    // Interleave date dividers; keep message indices for grouping.
    final items = <_GRow>[];
    DateTime? lastDay;
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final day = DateTime(m.sentAt.year, m.sentAt.month, m.sentAt.day);
      if (lastDay == null || day != lastDay) {
        items.add(_GRow.divider(chatDateLabel(m.sentAt)));
        lastDay = day;
      }
      items.add(_GRow.message(m, i));
    }

    final typing = presenceService.isTyping(widget.group.id);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      itemCount: items.length + (typing ? 1 : 0),
      itemBuilder: (ctx, idx) {
        if (typing && idx == items.length) {
          final others =
              widget.group.memberIds.where((id) => id != _myId).toList();
          final who = others.isNotEmpty ? others.first : '';
          return TypingBubble(
              isGroup: true, senderUserId: who, senderName: _nameFor(who));
        }

        final row = items[idx];
        if (row.isDivider) return ChatDivider(label: row.label!);

        final m = row.message!;
        final isMe = m.senderId == _myId;

        // Group-created / system line → info divider.
        if (m.content == _kGroupCreatedSentinel) {
          return const ChatDivider(label: 'Group created', info: true);
        }

        // Grouping: compare against neighbouring *message* rows.
        final prev = idx > 0 ? items[idx - 1] : null;
        final next = idx < items.length - 1 ? items[idx + 1] : null;
        final prevSame = prev != null &&
            !prev.isDivider &&
            prev.message!.senderId == m.senderId &&
            prev.message!.content != _kGroupCreatedSentinel;
        final nextSame = next != null &&
            !next.isDivider &&
            next.message!.senderId == m.senderId;

        if (m.content.startsWith('kupost:')) {
          return _GroupSharedPostBubble(
            postId: m.content.substring('kupost:'.length),
            isMe: isMe,
            senderName: isMe ? 'You' : _nameFor(m.senderId),
            sentAt: m.sentAt,
          );
        }
        if (m.content.startsWith('kuevent:')) {
          return _GroupSharedEventBubble(
            eventId: m.content.substring('kuevent:'.length),
            isMe: isMe,
            senderName: isMe ? 'You' : _nameFor(m.senderId),
            sentAt: m.sentAt,
          );
        }

        String? status;
        if (isMe) {
          status = (row.originalIndex == msgs.length - 1) ? 'delivered' : 'read';
        }

        return ChatBubble(
          messageId: m.id,
          content: m.content,
          mine: isMe,
          time: chatClock(m.sentAt),
          status: status,
          isGroup: true,
          showName: !prevSame,
          showAvatar: !nextSame,
          senderName: _nameFor(m.senderId),
          senderColor: _colorForUser(m.senderId),
          senderUserId: m.senderId,
        );
      },
    );
  }
}

class _GRow {
  final bool isDivider;
  final String? label;
  final GroupMessage? message;
  final int originalIndex;
  _GRow.divider(this.label)
      : isDivider = true,
        message = null,
        originalIndex = -1;
  _GRow.message(this.message, this.originalIndex)
      : isDivider = false,
        label = null;
}

// ─── Group header ───────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String title;
  final List<String> memberIds;
  final int activeCount;
  final String Function(String) nameFor;
  final bool isCreator;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const _GroupHeader({
    required this.title,
    required this.memberIds,
    required this.activeCount,
    required this.nameFor,
    required this.isCreator,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final shown = memberIds.take(3).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.primaryRed, size: 22),
          ),
          // Overlapping member avatars
          SizedBox(
            width: (shown.length.clamp(1, 3) * 18 + 22).toDouble(),
            height: 42,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * 18.0,
                    top: i * 3.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.background, width: 2),
                      ),
                      child: UserAvatar(
                        userId: shown[i],
                        name: nameFor(shown[i]),
                        size: 30,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.2),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(
                  '${memberIds.length} members'
                  '${activeCount > 0 ? ' · $activeCount active' : ''}',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: activeCount > 0
                          ? kOnlineGreen
                          : AppColors.secondaryText,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (isCreator)
            IconButton(
              icon: Icon(Icons.close_rounded, color: AppColors.primaryRed),
              tooltip: 'Close group',
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

// ─── Shared post bubble ───────────────────────────────────────────────────────
class _GroupSharedPostBubble extends StatelessWidget {
  final String postId;
  final bool isMe;
  final String senderName;
  final DateTime sentAt;

  const _GroupSharedPostBubble({
    required this.postId,
    required this.isMe,
    required this.senderName,
    required this.sentAt,
  });

  String _time(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    NewsPost? post;
    try {
      post = newsPosts.firstWhere((p) => p.id == postId);
    } catch (_) {}

    String clubName = '';
    const clubColors = [
      Color(0xFFB41C18), Color(0xFF1565C0), Color(0xFF2E7D32),
      Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
    ];
    Color color = clubColors[0];
    if (post != null) {
      try {
        clubName = clubs.firstWhere((c) => c.id == post!.clubId).name;
      } catch (_) {}
      final idx = clubs.indexWhere((c) => c.id == post!.clubId);
      color = clubColors[(idx < 0 ? 0 : idx) % clubColors.length];
    }

    final caption = post == null
        ? ''
        : (post.content.length > 90
            ? '${post.content.substring(0, 90)}…'
            : post.content);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                isMe ? 'You shared a post' : '$senderName shared a post',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600),
              ),
            ),
            GestureDetector(
              onTap: post == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              PostDetailScreen(post: post!, clubColor: color))),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        child: Row(children: [
                          Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                              child: Center(
                                  child: Text(
                                      clubName.isNotEmpty
                                          ? clubName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11)))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(clubName,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: color),
                                  overflow: TextOverflow.ellipsis)),
                          Icon(Icons.open_in_new_rounded,
                              size: 13, color: AppColors.secondaryText),
                        ]),
                      ),
                      if (post != null)
                        buildPostBanner(
                            imagePath: post.imagePath,
                            fallbackColor: color,
                            fallbackLetter: clubName.isNotEmpty
                                ? clubName[0].toUpperCase()
                                : '?',
                            height: 120),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(caption,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.text,
                                      height: 1.4),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(_time(sentAt),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.secondaryText)),
                            ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared event bubble ──────────────────────────────────────────────────────
class _GroupSharedEventBubble extends StatelessWidget {
  final String eventId;
  final bool isMe;
  final String senderName;
  final DateTime sentAt;

  const _GroupSharedEventBubble({
    required this.eventId,
    required this.isMe,
    required this.senderName,
    required this.sentAt,
  });

  String _time(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    Event? event;
    try {
      event = events.firstWhere((e) => e.id == eventId);
    } catch (_) {}

    const clubColors = [
      Color(0xFFB41C18), Color(0xFF1565C0), Color(0xFF2E7D32),
      Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
    ];
    String clubName = '';
    Color color = clubColors[0];
    if (event != null) {
      try {
        clubName = clubs.firstWhere((c) => c.id == event!.clubId).name;
      } catch (_) {}
      final idx = clubs.indexWhere((c) => c.id == event!.clubId);
      color = clubColors[(idx < 0 ? 0 : idx) % clubColors.length];
    }

    final dt = event?.dateTime;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = dt != null
        ? '${months[dt.month - 1]} ${dt.day} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                isMe ? 'You shared an event' : '$senderName shared an event',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600),
              ),
            ),
            GestureDetector(
              onTap: event == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              EventDetailScreen(event: event!, color: color))),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 6, color: color),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text('EVENT',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                        letterSpacing: 0.8)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(clubName,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.secondaryText),
                                      overflow: TextOverflow.ellipsis)),
                            ]),
                            const SizedBox(height: 6),
                            Text(event?.title ?? 'Event not found',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            if (dateStr.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 11, color: AppColors.secondaryText),
                                const SizedBox(width: 4),
                                Text(dateStr,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.secondaryText)),
                              ]),
                            ],
                            if (event?.location.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              Row(children: [
                                Icon(Icons.location_on_outlined,
                                    size: 11, color: AppColors.secondaryText),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(event!.location,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.secondaryText),
                                        overflow: TextOverflow.ellipsis)),
                              ]),
                            ],
                            const SizedBox(height: 6),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_time(sentAt),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.secondaryText)),
                                  Row(children: [
                                    Text('View event',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: color,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 3),
                                    Icon(Icons.arrow_forward_ios_rounded,
                                        size: 10, color: color),
                                  ]),
                                ]),
                          ]),
                    ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
