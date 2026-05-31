import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/group_chat_service.dart';
import '../services/message_service.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
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

  // All contacts: every user (except self) + every club
  List<_Contact> get _allContacts {
    final myId = _myId;
    return [
      ...users
          .where((u) => u.id != myId)
          .map((u) => _Contact(
                id: u.id,
                name: userState.displayNameFor(u.id, u.name),
                isClub: false,
                isAdmin: u.role == 'admin',
              )),
      ...clubs.map((c) => _Contact(id: c.id, name: c.name, isClub: true)),
    ];
  }

  // Contacts filtered by search query
  List<_Contact> get _searchResults {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _allContacts
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
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

  String _nameFor(String otherId) {
    try {
      return clubs.firstWhere((c) => c.id == otherId).name;
    } catch (_) {}
    try {
      final u = users.firstWhere((u) => u.id == otherId);
      return userState.displayNameFor(u.id, u.name);
    } catch (_) {}
    return 'Unknown';
  }

  bool _isClub(String id) => clubs.any((c) => c.id == id);

  void _openChat(String otherId, String otherName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(otherUserId: otherId, otherUserName: otherName),
      ),
    ).then((_) => setState(() {}));
  }

  static const _clubColors = [
    Color(0xFF8C1D40), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  Widget _avatarFor(String id, String name) {
    if (_isClub(id)) {
      final idx = clubs.indexWhere((c) => c.id == id);
      final color = _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
      return ClubAvatar(
        clubId: id,
        clubName: name,
        color: color,
        size: 56,
        fontSize: 22,
        borderRadius: 14,
      );
    }
    return UserAvatar(userId: id, name: name, size: 56, fontSize: 20);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _groupTitle(GroupChat g) {
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
    if (msg.content.startsWith('kupost:')) return '📄 Shared a post';
    if (msg.content.startsWith('kuevent:')) return '📅 Shared an event';
    final name = msg.senderId == _myId ? 'You' : (() {
      try {
        return users.firstWhere((u) => u.id == msg.senderId).name.split(' ').first;
      } catch (_) {
        return 'Someone';
      }
    })();
    return '$name: ${msg.content}';
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
        title: Text(
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
                hintText: 'Search people or clubs...',
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.secondaryText),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 18),
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
                            Icon(Icons.search_off,
                                size: 48, color: AppColors.secondaryText),
                            const SizedBox(height: 12),
                            Text(
                              'No results for "$_query"',
                              style: TextStyle(
                                  color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (context, i) =>
                            Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) => _ContactResultTile(
                          contact: results[i],
                          onTap: () =>
                              _openChat(results[i].id, results[i].name),
                        ),
                      )
                // ── Conversation list (groups + DMs) ─────────────────────
                : ListenableBuilder(
                    listenable: groupChatService,
                    builder: (context, child) {
                      final groups = groupChatService.groupsForUser(_myId);
                      if (partnerIds.isEmpty && groups.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 72, color: AppColors.secondaryText),
                              const SizedBox(height: 16),
                              Text('No messages yet',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                              const SizedBox(height: 8),
                              Text('Search for a person or club above to start chatting',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.secondaryText)),
                            ],
                          ),
                        );
                      }

                      return ListView(
                        children: [
                          // ── Group chats ──────────────────────────────────
                          if (groups.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                              child: Text('GROUPS',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                      color: AppColors.secondaryText, letterSpacing: 0.8)),
                            ),
                            ...groups.map((g) {
                              final title = _groupTitle(g);
                              final preview = _lastGroupPreview(g);
                              final ts = g.lastMessage?.sentAt ?? g.createdAt;
                              return InkWell(
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => GroupChatScreen(group: g)))
                                    .then((_) => setState(() {})),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      // Overlapping mini-avatars
                                      SizedBox(
                                        width: (g.memberIds.length.clamp(1, 3) * 18 + 14).toDouble(),
                                        height: 48,
                                        child: Stack(
                                          children: g.memberIds.take(3).toList().asMap().entries.map((e) =>
                                            Positioned(
                                              left: e.key * 18.0,
                                              top: e.key * 4.0,
                                              child: Container(
                                                decoration: BoxDecoration(shape: BoxShape.circle,
                                                    border: Border.all(color: AppColors.background, width: 2)),
                                                child: UserAvatar(
                                                  userId: e.value,
                                                  name: (() { try { return users.firstWhere((u) => u.id == e.value).name; } catch (_) { return '?'; } })(),
                                                  size: 28, fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ).toList(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryRed.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text('Group',
                                                    style: TextStyle(fontSize: 10, color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(child: Text(title,
                                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                                                  overflow: TextOverflow.ellipsis)),
                                            ]),
                                            const SizedBox(height: 2),
                                            Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_timeLabel(ts),
                                          style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            Divider(height: 1, indent: 16),
                          ],

                          // ── Direct messages ──────────────────────────────
                          if (partnerIds.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                              child: Text('DIRECT MESSAGES',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                      color: AppColors.secondaryText, letterSpacing: 0.8)),
                            ),
                            ...partnerIds.asMap().entries.map((entry) {
                              final i = entry.key;
                              final otherId = entry.value;
                              final name = _nameFor(otherId);
                              final last = _lastMessage(otherId);
                              final isSentByMe = last != null && last.senderId == _myId;
                              final all = _allMessages;
                              final unread = !isSentByMe && messageService.hasUnread(_myId, otherId, all);
                              final unreadCount = unread ? messageService.unreadCount(_myId, otherId, all) : 0;
                              final isClub = _isClub(otherId);

                              return Column(
                                children: [
                                  if (i > 0) Divider(height: 1, indent: 72),
                                  InkWell(
                                    onTap: () => _openChat(otherId, name),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(
                                        children: [
                                          _avatarFor(otherId, name),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(children: [
                                                  Flexible(child: Text(name,
                                                      style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.w600,
                                                          fontSize: 15, color: AppColors.text),
                                                      overflow: TextOverflow.ellipsis)),
                                                  if (isClub) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: AppColors.lightRed, borderRadius: BorderRadius.circular(8)),
                                                      child: Text('Club', style: TextStyle(fontSize: 10, color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
                                                    ),
                                                  ],
                                                ]),
                                                const SizedBox(height: 2),
                                                if (last != null)
                                                  Text(isSentByMe ? 'You: ${last.content}' : last.content,
                                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          color: unread ? AppColors.text : AppColors.secondaryText,
                                                          fontSize: 13,
                                                          fontWeight: unread ? FontWeight.w600 : FontWeight.normal)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (last != null)
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(_timeLabel(last.sentAt),
                                                    style: TextStyle(fontSize: 11,
                                                        fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                                                        color: unread ? AppColors.primaryRed : AppColors.secondaryText)),
                                                const SizedBox(height: 4),
                                                if (unread)
                                                  Container(
                                                    constraints: const BoxConstraints(minWidth: 20),
                                                    height: 20,
                                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                                    decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(10)),
                                                    child: Center(child: Text(unreadCount > 99 ? '99+' : '$unreadCount',
                                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                                                  )
                                                else
                                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                                    Icon(isSentByMe ? Icons.done_all : Icons.arrow_back_ios_new, size: 11, color: AppColors.secondaryText),
                                                    const SizedBox(width: 3),
                                                    Text(isSentByMe ? 'Delivered' : 'Received',
                                                        style: TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                                                  ]),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ],
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

// ─── Contact data class ────────────────────────────────────────────────────────

class _Contact {
  final String id;
  final String name;
  final bool isClub;
  final bool isAdmin;

  const _Contact({
    required this.id,
    required this.name,
    required this.isClub,
    this.isAdmin = false,
  });
}

// ─── Contact Result Tile ──────────────────────────────────────────────────────

class _ContactResultTile extends StatelessWidget {
  final _Contact contact;
  final VoidCallback onTap;

  const _ContactResultTile({required this.contact, required this.onTap});

  static const _clubColors = [
    Color(0xFF8C1D40), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  @override
  Widget build(BuildContext context) {
    final Widget avatar;
    final Widget? subtitle;

    if (contact.isClub) {
      final idx = clubs.indexWhere((c) => c.id == contact.id);
      final color = _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
      avatar = ClubAvatar(
        clubId: contact.id,
        clubName: contact.name,
        color: color,
        size: 48,
        fontSize: 18,
        borderRadius: 12,
      );
      subtitle = null;
    } else {
      avatar = UserAvatar(
          userId: contact.id, name: contact.name, size: 48, fontSize: 18);
      subtitle = null;
    }

    final badge = contact.isClub
        ? 'Club'
        : contact.isAdmin
            ? 'Club Admin'
            : null;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: avatar,
      title: Row(
        children: [
          Flexible(
            child: Text(contact.name,
                style: TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
      subtitle: subtitle,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primaryRed,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
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
