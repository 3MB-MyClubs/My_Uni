import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../models/event.dart';
import 'locale_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _initialized = false;
  final StreamController<Map<String, dynamic>> _remoteNotificationTaps =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get remoteNotificationTaps =>
      _remoteNotificationTaps.stream;

  // No BuildContext is available this deep in the service layer; system
  // notification text is resolved here via the current locale.
  AppLocalizations get _l10n =>
      lookupAppLocalizations(Locale(localeService.languageCode));

  NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  Future<void>? _initializing;

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializing ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android initialization
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    // Combined initialization
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    _initialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _remoteNotificationTaps.add(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      // Ignore malformed payloads from stale notification versions.
    }
  }

  Future<void> requestPermissions() async {
    if (!_initialized) await initialize();
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
  }

  Future<void> showRemoteNotification({
    required int id,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? groupKey,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'clubup_notifications',
      'ClubUp notifications',
      channelDescription: 'Messages and activity from ClubUp',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      groupKey: groupKey,
      // Keep the native (tag, id) pair stable for a conversation. This also
      // covers notifications created locally while the app is foregrounded.
      tag: groupKey,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: groupKey,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data),
    );
  }

  Future<void> scheduleEventReminders(Event event) async {
    if (!_initialized) await initialize();
    await requestPermissions();

    await cancelEventReminders(event.id);
    await _scheduleEventReminder(
      event: event,
      reminderId: _eventReminderId(event.id, 'day'),
      before: const Duration(days: 1),
      body: _l10n.eventStartsTomorrow(event.title),
    );
    await _scheduleEventReminder(
      event: event,
      reminderId: _eventReminderId(event.id, 'hour'),
      before: const Duration(hours: 1),
      body: _l10n.eventStartsInOneHour(event.title),
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
    required String body,
  }) async {
    final reminderAt = event.dateTime.subtract(before);
    if (!reminderAt.isAfter(DateTime.now())) return;

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'event_reminders',
          _l10n.eventReminderChannelName,
          channelDescription: _l10n.eventReminderChannelDescription,
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

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      reminderId,
      _l10n.eventReminderTitle,
      body,
      tz.TZDateTime.from(reminderAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  int _eventReminderId(String eventId, String offset) =>
      'event_reminder_${eventId}_$offset'.hashCode;

  /// Stable notification ids let a new message replace the previous system
  /// notification for the same conversation instead of creating another row.
  int notificationIdFor(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}

// Global instance
final notificationService = NotificationService();
