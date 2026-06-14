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

  void _openComposeSheet() async {
    final myId = _myId;
    final contacts = _allContacts.where((c) => !c.isClub).toList();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            tooltip: 'New conversation',
            onPressed: _openComposeSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openComposeSheet,
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit_rounded),
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
    return widget.contacts.where((c) => c.name.toLowerCase().contains(q)).toList();
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
    final canStart = _selected.isNotEmpty && (!isGroup || _groupNameCtrl.text.trim().isNotEmpty);
    final height = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('New Conversation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
                ),
              ],
            ),
          ),

          // Selected chips
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _selected.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.primaryRed.withValues(alpha: 0.12),
                    label: Text(c.name.split(' ').first,
                        style: TextStyle(fontSize: 12, color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
                    deleteIconColor: AppColors.primaryRed,
                    onDeleted: () => _toggle(c),
                    padding: EdgeInsets.zero,
                  ),
                )).toList(),
              ),
            ),
          ],

          // Group name field
          if (_showGroupName) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _groupNameCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Group name',
                  prefixIcon: Icon(Icons.group_rounded, color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.secondaryText),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Results list
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text('No results', style: TextStyle(color: AppColors.secondaryText)),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (ctx, i) => Divider(height: 1, indent: 64),
                    itemBuilder: (_, i) {
                      final c = _results[i];
                      final selected = _isSelected(c);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: UserAvatar(userId: c.id, name: c.name, size: 44, fontSize: 16),
                        title: Text(c.name,
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                        trailing: selected
                            ? Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 16),
                              )
                            : Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.divider, width: 1.5),
                                ),
                              ),
                        onTap: () => _toggle(c),
                      );
                    },
                  ),
          ),

          // Start button
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? 'Select someone'
                        : isGroup
                            ? 'Create Group'
                            : 'Start Chat with ${_selected.first.name.split(' ').first}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
