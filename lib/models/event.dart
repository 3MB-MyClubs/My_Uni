/// Event times are displayed as local campus/device wall-clock values.
/// Supabase `timestamptz` fields commonly arrive with `Z` or an explicit
/// offset, so normalize them at the model boundary instead of requiring every
/// screen to remember to call `toLocal()`.
DateTime? tryParseEventDateTime(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

DateTime parseEventDateTime(String raw) => DateTime.parse(raw).toLocal();

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
    time: parseEventDateTime(m['time'] as String),
    title: m['title'] as String,
    subtitle: m['subtitle'] as String?,
    isHighlighted: m['isHighlighted'] as bool? ?? false,
  );
}

/// A featured speaker for an event (shown on the attendee event detail).
class EventSpeaker {
  final String name;
  final String role;
  final String? linkedin;

  const EventSpeaker({required this.name, this.role = '', this.linkedin});

  Map<String, dynamic> toMap() => {
    'name': name,
    'role': role,
    'linkedin': linkedin,
  };

  factory EventSpeaker.fromMap(Map<String, dynamic> m) => EventSpeaker(
    name: m['name'] as String,
    role: m['role'] as String? ?? '',
    linkedin: m['linkedin'] as String?,
  );
}

class Event {
  final String id;
  final String clubId;
  final String title;
  final String description;
  final DateTime dateTime; // start time
  final DateTime endTime; // end time
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

  /// Hex color string (e.g. 'FF8C1D40') chosen by the creator.
  /// Overrides the auto-generated club color in EventDetailScreen.
  final String? accentColorHex;

  /// External sign-up link (Google Form, Eventbrite…). When set, the event
  /// detail shows a "Register to attend" action that opens this URL.
  final String? registrationUrl;

  /// Optional seat cap — drives the "X of Y seats taken" capacity bar.
  final int? capacity;

  /// Featured speakers shown on the attendee detail (name, role, LinkedIn).
  final List<EventSpeaker> speakers;

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
    this.accentColorHex,
    this.registrationUrl,
    this.capacity,
    List<EventSpeaker>? speakers,
  }) : rsvpTimestamps = rsvpTimestamps ?? {},
       tags = tags ?? [],
       speakers = speakers ?? const [];

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
    'accentColorHex': accentColorHex,
    'registrationUrl': registrationUrl,
    'capacity': capacity,
    'speakers': speakers.map((s) => s.toMap()).toList(),
  };

  factory Event.fromMap(Map<String, dynamic> m) => Event(
    id: m['id'] as String,
    clubId: m['clubId'] as String,
    title: m['title'] as String,
    description: m['description'] as String,
    dateTime: parseEventDateTime(m['dateTime'] as String),
    endTime: parseEventDateTime(m['endTime'] as String),
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
              .map(
                (s) => EventSlot.fromMap(Map<String, dynamic>.from(s as Map)),
              )
              .toList()
        : null,
    accentColorHex: m['accentColorHex'] as String?,
    registrationUrl: m['registrationUrl'] as String?,
    capacity: m['capacity'] as int?,
    speakers: m['speakers'] != null
        ? (m['speakers'] as List)
              .map(
                (s) =>
                    EventSpeaker.fromMap(Map<String, dynamic>.from(s as Map)),
              )
              .toList()
        : const [],
  );
}
