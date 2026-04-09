/// A persistent record of a board-member application.
///
/// Status lifecycle: pending → approved | declined
class BoardMemberRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String clubId;
  final DateTime requestedAt;

  /// 'pending' | 'approved' | 'declined'
  String status;

  BoardMemberRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.clubId,
    required this.requestedAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'clubId': clubId,
        'requestedAt': requestedAt.toIso8601String(),
        'status': status,
      };

  factory BoardMemberRequest.fromMap(Map<String, dynamic> m) =>
      BoardMemberRequest(
        id: m['id'] as String,
        userId: m['userId'] as String,
        userName: m['userName'] as String,
        userEmail: m['userEmail'] as String,
        clubId: m['clubId'] as String,
        requestedAt: DateTime.parse(m['requestedAt'] as String),
        status: m['status'] as String? ?? 'pending',
      );
}
