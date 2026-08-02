import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/admin_moderation_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/club_passcode_auth_service.dart';
import 'package:flutter_application_1/services/mock_clubup_profile.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AdminModerationService service;
  late AppAdmin clubUp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    removeClubUpMockProfile();
    clubUp = ensureClubUpMockProfile();
    service = AdminModerationService();
    await service.initialize();
  });

  tearDown(() {
    clubAdmins.removeWhere((admin) => admin.id == 'other-club');
    users.removeWhere((user) => user.id == 'banned-student');
    removeClubUpMockProfile();
  });

  test('reports are visible only to the ClubUp profile', () async {
    await service.recordReport(
      reporterId: 'student-1',
      targetType: 'profile',
      targetId: 'student-2',
      reportedUserId: 'student-2',
      reason: 'harassment',
    );
    final otherAdmin = AppAdmin(
      id: 'other-club',
      name: 'Other Club',
      email: 'other@ku.edu.tr',
      password: '22222222',
    );

    expect(service.reportsFor(clubUp), hasLength(1));
    expect(service.reportsFor(otherAdmin), isEmpty);
    expect(service.reportsFor(null), isEmpty);
  });

  test('only ClubUp can ban and unban profiles', () async {
    final otherAdmin = AppAdmin(
      id: 'other-club',
      name: 'Other Club',
      email: 'other@ku.edu.tr',
      password: '22222222',
    );

    expect(
      await service.banUser(
        actor: otherAdmin,
        userId: 'student-2',
        email: 'student2@ku.edu.tr',
      ),
      isFalse,
    );
    expect(
      await service.isUserBanned(
        userId: 'student-2',
        email: 'student2@ku.edu.tr',
      ),
      isFalse,
    );

    expect(
      await service.banUser(
        actor: clubUp,
        userId: 'student-2',
        email: 'student2@ku.edu.tr',
      ),
      isTrue,
    );
    expect(
      await service.isUserBanned(
        userId: 'student-2',
        email: 'student2@ku.edu.tr',
      ),
      isTrue,
    );
    expect(
      await service.unbanUser(
        actor: otherAdmin,
        userId: 'student-2',
        email: 'student2@ku.edu.tr',
      ),
      isFalse,
    );
  });

  test('banned clubs are rejected by the club passcode login', () async {
    final otherAdmin = AppAdmin(
      id: 'other-club',
      name: 'Other Club',
      email: 'other@ku.edu.tr',
      password: '22222222',
    );
    clubAdmins.add(otherAdmin);
    await service.banClub(
      actor: clubUp,
      clubId: otherAdmin.id,
      email: otherAdmin.email,
    );

    final auth = ClubPasscodeAuthService(
      canUseMockAuth: () => true,
      moderationService: service,
    );
    final result = await auth.login(
      email: otherAdmin.email,
      passcode: otherAdmin.password,
    );

    expect(result.success, isFalse);
    expect(result.errorCode, ClubPasscodeAuthError.banned);
  });

  test('banned profiles are rejected with the banned login result', () async {
    final student = User(
      id: 'banned-student',
      name: 'Banned Student',
      email: 'banned.student@ku.edu.tr',
      password: '135790',
      role: 'student',
      subscribedClubIds: const [],
    );
    users.add(student);
    await service.banUser(
      actor: clubUp,
      userId: student.id,
      email: student.email,
    );
    final auth = AuthService(moderationService: service);

    expect(auth.login(student.email, student.password), isFalse);
    expect(auth.lastLoginFailure, AuthLoginFailure.banned);
  });

  test('ClubUp cannot ban its own profile or club', () async {
    expect(
      await service.banUser(
        actor: clubUp,
        userId: clubUpMockAdminId,
        email: clubUpMockEmail,
      ),
      isFalse,
    );
    expect(
      await service.banClub(
        actor: clubUp,
        clubId: clubUpMockAdminId,
        email: clubUpMockEmail,
      ),
      isFalse,
    );
  });
}
