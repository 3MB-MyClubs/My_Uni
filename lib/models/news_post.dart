class NewsPost {
  final String id;
  final String clubId;
  final String authorId;
  final String title;
  final String content;
  final DateTime createdAt;

  NewsPost({
    required this.id,
    required this.clubId,
    required this.authorId,
    required this.title,
    required this.content,
    required this.createdAt,
  });
}
