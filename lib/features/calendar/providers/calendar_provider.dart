import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/calendar_event_model.dart';
import '../services/calendar_service.dart';
import 'calendar_state.dart';

final calendarServiceProvider = Provider<CalendarService>(
  (ref) => CalendarService(),
);

class CalendarEventNotifier extends StateNotifier<CalendarAddState> {
  final String eventId;
  final CalendarService _service;

  CalendarEventNotifier({
    required this.eventId,
    required CalendarService service,
  }) : _service = service,
       super(const CalendarAddIdle()) {
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final added = await _service.isAdded(eventId);
    if (mounted) {
      state = added
          ? const CalendarAddSuccess('Added to calendar')
          : const CalendarAddIdle();
    }
  }

  Future<void> add(CalendarEventModel model) async {
    if (state is CalendarAddLoading || state is CalendarAddSuccess) return;
    state = const CalendarAddLoading();

    var permission = await _service.checkPermission();

    if (permission == CalendarPermissionState.unknown) {
      state = const CalendarAddFailure('Unable to check calendar permissions.');
      return;
    }

    if (permission == CalendarPermissionState.permanentlyDenied ||
        permission == CalendarPermissionState.restricted) {
      state = CalendarAddPermissionRequired(permission);
      return;
    }

    if (permission != CalendarPermissionState.granted) {
      permission = await _service.requestPermission();
    }

    if (permission != CalendarPermissionState.granted) {
      state = CalendarAddPermissionRequired(permission);
      return;
    }

    final result = await _service.addEvent(model);
    if (!mounted) return;

    if (result.success) {
      if (!result.isDuplicate) await _service.markAdded(eventId);
      state = const CalendarAddSuccess('Event added to calendar!');
    } else {
      state = CalendarAddFailure(
        result.error ?? 'Failed to add event to calendar.',
      );
    }
  }

  Future<void> openSettings() => _service.openSettings();

  void resetToIdle() {
    if (state is! CalendarAddSuccess) state = const CalendarAddIdle();
  }
}

final calendarEventProvider =
    StateNotifierProvider.family<
      CalendarEventNotifier,
      CalendarAddState,
      String
    >(
      (ref, eventId) => CalendarEventNotifier(
        eventId: eventId,
        service: ref.watch(calendarServiceProvider),
      ),
    );
