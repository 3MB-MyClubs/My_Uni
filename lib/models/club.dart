class Club {
  final String id;
  final String name;
  final String description;
  final List<String> adminUserIds;
  // Regular users promoted to board member — restricted to 1 club like admins.
  final List<String> boardMemberIds;
  // Admin-assigned title per board member, keyed by userId.
  final Map<String, String> boardMemberTitles;

  Club({
    required this.id,
    required this.name,
    required this.description,
    required this.adminUserIds,
    List<String>? boardMemberIds,
    Map<String, String>? boardMemberTitles,
  })  : boardMemberIds = boardMemberIds ?? [],
        boardMemberTitles = boardMemberTitles ?? {};
}
