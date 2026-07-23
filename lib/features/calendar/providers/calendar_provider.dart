import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/locale_service.dart';
import '../data/calendar_event_model.dart';
import '../services/calendar_service.dart';
import 'calendar_state.dart';

// No BuildContext is available this deep in the provider layer; these
// fallbacks are resolved here via the current locale rather than pushed up
// to a caller that may not exist yet.
AppLocalizations get _l10n =>
    lookupAppLocalizations(Locale(localeService.languageCode));

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
          ? CalendarAddSuccess(_l10n.calendarAlreadyAdded)
          : const CalendarAddIdle();
    }
  }

  Future<void> add(CalendarEventModel model) async {
    if (state is CalendarAddLoading || state is CalendarAddSuccess) return;
    state = const CalendarAddLoading();

    var permission = await _service.checkPermission();

    if (permission == CalendarPermissionState.unknown) {
      state = CalendarAddFailure(_l10n.calendarPermissionCheckFailed);
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
      state = CalendarAddSuccess(_l10n.calendarAddedSuccess);
    } else {
      state = CalendarAddFailure(
        result.error ?? _l10n.calendarAddFailedGeneric,
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
