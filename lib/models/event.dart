class Event {
  final String id;
  final String clubId;
  final String title;
  final String description;
  final DateTime dateTime;   // start time
  final DateTime endTime;    // end time
  final String location;
  final List<String> attendeeUserIds;
  // userId → ISO-8601 datetime string of when they RSVP'd
  final Map<String, String> rsvpTimestamps;
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
    Map<String, String>? rsvpTimestamps,
    this.imagePath,
    this.createdByUserId,
  }) : rsvpTimestamps = rsvpTimestamps ?? {};

  Map<String, dynamic> toMap() => {
        'id': id,
        'clubId': clubId,
        'title': title,
        'description': description,
        'dateTime': dateTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'location': location,
        'attendeeUserIds': attendeeUserIds,
        'rsvpTimestamps': rsvpTimestamps,
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
        rsvpTimestamps: m['rsvpTimestamps'] != null
            ? Map<String, String>.from(m['rsvpTimestamps'] as Map)
            : {},
        imagePath: m['imagePath'] as String?,
        createdByUserId: m['createdByUserId'] as String?,
      );
}
