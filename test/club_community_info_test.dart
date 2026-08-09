import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/club_community_info_controller.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('community member label caps totals at 100+', () async {
    await localeService.setLanguage('en');

    expect(S.communityMembers(8), '8 Members');
    expect(S.communityMembers(99), '99 Members');
    expect(S.communityMembers(100), '100+ Members');
    expect(S.communityMembers(243), '100+ Members');
  });

  test('club information starts from the fallback member count', () {
    final controller = ClubCommunityInfoController(
      clubId: 'club-1',
      fallbackMemberCount: 42,
      fallbackMemberIds: const ['member-1', 'member-2'],
    );
    addTearDown(controller.dispose);

    expect(controller.memberCount, 42);
  });
}
