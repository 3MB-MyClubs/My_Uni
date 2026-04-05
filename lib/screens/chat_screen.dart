import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';

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
    // Mark messages from the other user as read
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

    // Save to persistent storage and mark conversation as read
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
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightRed,
              ),
              child: Center(
                child: Text(
                  widget.otherUserName.isNotEmpty
                      ? widget.otherUserName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherUserName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _conversation.isEmpty
                    ? const Center(
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
                      const TextStyle(color: AppColors.secondaryText),
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryRed,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
