import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/news_post.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
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

  static const _clubColors = [
    Color(0xFF8C1D40), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  Widget _buildOtherAvatar() {
    final isClub = clubs.any((c) => c.id == widget.otherUserId);
    if (isClub) {
      final idx = clubs.indexWhere((c) => c.id == widget.otherUserId);
      final color = _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
      return ClubAvatar(
        clubId: widget.otherUserId,
        clubName: widget.otherUserName,
        color: color,
        size: 36,
        fontSize: 15,
        borderRadius: 10,
      );
    }
    final u = users.cast().firstWhere(
      (u) => u.id == widget.otherUserId,
      orElse: () => null,
    );
    if (u != null) {
      return UserAvatar(userId: u.id, name: u.name, size: 36, fontSize: 15);
    }
    return UserAvatar(
        userId: widget.otherUserId, name: widget.otherUserName, size: 36, fontSize: 15);
  }

  @override
  void initState() {
    super.initState();
    messageService.setCurrentUserId(_myId);
    _loadConversation();
  }

  Future<void> _loadConversation() async {
    setState(() => _loading = true);
    _conversation =
        messageService.getConversation(_myId, widget.otherUserId);
    await messageService.markAsRead(_myId, widget.otherUserId);
    setState(() => _loading = false);
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final msg = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myId,
      receiverId: widget.otherUserId,
      content: text,
      sentAt: DateTime.now(),
    );

    messageService.saveMessage(msg);
    messageService.markAsRead(_myId, widget.otherUserId);

    setState(() {
      _conversation.add(msg);
      _conversation.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      _controller.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    _simulateReply();
  }

  static const _autoReplies = [
    'Got it! 👍',
    'Sounds good!',
    'Thanks for the message!',
    'Sure, let\'s do it! 🎉',
    'I\'ll get back to you shortly.',
    'That\'s great to hear!',
  ];

  Future<void> _simulateReply() async {
    await Future.delayed(const Duration(seconds: 3));
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: [
            _buildOtherAvatar(),
            const SizedBox(width: 10),
            Text(
              widget.otherUserName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _conversation.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.\nSay hello!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _conversation.length,
                        itemBuilder: (context, i) {
                          final msg = _conversation[i];
                          final isMe = msg.senderId == _myId;
                          if (msg.content.startsWith('kupost:')) {
                            final postId =
                                msg.content.substring('kupost:'.length);
                            return _SharedPostBubble(
                              postId: postId,
                              isMe: isMe,
                              sentAt: msg.sentAt,
                            );
                          }
                          return _MessageBubble(message: msg, isMe: isMe);
                        },
                      ),
          ),
          _InputBar(controller: _controller, onSend: _sendMessage),
        ],
      ),
    );
  }
}

// ─── Shared-post bubble ───────────────────────────────────────────────────────

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
    // Look up post
    NewsPost? post;
    try {
      post = newsPosts.firstWhere((p) => p.id == postId);
    } catch (_) {}

    if (post == null) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
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
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1.2,
          ),
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
              builder: (_) =>
                  PostDetailScreen(post: post!, clubColor: color),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Club header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            clubName.isNotEmpty
                                ? clubName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          clubName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.open_in_new_rounded,
                          size: 14, color: AppColors.secondaryText),
                    ],
                  ),
                ),

                // ── Image or gradient banner ──
                if (hasImage)
                  buildPostBanner(
                    imagePath: post.imagePath,
                    fallbackColor: color,
                    fallbackLetter: clubName.isNotEmpty
                        ? clubName[0].toUpperCase()
                        : '?',
                    height: 160,
                  )
                else
                  Container(
                    height: 70,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color,
                          color.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        clubName.isNotEmpty ? clubName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // ── Caption ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text(
                    caption,
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.text, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // ── Footer: timestamp + "View post" ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _timeLabel(sentAt),
                        style: TextStyle(
                            fontSize: 10, color: AppColors.secondaryText),
                      ),
                      Row(
                        children: [
                          Text(
                            'View post',
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

// ─── Regular text bubble ──────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryRed : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.text,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _timeLabel(message.sentAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle:
                      TextStyle(color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.lightGray,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryRed,
                ),
                child: Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
