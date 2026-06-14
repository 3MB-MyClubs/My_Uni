import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/news_post.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/mock_data.dart';
import '../services/presence_service.dart';

import '../widgets/chat_widgets.dart';
import '../widgets/club_avatar.dart';
import '../widgets/user_avatar.dart';
import 'create_post_screen.dart' show buildPostBanner;
import 'post_detail_screen.dart';

// Club color palette — same as feed_screen / notifications_screen
const List<Color> _chatClubColors = [
  Color(0xFFB41C18), Color(0xFF1565C0), Color(0xFF2E7D32),
  Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
];

Color _colorForClubId(String clubId) {
  final idx = clubs.indexWhere((c) => c.id == clubId);
  return _chatClubColors[(idx < 0 ? 0 : idx) % _chatClubColors.length];
}

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Message> _conversation = [];
  bool _loading = true;

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  bool get _isClub => clubs.any((c) => c.id == widget.otherUserId);

  @override
  void initState() {
    super.initState();
    messageService.setCurrentUserId(_myId);
    _loadConversation();
  }

  Future<void> _loadConversation() async {
    setState(() => _loading = true);
    // Merge persisted (Hive) messages with the mock seed conversation so the
    // open thread matches the previews shown in the inbox.
    final hive = messageService.getConversation(_myId, widget.otherUserId);
    final hiveIds = hive.map((m) => m.id).toSet();
    final seed = messages.where((m) =>
        ((m.senderId == _myId && m.receiverId == widget.otherUserId) ||
            (m.senderId == widget.otherUserId && m.receiverId == _myId)) &&
        !hiveIds.contains(m.id));
    _conversation = [...hive, ...seed]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    await messageService.markAsRead(_myId, widget.otherUserId);
    setState(() => _loading = false);
    _scrollToBottom(animate: false);
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(target,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _appendOwn(String content) {
    final msg = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myId,
      receiverId: widget.otherUserId,
      content: content,
      sentAt: DateTime.now(),
    );
    messageService.saveMessage(msg);
    messageService.markAsRead(_myId, widget.otherUserId);
    setState(() {
      _conversation.add(msg);
      _conversation.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    });
    _scrollToBottom();
    _simulateReply();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _appendOwn(text);
  }

  Future<void> _onAttach() async {
    final choice = await showAttachSheet(context);
    if (choice == 'photo') {
      _appendOwn('kuphoto:campus_photo.jpg');
    } else if (choice == 'voice') {
      _appendOwn('kuvoice:0:09');
    }
  }

  void _onCamera() => _appendOwn('kuphoto:camera_shot.jpg');
  void _onMic() => _appendOwn('kuvoice:0:07');

  static const _autoReplies = [
    'Got it! 👍',
    'Sounds good!',
    'Thanks for the message!',
    'Sure, let\'s do it! 🎉',
    'I\'ll get back to you shortly.',
    'That\'s great to hear!',
  ];

  Future<void> _simulateReply() async {
    // Show a live typing indicator (inbox + thread) before the reply lands.
    presenceService.startTyping(widget.otherUserId);
    await Future.delayed(const Duration(seconds: 3));
    presenceService.stopTyping(widget.otherUserId);
    if (!mounted) return;

    final reply = _autoReplies[
        DateTime.now().millisecondsSinceEpoch % _autoReplies.length];
    final msg = Message(
      id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
      senderId: widget.otherUserId,
      receiverId: _myId,
      content: reply,
      sentAt: DateTime.now(),
    );
    await messageService.saveMessage(msg);
    if (!mounted) return;
    setState(() {
      _conversation.add(msg);
      _conversation.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    presenceService.clearTypingQuietly(widget.otherUserId);
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
            _ChatHeader(
              otherUserId: widget.otherUserId,
              otherUserName: widget.otherUserName,
              isClub: _isClub,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessageList(),
            ),
            ChatComposer(
              controller: _controller,
              onSend: _sendMessage,
              onAttach: _onAttach,
              onCamera: _onCamera,
              onMic: _onMic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_conversation.isEmpty) {
      return Center(
        child: Text('No messages yet.\nSay hello!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText)),
      );
    }

    // Build a render list interleaving date dividers between day changes.
    final items = <_Row>[];
    DateTime? lastDay;
    for (var i = 0; i < _conversation.length; i++) {
      final m = _conversation[i];
      final day = DateTime(m.sentAt.year, m.sentAt.month, m.sentAt.day);
      if (lastDay == null || day != lastDay) {
        items.add(_Row.divider(chatDateLabel(m.sentAt)));
        lastDay = day;
      }
      items.add(_Row.message(m, i));
    }

    return ListenableBuilder(
      listenable: presenceService,
      builder: (context, _) {
        final typing = presenceService.isTyping(widget.otherUserId);
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          itemCount: items.length + (typing ? 1 : 0),
          itemBuilder: (context, idx) {
            if (typing && idx == items.length) {
              return const TypingBubble();
            }
            final row = items[idx];
            if (row.isDivider) return ChatDivider(label: row.label!);

            final m = row.message!;
            final isMe = m.senderId == _myId;

            if (m.content.startsWith('kupost:')) {
              return _SharedPostBubble(
                postId: m.content.substring('kupost:'.length),
                isMe: isMe,
                sentAt: m.sentAt,
              );
            }

            // status for my messages: last message overall = delivered,
            // otherwise read (a later reply implies it was seen).
            String? status;
            if (isMe) {
              status = (row.originalIndex == _conversation.length - 1)
                  ? 'delivered'
                  : 'read';
            }

            return ChatBubble(
              messageId: m.id,
              content: m.content,
              mine: isMe,
              time: chatClock(m.sentAt),
              status: status,
              isGroup: false,
            );
          },
        );
      },
    );
  }
}

// Render-row helper (divider or message).
class _Row {
  final bool isDivider;
  final String? label;
  final Message? message;
  final int originalIndex;
  _Row.divider(this.label)
      : isDivider = true,
        message = null,
        originalIndex = -1;
  _Row.message(this.message, this.originalIndex)
      : isDivider = false,
        label = null;
}

// ─── Conversation header (presence + call) ──────────────────────────────────
class _ChatHeader extends StatelessWidget {
  final String otherUserId;
  final String otherUserName;
  final bool isClub;
  final VoidCallback onBack;

  const _ChatHeader({
    required this.otherUserId,
    required this.otherUserName,
    required this.isClub,
    required this.onBack,
  });

  Widget _avatar() {
    if (isClub) {
      final idx = clubs.indexWhere((c) => c.id == otherUserId);
      final color = _chatClubColors[(idx < 0 ? 0 : idx) % _chatClubColors.length];
      return ClubAvatar(
        clubId: otherUserId,
        clubName: otherUserName,
        color: color,
        size: 40,
        fontSize: 16,
        borderRadius: 13,
      );
    }
    return UserAvatar(
        userId: otherUserId, name: otherUserName, size: 40, fontSize: 16);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: presenceService,
      builder: (context, _) {
        final online = !isClub && presenceService.isOnline(otherUserId);
        final typing = presenceService.isTyping(otherUserId);

        String presence;
        Color presenceColor;
        if (isClub) {
          presence = 'Club account';
          presenceColor = AppColors.secondaryText;
        } else if (typing) {
          presence = 'typing…';
          presenceColor = AppColors.primaryRed;
        } else if (online) {
          presence = 'Active now';
          presenceColor = kOnlineGreen;
        } else {
          presence = 'Last seen ${presenceService.lastSeenFor(otherUserId)}';
          presenceColor = AppColors.secondaryText;
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 14, 12),
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _avatar(),
                  if (online)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: kOnlineGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.background, width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(otherUserName,
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                            letterSpacing: -0.2),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        if (online && !typing) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: kOnlineGreen, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(presence,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: presenceColor,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text('Calling $otherUserName…'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ));
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceAlt,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Icon(Icons.call_outlined,
                      size: 18, color: AppColors.secondaryText),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Shared-post bubble (kept; restyled border to match) ────────────────────
class _SharedPostBubble extends StatelessWidget {
  final String postId;
  final bool isMe;
  final DateTime sentAt;

  const _SharedPostBubble({
    required this.postId,
    required this.isMe,
    required this.sentAt,
  });

  String _timeLabel(DateTime dt) {
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

    if (post == null) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text('Post no longer available',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
        ),
      );
    }

    String clubName = 'Unknown Club';
    try {
      clubName = clubs.firstWhere((c) => c.id == post!.clubId).name;
    } catch (_) {}

    final color = _colorForClubId(post.clubId);
    final caption = post.content.length > 90
        ? '${post.content.substring(0, 90)}…'
        : post.content;
    final hasImage = post.imagePath != null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(post: post!, clubColor: color),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            clubName.isNotEmpty
                                ? clubName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(clubName,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: color),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Icon(Icons.open_in_new_rounded,
                          size: 14, color: AppColors.secondaryText),
                    ],
                  ),
                ),
                if (hasImage)
                  buildPostBanner(
                    imagePath: post.imagePath,
                    fallbackColor: color,
                    fallbackLetter:
                        clubName.isNotEmpty ? clubName[0].toUpperCase() : '?',
                    height: 160,
                  )
                else
                  Container(
                    height: 70,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.55)]),
                    ),
                    child: Center(
                      child: Text(
                        clubName.isNotEmpty ? clubName[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text(caption,
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.text, height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_timeLabel(sentAt),
                          style: TextStyle(
                              fontSize: 10, color: AppColors.secondaryText)),
                      Row(
                        children: [
                          Text('View post',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 10, color: color),
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
}
