import '../models/event.dart';
import '../models/club.dart';
import 'auth_service.dart';
import 'mock_data.dart';

bool canViewEventAttendance(Event event) {
  final admin = authService.currentAdmin;
  if (admin == null) return false;

  if (event.createdByUserId != null) {
    return event.createdByUserId == admin.id;
  }

  final club = clubs.cast<Club?>().firstWhere(
    (candidate) => candidate?.id == event.clubId,
    orElse: () => null,
  );
  return club?.adminUserIds.contains(admin.id) ?? false;
}
