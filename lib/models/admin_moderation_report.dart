class AdminModerationReport {
  final String id;
  final String reporterId;
  final String targetType;
  final String targetId;
  final String reason;
  final String source;
  final String? reportedUserId;
  final String? reportedClubId;
  final String? contentSnapshot;
  final DateTime createdAt;

  const AdminModerationReport({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.source,
    required this.createdAt,
    this.reportedUserId,
    this.reportedClubId,
    this.contentSnapshot,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'reporterId': reporterId,
    'targetType': targetType,
    'targetId': targetId,
    'reason': reason,
    'source': source,
    'reportedUserId': reportedUserId,
    'reportedClubId': reportedClubId,
    'contentSnapshot': contentSnapshot,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AdminModerationReport.fromMap(Map<String, dynamic> map) {
    return AdminModerationReport(
      id: map['id']?.toString() ?? '',
      reporterId: map['reporterId']?.toString() ?? '',
      targetType: map['targetType']?.toString() ?? '',
      targetId: map['targetId']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      source: map['source']?.toString() ?? 'report',
      reportedUserId: _optionalString(map['reportedUserId']),
      reportedClubId: _optionalString(map['reportedClubId']),
      contentSnapshot: _optionalString(map['contentSnapshot']),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
