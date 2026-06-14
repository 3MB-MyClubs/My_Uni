import 'package:flutter/foundation.dart';

class GroupMessage {
  final String id;
  final String senderId;
  final String content; // 'kupost:xxx' / 'kuevent:xxx' / plain text
  final DateTime sentAt;

  GroupMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.sentAt,
  });
}

class GroupChat {
  final String id;
  final String creatorId;
  final List<String> memberIds; // includes creator
  final List<GroupMessage> messages;
  final DateTime createdAt;
  final String? name;

  GroupChat({
    required this.id,
    required this.creatorId,
    required this.memberIds,
    required this.messages,
    required this.createdAt,
    this.name,
  });

  GroupMessage? get lastMessage =>
      messages.isEmpty ? null : messages.last;
}

class GroupChatService extends ChangeNotifier {
  final List<GroupChat> _groups = [];

  List<GroupChat> get allGroups => List.unmodifiable(_groups);

  List<GroupChat> groupsForUser(String userId) =>
      _groups.where((g) => g.memberIds.contains(userId)).toList()
        ..sort((a, b) {
          final ta = a.lastMessage?.sentAt ?? a.createdAt;
          final tb = b.lastMessage?.sentAt ?? b.createdAt;
          return tb.compareTo(ta);
        });

  GroupChat createGroup({
    required String creatorId,
    required List<String> memberIds,
    required String initialContent,
    String? groupName,
  }) {
    final all = ({creatorId, ...memberIds}).toList();
    final group = GroupChat(
      id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
      creatorId: creatorId,
      memberIds: all,
      messages: [
        GroupMessage(
          id: 'grpmsg_0_${DateTime.now().millisecondsSinceEpoch}',
          senderId: creatorId,
          content: initialContent,
          sentAt: DateTime.now(),
        ),
      ],
      createdAt: DateTime.now(),
      name: groupName,
    );
    _groups.insert(0, group);
    notifyListeners();
    return group;
  }

  void addMessage(String groupId, GroupMessage message) {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    _groups[idx].messages.add(message);
    // Bring to top of list
    final g = _groups.removeAt(idx);
    _groups.insert(0, g);
    notifyListeners();
  }

  // Only the creator can close/delete a group
  void closeGroup(String groupId, String requesterId) {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    if (_groups[idx].creatorId != requesterId) return;
    _groups.removeAt(idx);
    notifyListeners();
  }
}

final groupChatService = GroupChatService();
