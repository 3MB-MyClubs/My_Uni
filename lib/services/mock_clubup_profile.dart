import '../models/app_admin.dart';
import '../models/club.dart';
import 'mock_data.dart';

/// Development-only ClubUp club-admin fixture.
///
/// The fixture is registered lazily after the mock-auth gate has passed, so
/// production startup still contains no bundled users, clubs, or sessions.
const String clubUpMockAdminId = 'mock-clubup';
const String clubUpMockEmail = 'clubup@ku.edu.tr';
const String clubUpMockPasscode = '11111111';

AppAdmin _newClubUpMockAdmin() => AppAdmin(
  id: clubUpMockAdminId,
  name: 'ClubUp',
  email: clubUpMockEmail,
  password: clubUpMockPasscode,
);

Club _newClubUpMockClub() => Club(
  id: clubUpMockAdminId,
  name: 'ClubUp',
  shortName: 'ClubUp',
  description: "ClubUp's mock club administration profile.",
  categoryName: 'Tech',
  email: clubUpMockEmail,
  adminUserIds: const [clubUpMockAdminId],
);

bool isClubUpMockAdmin(AppAdmin? admin) => admin?.id == clubUpMockAdminId;

bool get isClubUpMockProfileRegistered => clubAdmins.any(isClubUpMockAdmin);

Club? get clubUpMockClub {
  for (final club in clubs) {
    if (club.id == clubUpMockAdminId) return club;
  }
  return null;
}

/// Adds the fixture once and returns the registered admin identity.
AppAdmin ensureClubUpMockProfile() {
  AppAdmin? admin;
  for (final candidate in clubAdmins) {
    if (isClubUpMockAdmin(candidate)) {
      admin = candidate;
      break;
    }
  }
  admin ??= _newClubUpMockAdmin();
  if (!clubAdmins.contains(admin)) clubAdmins.add(admin);

  if (clubUpMockClub == null) clubs.add(_newClubUpMockClub());
  return admin;
}

/// Removes only the development fixture, leaving fetched/user content intact.
void removeClubUpMockProfile() {
  clubAdmins.removeWhere(isClubUpMockAdmin);
  clubs.removeWhere((club) => club.id == clubUpMockAdminId);
}
