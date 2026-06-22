import '../models/club.dart';
import 'auth_service.dart';
import 'mock_data.dart';

bool clubIsManagedByAdmin(Club club, String adminId) {
  if (adminId.isEmpty) return false;
  return club.id == adminId || club.adminUserIds.contains(adminId);
}

bool isCurrentAdminForClub(Club club) {
  final adminId = authService.currentAdmin?.id ?? '';
  return clubIsManagedByAdmin(club, adminId);
}

Club? managedClubForAdmin(String adminId) {
  if (adminId.isEmpty || adminId == appAdmin.id) return null;
  for (final club in clubs) {
    if (clubIsManagedByAdmin(club, adminId)) return club;
  }
  return null;
}
