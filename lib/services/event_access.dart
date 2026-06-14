import '../models/event.dart';
import 'auth_service.dart';

bool canViewEventAttendance(Event event) {
  final admin = authService.currentAdmin;
  return admin != null &&
      event.createdByUserId != null &&
      event.createdByUserId == admin.id;
}
