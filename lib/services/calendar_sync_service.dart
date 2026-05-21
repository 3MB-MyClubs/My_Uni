import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/event.dart';

class CalendarSyncService extends ChangeNotifier {
  static const _boxName = 'calendar_sync_v1';
  late Box<dynamic> _box;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _box = await Hive.openBox<dynamic>(_boxName);
    _initialized = true;
  }

  bool isSynced(String userId, String eventId) {
    if (!_initialized || userId.isEmpty) return false;
    return _box.get(_key(userId, eventId), defaultValue: false) == true;
  }

  Future<bool> addToDeviceCalendar(
    Event event,
    String userId, {
    bool force = false,
  }) async {
    if (!_initialized || userId.isEmpty) return false;
    final key = _key(userId, event.id);
    if (!force && _box.get(key, defaultValue: false) == true) return true;

    try {
      final added = await cal.Add2Calendar.addEvent2Cal(
        cal.Event(
          title: event.title,
          description: event.description,
          location: event.location,
          startDate: event.dateTime,
          endDate: event.endTime,
          allDay: false,
        ),
      );
      if (added) {
        await _box.put(key, true);
        notifyListeners();
      }
      return added;
    } catch (_) {
      return false;
    }
  }

  Future<void> markSynced(String userId, String eventId) async {
    if (!_initialized || userId.isEmpty) return;
    await _box.put(_key(userId, eventId), true);
    notifyListeners();
  }

  String _key(String userId, String eventId) => '${userId}_$eventId';
}

final calendarSyncService = CalendarSyncService();
