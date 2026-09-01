const int kClubInitialsMaxLength = 15;

/// Removes the optional display prefix while preserving the capitalization
/// chosen by the club (for example `@IES` is stored as `IES`).
String normalizeClubInitials(String value) =>
    value.trim().replaceFirst(RegExp(r'^@+'), '');

bool isValidClubInitials(String value) {
  final normalized = normalizeClubInitials(value);
  return normalized.isNotEmpty &&
      normalized.length <= kClubInitialsMaxLength &&
      RegExp(r'^[A-Za-z0-9_çğıöşüÇĞİÖŞÜ]+$').hasMatch(normalized);
}

/// The value shown after `@` for a club: its chosen initials when it has them,
/// otherwise initials derived from its name.
String clubHandle(Club club) {
  final shortName = club.shortName?.trim();
  if (shortName != null && shortName.isNotEmpty) {
    return normalizeClubInitials(shortName);
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

  /// Editable club initials persisted as Supabase `clubs.short_name`.
  String? shortName;
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
