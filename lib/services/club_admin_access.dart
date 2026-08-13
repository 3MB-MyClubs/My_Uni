import '../models/club.dart';
import 'account_switcher_service.dart';
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

/// True when the account currently represented by the UI can manage [clubId].
///
/// Dedicated club logins expose the club through [currentAdmin], while linked
/// board-member accounts keep a student auth session and expose the selected
/// club through [accountSwitcherService]. Keep those two representations in
/// one predicate so event screens and local content checks cannot disagree.
bool currentAccountManagesClubId(String clubId) {
  if (currentAdminOwnsClubId(clubId)) return true;
  return accountSwitcherService.activeClub?.id == clubId;
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
