enum CalendarPermissionState {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

sealed class CalendarAddState {
  const CalendarAddState();
}

final class CalendarAddIdle extends CalendarAddState {
  const CalendarAddIdle();
}

final class CalendarAddLoading extends CalendarAddState {
  const CalendarAddLoading();
}

final class CalendarAddSuccess extends CalendarAddState {
  final String message;
  const CalendarAddSuccess(this.message);
}

final class CalendarAddFailure extends CalendarAddState {
  final String error;
  const CalendarAddFailure(this.error);
}

final class CalendarAddPermissionRequired extends CalendarAddState {
  final CalendarPermissionState permission;
  const CalendarAddPermissionRequired(this.permission);
}
