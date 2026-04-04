class NewsPost {
  final String id;
  final String clubId;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final List<String> taggedClubIds;
  // null = use club gradient fallback
  // "tpl:N" = built-in template index N
  // any other string = local file path picked from gallery
  final String? imagePath;

  // Legacy — kept only so existing mock data compiles without changes.
  // Not displayed anywhere in the UI.
  final String title;

  NewsPost({
    required this.id,
    required this.clubId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.title = '',
    this.taggedClubIds = const [],
    this.imagePath,
  });
}
