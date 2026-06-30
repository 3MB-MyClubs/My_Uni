import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/club_chat_service.dart';
import '../services/group_chat_service.dart' show GroupMessage;
import '../services/mock_data.dart';
import '../services/presence_service.dart';
import '../services/user_state.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/club_avatar.dart';

const List<Color> _memberColors = [
  Color(0xFFB41C18),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFFE65100),
  Color(0xFF00838F),
  Color(0xFF558B2F),
  Color(0xFF283593),
  Color(0xFF6D4C41),
];

Color _colorForUser(String userId) {
  final idx = users.indexWhere((u) => u.id == userId);
  return _memberColors[(idx < 0 ? 0 : idx) % _memberColors.length];
}

/// A club's joint discussion channel — every member talks together here.
class ClubChannelScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final Color color;

  const ClubChannelScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.color,
  });

  @override
  State<ClubChannelScreen> createState() => _ClubChannelScreenState();
}

class _ClubChannelScreenState extends State<ClubChannelScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  String get _typingKey => 'club_${widget.clubId}';

  @override
  void initState() {
    super.initState();
    clubChatService.markRead(widget.clubId);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(animate: false),
    );
  }

  String _nameFor(String uid) {
    try {
      final u = users.firstWhere((u) => u.id == uid);
      return userState.displayNameFor(u.id, u.name).split(' ').first;
    } catch (_) {
      return 'Member';
    }
  }

  void _appendOwn(String content) {
    clubChatService.addMessage(
      widget.clubId,
      GroupMessage(
        id: 'cc_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _myId,
        content: content,
        sentAt: DateTime.now(),
      ),
    );
    clubChatService.markRead(widget.clubId);
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
      _appendOwn('kuphoto:shared_photo.jpg');
    } else if (choice == 'voice') {
      _appendOwn('kuvoice:0:08');
    }
  }

  void _onCamera() => _appendOwn('kuphoto:camera_shot.jpg');
  void _onMic() => _appendOwn('kuvoice:0:06');

  static const _autoReplies = [
    'Great point! 👍',
    'Agreed 🙌',
    'Count me in!',
    'Thanks for sharing 🎉',
    'See you all there!',
    'Sounds good to me 😄',
  ];

  Future<void> _simulateReply() async {
    final others = clubChatService
        .memberIdsFor(widget.clubId)
        .where((id) => id != _myId)
        .toList();
    if (others.isEmpty) return;
    final responder =
        others[DateTime.now().millisecondsSinceEpoch % others.length];
    presenceService.startTyping(_typingKey);
    await Future.delayed(const Duration(seconds: 3));
    presenceService.stopTyping(_typingKey);
    if (!mounted) return;
    final reply =
        _autoReplies[DateTime.now().millisecondsSinceEpoch %
            _autoReplies.length];
    clubChatService.addMessage(
      widget.clubId,
      GroupMessage(
        id: 'cc_sim_${DateTime.now().millisecondsSinceEpoch}',
        senderId: responder,
        content: reply,
        sentAt: DateTime.now(),
      ),
    );
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  void dispose() {
    presenceService.clearTypingQuietly(_typingKey);
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
            _header(),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  clubChatService,
                  presenceService,
                ]),
                builder: (context, _) => _buildMessageList(),
              ),
            ),
            ChatComposer(
              controller: _controller,
              onSend: _send,
              onAttach: _onAttach,
              onCamera: _onCamera,
              onMic: _onMic,
              hint: 'Message ${widget.clubName.split(' ').first}…',
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final members = clubChatService.memberIdsFor(widget.clubId);
    final active = members.where((m) => presenceService.isOnline(m)).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.primaryRed,
              size: 22,
            ),
          ),
          ClubAvatar(
            clubId: widget.clubId,
            clubName: widget.clubName,
            color: widget.color,
            imageUrl: clubs.any((club) => club.id == widget.clubId)
                ? clubs.firstWhere((club) => club.id == widget.clubId).logoUrl
                : null,
            size: 40,
            fontSize: 16,
            borderRadius: 13,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.clubName,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Club',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '${members.length} members'
                  '${active > 0 ? ' · $active active' : ''} · group discussion',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: active > 0 ? kOnlineGreen : AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceAlt,
              border: Border.all(color: AppColors.divider),
            ),
            child: Icon(
              Icons.groups_rounded,
              size: 19,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final msgs = clubChatService.messagesFor(widget.clubId);
    if (msgs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 56,
                color: AppColors.secondaryText,
              ),
              const SizedBox(height: 14),
              Text(
                'No messages yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Be the first to start the discussion in this club.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    final items = <_CRow>[];
    DateTime? lastDay;
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final day = DateTime(m.sentAt.year, m.sentAt.month, m.sentAt.day);
      if (lastDay == null || day != lastDay) {
        items.add(_CRow.divider(chatDateLabel(m.sentAt)));
        lastDay = day;
      }
      items.add(_CRow.message(m, i));
    }

    final typing = presenceService.isTyping(_typingKey);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      itemCount: items.length + (typing ? 1 : 0),
      itemBuilder: (ctx, idx) {
        if (typing && idx == items.length) {
          final others = clubChatService
              .memberIdsFor(widget.clubId)
              .where((id) => id != _myId)
              .toList();
          final who = others.isNotEmpty ? others.first : '';
          return TypingBubble(
            isGroup: true,
            senderUserId: who,
            senderName: _nameFor(who),
          );
        }

        final row = items[idx];
        if (row.isDivider) return ChatDivider(label: row.label!);

        final m = row.message!;
        final isMe = m.senderId == _myId;

        final prev = idx > 0 ? items[idx - 1] : null;
        final next = idx < items.length - 1 ? items[idx + 1] : null;
        final prevSame =
            prev != null &&
            !prev.isDivider &&
            prev.message!.senderId == m.senderId;
        final nextSame =
            next != null &&
            !next.isDivider &&
            next.message!.senderId == m.senderId;

        String? status;
        if (isMe) {
          status = (row.originalIndex == msgs.length - 1)
              ? 'delivered'
              : 'read';
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

class _CRow {
  final bool isDivider;
  final String? label;
  final GroupMessage? message;
  final int originalIndex;
  _CRow.divider(this.label)
    : isDivider = true,
      message = null,
      originalIndex = -1;
  _CRow.message(this.message, this.originalIndex)
    : isDivider = false,
      label = null;
}
