class Club {
  final String id;
  final String name;
  final String? shortName;
  // Editable by the club's own admin from Settings. Mutable so an edit shows
  // everywhere the club is displayed; persisted globally and re-applied at start.
  String description;
  final String? logoUrl;
  final String? categoryId;
  final String? categoryName;
  final String? email;
  final List<String> adminUserIds;
  // Regular users promoted to board member — restricted to 1 club like admins.
  final List<String> boardMemberIds;
  // Admin-assigned title per board member, keyed by userId.
  final Map<String, String> boardMemberTitles;

  Club({
    required this.id,
    required this.name,
    this.shortName,
    required this.description,
    this.logoUrl,
    this.categoryId,
    this.categoryName,
    this.email,
    required this.adminUserIds,
    List<String>? boardMemberIds,
    Map<String, String>? boardMemberTitles,
  }) : boardMemberIds = boardMemberIds ?? [],
       boardMemberTitles = boardMemberTitles ?? {};
}
