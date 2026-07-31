import '../models/club.dart';
import 'auth_service.dart';
import 'mock_data.dart';
import 'mock_clubup_profile.dart';

bool clubIsManagedByAdmin(Club club, String adminId) {
  if (adminId.isEmpty) return false;
  return club.id == adminId || club.adminUserIds.contains(adminId);
}

bool isCurrentAdminForClub(Club club) {
  final adminId = authService.currentAdmin?.id ?? '';
  return clubIsManagedByAdmin(club, adminId);
}

/// True when the logged-in club admin manages the club with [clubId].
/// Used for club-only admin views and analytics controls.
bool currentAdminOwnsClubId(String clubId) {
  final adminId = authService.currentAdmin?.id ?? '';
  if (adminId.isEmpty) return false;
  return clubs.any((c) => c.id == clubId && clubIsManagedByAdmin(c, adminId));
}

Club? managedClubForAdmin(String adminId) {
  if (adminId.isEmpty ||
      adminId == appAdmin.id ||
      (authService.currentAdmin?.id == adminId &&
          isClubUpAdmin(authService.currentAdmin))) {
    return null;
  }
  for (final club in clubs) {
    if (clubIsManagedByAdmin(club, adminId)) return club;
  }
  return null;
}
