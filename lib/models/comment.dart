class Comment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'postId': postId,
        'userId': userId,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Comment.fromMap(Map<String, dynamic> m) => Comment(
        id: m['id'] as String,
        postId: m['postId'] as String,
        userId: m['userId'] as String,
        content: m['content'] as String,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}
