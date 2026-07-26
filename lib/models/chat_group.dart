class ChatGroup {
  final String id;
  final String creatorId;
  final List<String> memberIds;
  final List<String> adminIds;
  final String? customName;
  final String? photoUrl;
  final DateTime createdAt;

  const ChatGroup({
    required this.id,
    required this.creatorId,
    required this.memberIds,
    this.adminIds = const [],
    required this.customName,
    required this.photoUrl,
    required this.createdAt,
  });

  String get threadId => 'group:$id';

  bool isAdmin(String userId) =>
      userId == creatorId || adminIds.contains(userId);

  static String automaticName(Iterable<String> memberNames) {
    final names = memberNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .map((name) => name.split(RegExp(r'\s+')).first)
        .toList();
    if (names.isEmpty) return 'Group';
    if (names.length <= 3) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  String displayName({
    required String viewerId,
    required String Function(String userId) nameForUser,
  }) {
    final custom = customName?.trim() ?? '';
    if (custom.isNotEmpty) return custom;
    return automaticName(
      memberIds.where((memberId) => memberId != viewerId).map(nameForUser),
    );
  }

  ChatGroup withMembers(Iterable<String> members) {
    final nextMembers = members.toSet();
    final retainedAdmins = {
      creatorId,
      ...adminIds,
    }.where(nextMembers.contains).toList(growable: false);
    return ChatGroup(
      id: id,
      creatorId: creatorId,
      memberIds: nextMembers.toList(growable: false),
      adminIds: retainedAdmins,
      customName: customName,
      photoUrl: photoUrl,
      createdAt: createdAt,
    );
  }

  ChatGroup withAdmins(Iterable<String> admins) => ChatGroup(
    id: id,
    creatorId: creatorId,
    memberIds: memberIds,
    adminIds: {
      creatorId,
      ...admins.where(memberIds.contains),
    }.toList(growable: false),
    customName: customName,
    photoUrl: photoUrl,
    createdAt: createdAt,
  );

  ChatGroup withCustomName(String? value) {
    final trimmed = value?.trim() ?? '';
    return ChatGroup(
      id: id,
      creatorId: creatorId,
      memberIds: memberIds,
      adminIds: adminIds,
      customName: trimmed.isEmpty ? null : trimmed,
      photoUrl: photoUrl,
      createdAt: createdAt,
    );
  }

  ChatGroup withPhoto(String? value) {
    final trimmed = value?.trim() ?? '';
    return ChatGroup(
      id: id,
      creatorId: creatorId,
      memberIds: memberIds,
      adminIds: adminIds,
      customName: customName,
      photoUrl: trimmed.isEmpty ? null : trimmed,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'creatorId': creatorId,
    'memberIds': memberIds,
    'adminIds': {creatorId, ...adminIds}.toList(growable: false),
    'customName': customName,
    'photoUrl': photoUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatGroup.fromMap(Map<String, dynamic> map) {
    final custom = map['customName']?.toString().trim() ?? '';
    return ChatGroup(
      id: map['id'].toString(),
      creatorId: map['creatorId']?.toString() ?? '',
      memberIds: (map['memberIds'] as List? ?? const [])
          .map((id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false),
      adminIds: (map['adminIds'] as List? ?? const [])
          .map((id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false),
      customName: custom.isEmpty ? null : custom,
      photoUrl: _nullableString(map['photoUrl']),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
