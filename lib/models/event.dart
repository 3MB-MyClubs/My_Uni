class Event {
  final String id;
  final String clubId;
  final String title;
  final String description;
  final DateTime dateTime;   // start time
  final DateTime endTime;    // end time
  final String location;
  final List<String> attendeeUserIds;

  Event({
    required this.id,
    required this.clubId,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.endTime,
    required this.location,
    required this.attendeeUserIds,
  });
}
