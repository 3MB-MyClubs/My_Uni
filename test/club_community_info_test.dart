import 'package:flutter_application_1/services/app_presence_service.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/club_community_info_controller.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePresenceService extends AppPresenceService {
  Set<String> _users = const {};

  @override
  Set<String> get onlineUserIds => _users;

  void setOnlineUsers(Iterable<String> userIds) {
    _users = Set.unmodifiable(userIds);
    notifyListeners();
  }
}

void main() {
  test('community member label caps totals at 100+', () async {
    await localeService.setLanguage('en');

    expect(S.communityMembers(8), '8 Members');
    expect(S.communityMembers(99), '99 Members');
    expect(S.communityMembers(100), '100+ Members');
    expect(S.communityMembers(243), '100+ Members');
  });

  test('online total includes only unique members of the opened club', () {
    expect(
      onlineClubMemberCount(
        onlineUserIds: const ['member-1', 'member-1', 'not-a-member'],
        memberUserIds: const ['member-1', 'member-2'],
      ),
      1,
    );
  });

  test('club information reacts to presence changes without refresh', () {
    final presence = _FakePresenceService();
    final controller = ClubCommunityInfoController(
      clubId: 'club-1',
      fallbackMemberCount: 42,
      fallbackMemberIds: const ['member-1', 'member-2'],
      presenceService: presence,
    );
    addTearDown(() {
      controller.dispose();
      presence.dispose();
    });

    expect(controller.memberCount, 42);
    expect(controller.onlineCount, 0);

    presence.setOnlineUsers(const ['member-2', 'outsider']);
    expect(controller.onlineCount, 1);

    presence.setOnlineUsers(const ['outsider']);
    expect(controller.onlineCount, 0);
  });
}
