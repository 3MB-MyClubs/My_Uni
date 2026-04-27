class EventSlot {
  final DateTime time;
  final String title;
  final String? subtitle;
  final bool isHighlighted;

  const EventSlot({
    required this.time,
    required this.title,
    this.subtitle,
    this.isHighlighted = false,
  });

  Map<String, dynamic> toMap() => {
        'time': time.toIso8601String(),
        'title': title,
        'subtitle': subtitle,
        'isHighlighted': isHighlighted,
      };

  factory EventSlot.fromMap(Map<String, dynamic> m) => EventSlot(
        time: DateTime.parse(m['time'] as String),
        title: m['title'] as String,
        subtitle: m['subtitle'] as String?,
        isHighlighted: m['isHighlighted'] as bool? ?? false,
      );
}

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
  final List<String> tags;
  final String? guestSpeaker;
  final List<EventSlot>? schedule;
  final bool scheduleGated;

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
    List<String>? tags,
    this.guestSpeaker,
    this.schedule,
    this.scheduleGated = false,
  })  : rsvpTimestamps = rsvpTimestamps ?? {},
        tags = tags ?? [];

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
        'tags': tags,
        'guestSpeaker': guestSpeaker,
        'schedule': schedule?.map((s) => s.toMap()).toList(),
        'scheduleGated': scheduleGated,
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
        tags: m['tags'] != null ? List<String>.from(m['tags'] as List) : [],
        guestSpeaker: m['guestSpeaker'] as String?,
        schedule: m['schedule'] != null
            ? (m['schedule'] as List)
                .map((s) => EventSlot.fromMap(Map<String, dynamic>.from(s as Map)))
                .toList()
            : null,
        scheduleGated: m['scheduleGated'] as bool? ?? false,
      );
}
