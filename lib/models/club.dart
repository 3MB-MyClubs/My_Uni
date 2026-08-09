/// The `@handle` shown for a club: its short name when it has one, otherwise
/// the initials of its name (falling back to the whole name for clubs whose
/// words start with non-Latin characters).
String clubHandle(Club club) {
  final shortName = club.shortName?.trim();
  if (shortName != null && shortName.isNotEmpty) {
    return shortName
        .replaceFirst(RegExp(r'^@+'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  final name = club.name;
  final words = name.split(RegExp(r'[\s\-]+'));
  final initials = words
      .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0]))
      .map((w) => w[0])
      .join()
      .toLowerCase();
  return initials.isEmpty
      ? name.toLowerCase().replaceAll(RegExp(r'\s+'), '')
      : initials;
}

class Club {
  final String id;
  String name;
  final String? shortName;
  // Editable by the club's own admin from Settings. Mutable so an edit shows
  // everywhere the club is displayed; persisted globally and re-applied at start.
  String description;
  String? logoUrl;
  String? categoryId;
  String? categoryName;
  final String? email;
  final List<String> adminUserIds;
  // Regular users promoted to board member — restricted to 1 club like admins.
  final List<String> boardMemberIds;
  // Admin-assigned title per board member, keyed by userId.
  final Map<String, String> boardMemberTitles;

  /// When the club was created (Supabase `clubs.created_at`). Null for clubs
  /// built locally, and for rows fetched before this column was selected —
  /// Insights then falls back to the club's earliest post or event.
  final DateTime? createdAt;

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
    this.createdAt,
    List<String>? boardMemberIds,
    Map<String, String>? boardMemberTitles,
  }) : boardMemberIds = boardMemberIds ?? [],
       boardMemberTitles = boardMemberTitles ?? {};
}
