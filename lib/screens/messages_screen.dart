import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import 'chat_screen.dart';

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

  // All users the current user follows (excluding self)
  List<User> get _followedUsers => users
      .where((u) => userState.isFollowingUser(u.id) && u.id != _myId)
      .toList();

  // Followed users filtered by search query
  List<User> get _searchResults {
    if (_query.isEmpty) return [];
    return _followedUsers.where((u) =>
        u.name.toLowerCase().contains(_query.toLowerCase()) ||
        u.email.toLowerCase().contains(_query.toLowerCase())).toList();
  }

  // All messages from both mock seed data and Hive-persisted messages
  List<Message> get _allMessages {
    final hiveMessages = messageService.getAllMessages();
    final hiveIds = hiveMessages.map((m) => m.id).toSet();
    final merged = [...hiveMessages];
    for (final m in messages) {
      if (!hiveIds.contains(m.id)) merged.add(m);
    }
    return merged;
  }

  // Existing conversation partner IDs, sorted by last message time
  List<String> get _conversationPartnerIds {
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
    final convo = _allMessages
        .where((m) =>
            (m.senderId == _myId && m.receiverId == otherId) ||
            (m.senderId == otherId && m.receiverId == _myId))
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return convo.isEmpty ? null : convo.first;
  }

  String _userName(String userId) {
    try {
      return users.firstWhere((u) => u.id == userId).name;
    } catch (_) {
      return 'Unknown';
    }
  }

  bool _isMutual(String otherId) {
    final meFollowsThem = userState.isFollowingUser(otherId);
    final theyFollowMe = users
        .firstWhere((u) => u.id == otherId, orElse: () => users.first)
        .followingUserIds
        .contains(_myId);
    return meFollowsThem && theyFollowMe;
  }

  void _openChat(String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(otherUserId: userId, otherUserName: userName),
      ),
    ).then((_) => setState(() {}));
  }

  Future<void> _tryOpenChat(String userId, String userName) async {
    if (userState.isProfilePrivate(userId) && !userState.isFollowingUser(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userState.hasPendingRequest(userId)
                ? 'Wait for $userName to accept your follow request first.'
                : 'Request to follow $userName before sending a message.',
          ),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isMutual(userId) || userState.hasAcceptedMessageRequest(_myId, userId)) {
      _openChat(userId, userName);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Send message request?',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: Text(
          '$userName doesn\'t follow you back yet. Your message will be sent as a request — they\'ll need to accept it before you can chat freely.',
          style: const TextStyle(fontSize: 14, color: AppColors.secondaryText, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      userState.acceptMessageRequest(_myId, userId);
      _openChat(userId, userName);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _searchResults;
    final partnerIds = _conversationPartnerIds;
    final isSearching = _query.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search people to message...',
                prefixIcon: const Icon(Icons.person_search_outlined,
                    color: AppColors.secondaryText),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.lightGray,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: isSearching
                // ── Search results ────────────────────────────────────────
                ? results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off,
                                size: 48, color: AppColors.secondaryText),
                            const SizedBox(height: 12),
                            Text(
                              'No followed users match "$_query"',
                              style: const TextStyle(
                                  color: AppColors.secondaryText),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'You can only message people you follow.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (context, i) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) =>
                            _UserResultTile(
                              user: results[i],
                              onTap: () => _tryOpenChat(
                                  results[i].id, results[i].name),
                            ),
                      )
                // ── Conversation list ─────────────────────────────────────
                : partnerIds.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble_outline,
                                size: 72, color: AppColors.secondaryText),
                            const SizedBox(height: 16),
                            const Text(
                              'No messages yet',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Search for a name above to start chatting',
                              style: TextStyle(
                                  color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: partnerIds.length,
                        separatorBuilder: (context, i) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) {
                          final otherId = partnerIds[i];
                          final name = _userName(otherId);
                          final last = _lastMessage(otherId);
                          final isSentByMe =
                              last != null && last.senderId == _myId;
                          final all = _allMessages;
                          final unread = !isSentByMe &&
                              messageService.hasUnread(_myId, otherId, all);
                          final unreadCount = unread
                              ? messageService.unreadCount(_myId, otherId, all)
                              : 0;

                          return InkWell(
                            onTap: () => _tryOpenChat(otherId, name),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.lightRed,
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryRed,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Name + message preview
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: unread
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            fontSize: 15,
                                            color: unread
                                                ? AppColors.text
                                                : AppColors.text,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        if (last != null)
                                          Text(
                                            isSentByMe
                                                ? 'You: ${last.content}'
                                                : last.content,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: unread
                                                  ? AppColors.text
                                                  : AppColors.secondaryText,
                                              fontSize: 13,
                                              fontWeight: unread
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Time + unread badge or delivery status
                                  if (last != null)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _timeLabel(last.sentAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: unread
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: unread
                                                ? AppColors.primaryRed
                                                : AppColors.secondaryText,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (unread)
                                          Container(
                                            constraints: const BoxConstraints(minWidth: 20),
                                            height: 20,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryRed,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                unreadCount > 99
                                                    ? '99+'
                                                    : '$unreadCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isSentByMe
                                                    ? Icons.done_all
                                                    : Icons.arrow_back_ios_new,
                                                size: 11,
                                                color: AppColors.secondaryText,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                isSentByMe
                                                    ? 'Delivered'
                                                    : 'Received',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.secondaryText,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final daysDiff = today.difference(msgDay).inDays;

    if (daysDiff == 1) return 'Yesterday';
    if (daysDiff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (dt.year == now.year) return '${months[dt.month - 1]} ${dt.day}';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ─── User Result Tile ─────────────────────────────────────────────────────────

class _UserResultTile extends StatelessWidget {
  final User user;
  final VoidCallback onTap;

  const _UserResultTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isClubAdmin = user.role == 'admin';
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.lightRed,
        ),
        child: Center(
          child: Text(
            user.name[0].toUpperCase(),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryRed,
                fontSize: 18),
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(user.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          if (isClubAdmin) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Club Admin',
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(user.email,
          style: const TextStyle(
              fontSize: 12, color: AppColors.secondaryText)),
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
              color: Colors.white),
        ),
      ),
      onTap: onTap,
    );
  }
}
