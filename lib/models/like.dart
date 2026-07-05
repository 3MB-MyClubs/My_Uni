class Like {
  final String id;
  final String postId;
  final String userId;

  Like({required this.id, required this.postId, required this.userId});

  Map<String, dynamic> toMap() => {
    'id': id,
    'postId': postId,
    'userId': userId,
  };

  factory Like.fromMap(Map<String, dynamic> m) => Like(
    id: m['id'] as String,
    postId: m['postId'] as String,
    userId: m['userId'] as String,
  );
}
