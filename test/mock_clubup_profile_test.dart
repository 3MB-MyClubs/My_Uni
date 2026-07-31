import 'package:flutter_application_1/services/club_admin_access.dart';
import 'package:flutter_application_1/services/club_passcode_auth_service.dart';
import 'package:flutter_application_1/services/mock_clubup_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    removeClubUpMockProfile();
  });
  tearDown(removeClubUpMockProfile);

  test('registers one ClubUp admin linked to one ClubUp club', () {
    final first = ensureClubUpMockProfile();
    final second = ensureClubUpMockProfile();
    final club = clubUpMockClub;

    expect(identical(first, second), isTrue);
    expect(first.name, 'ClubUp');
    expect(first.email, 'clubup@ku.edu.tr');
    expect(first.password, '11111111');
    expect(club, isNotNull);
    expect(club!.name, 'ClubUp');
    expect(clubIsManagedByAdmin(club, first.id), isTrue);
  });

  test('mock club passcode login accepts the ClubUp credentials', () async {
    final service = ClubPasscodeAuthService(canUseMockAuth: () => true);

    final result = await service.login(
      email: 'CLUBUP@ku.edu.tr',
      passcode: '11111111',
    );

    expect(result.success, isTrue);
    expect(result.admin?.id, clubUpMockAdminId);
    expect(result.admin?.name, 'ClubUp');
  });

  test('invalid mock credentials do not register the fixture', () async {
    final service = ClubPasscodeAuthService(canUseMockAuth: () => true);

    final result = await service.login(
      email: 'clubup@ku.edu.tr',
      passcode: '22222222',
    );

    expect(result.success, isFalse);
    expect(isClubUpMockProfileRegistered, isFalse);
    expect(clubUpMockClub, isNull);
  });
}
