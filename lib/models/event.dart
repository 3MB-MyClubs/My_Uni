class Event {
  final String id;
  final String clubId;
  final String title;
  final String description;
  final DateTime dateTime;   // start time
  final DateTime endTime;    // end time
  final String location;
  final List<String> attendeeUserIds;
  final String? imagePath;
  // The user ID of whoever created this event. Used for ownership-based deletion.
  final String? createdByUserId;

  Event({
    required this.id,
    required this.clubId,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.endTime,
    required this.location,
    required this.attendeeUserIds,
    this.imagePath,
    this.createdByUserId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'clubId': clubId,
        'title': title,
        'description': description,
        'dateTime': dateTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'location': location,
        'attendeeUserIds': attendeeUserIds,
        'imagePath': imagePath,
        'createdByUserId': createdByUserId,
      };

  factory Event.fromMap(Map<String, dynamic> m) => Event(
        id: m['id'] as String,
        clubId: m['clubId'] as String,
        title: m['title'] as String,
        description: m['description'] as String,
        dateTime: DateTime.parse(m['dateTime'] as String),
        endTime: DateTime.parse(m['endTime'] as String),
        location: m['location'] as String,
        attendeeUserIds: List<String>.from(m['attendeeUserIds'] as List? ?? []),
        imagePath: m['imagePath'] as String?,
        createdByUserId: m['createdByUserId'] as String?,
      );
}
