import '../../../models/event.dart' as app;

class CalendarEventModel {
  final String appEventId;
  final String title;
  final String description;
  final String location;
  final DateTime startDate;
  final DateTime endDate;
  final String? url;

  const CalendarEventModel({
    required this.appEventId,
    required this.title,
    required this.description,
    required this.location,
    required this.startDate,
    required this.endDate,
    this.url,
  });

  factory CalendarEventModel.fromAppEvent(app.Event event) =>
      CalendarEventModel(
        appEventId: event.id,
        title: event.title,
        description: event.description,
        location: event.location,
        startDate: event.dateTime,
        endDate: event.endTime,
        url: 'myclubs://event/${event.id}',
      );
}
