import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/event.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _initialized = false;

  NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android initialization
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    // Combined initialization
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Request permissions (iOS)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
  }


  Future<void> scheduleEventReminders(Event event) async {
    if (!_initialized) await initialize();

    await cancelEventReminders(event.id);
    await _scheduleEventReminder(
      event: event,
      reminderId: _eventReminderId(event.id, 'day'),
      before: const Duration(days: 1),
      label: 'tomorrow',
    );
    await _scheduleEventReminder(
      event: event,
      reminderId: _eventReminderId(event.id, 'hour'),
      before: const Duration(hours: 1),
      label: 'in 1 hour',
    );
  }

  Future<void> cancelEventReminders(String eventId) async {
    if (!_initialized) await initialize();
    await _notificationsPlugin.cancel(_eventReminderId(eventId, 'day'));
    await _notificationsPlugin.cancel(_eventReminderId(eventId, 'hour'));
  }

  Future<void> _scheduleEventReminder({
    required Event event,
    required int reminderId,
    required Duration before,
    required String label,
  }) async {
    final reminderAt = event.dateTime.subtract(before);
    if (!reminderAt.isAfter(DateTime.now())) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'event_reminders',
          'Event reminders',
          channelDescription: 'Reminders for events you RSVP to',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      reminderId,
      'Event reminder',
      '${event.title} starts $label',
      tz.TZDateTime.from(reminderAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  int _eventReminderId(String eventId, String offset) =>
      'event_reminder_${eventId}_$offset'.hashCode;

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}

// Global instance
final notificationService = NotificationService();
