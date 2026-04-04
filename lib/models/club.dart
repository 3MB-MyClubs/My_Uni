class Club {
  final String id;
  final String name;
  final String description;
  final List<String> adminUserIds;
  // Regular users promoted to board member — restricted to 1 club like admins.
  final List<String> boardMemberIds;

  Club({
    required this.id,
    required this.name,
    required this.description,
    required this.adminUserIds,
    List<String>? boardMemberIds,
  }) : boardMemberIds = boardMemberIds ?? [];
}
