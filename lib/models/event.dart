class Event {
  final String id;
  final String clubId;
  final String title;
  final String description;
  final DateTime dateTime;
  final List<String> attendeeUserIds;

  Event({
    required this.id,
    required this.clubId,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.attendeeUserIds,
  });
}
