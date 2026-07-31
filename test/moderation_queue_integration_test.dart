import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/admin_moderation_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_clubup_profile.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/moderation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const reporterId = 'moderation-queue-reporter';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    users.add(
      User(
        id: reporterId,
        name: 'Reporter',
        email: 'reporter@ku.edu.tr',
        password: '135790',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );
    await adminModerationService.initialize(force: true);
  });

  tearDown(() async {
    moderationService.clearActiveUser();
    await authService.logout();
    users.removeWhere((user) => user.id == reporterId);
    removeClubUpMockProfile();
  });

  test('an ordinary user report appears only in the ClubUp queue', () async {
    expect(authService.login('reporter@ku.edu.tr', '135790'), isTrue);
    await moderationService.activateForUser(reporterId);

    await moderationService.reportPost(
      NewsPost(
        id: 'reported-post',
        clubId: 'reported-club',
        authorId: 'reported-profile',
        content: 'Reported content snapshot',
        createdAt: DateTime(2026, 7, 31),
      ),
      reason: 'harassment',
    );

    expect(adminModerationService.reportsFor(null), isEmpty);
    final clubUp = ensureClubUpMockProfile();
    authService.setClubAdmin(clubUp);
    final reports = adminModerationService.reportsFor(authService.currentAdmin);
    expect(reports, hasLength(1));
    expect(reports.single.reporterId, reporterId);
    expect(reports.single.reportedUserId, 'reported-profile');
    expect(reports.single.reportedClubId, 'reported-club');
  });
}
