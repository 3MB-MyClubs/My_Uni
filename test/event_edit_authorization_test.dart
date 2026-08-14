import 'dart:io';

import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/account_switcher_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/club_admin_access.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'event_edit_authorization_',
    );
    Hive.init(tempDir.path);
    await contentStore.initialize();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    accountSwitcherService.clear();
    clubs.clear();
    events.clear();
    users.clear();
    clubAdmins.clear();
  });

  tearDown(() async {
    await contentStore.saveEvents();
    accountSwitcherService.clear();
    await authService.logout();
    clubs.clear();
    events.clear();
    users.clear();
    clubAdmins.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('dedicated club account can apply a saved event edit locally', () {
    final club = _club(id: 'club-dedicated');
    final event = _event(club.id);
    clubs.add(club);
    events.add(event);
    authService.setClubAdmin(
      AppAdmin(
        id: club.id,
        name: club.name,
        email: 'club@ku.edu.tr',
        password: '',
      ),
    );

    expect(currentAccountManagesClubId(club.id), isTrue);
    expect(
      contentStore.updateEventForCurrentAccount(
        _event(club.id, title: 'Edited by dedicated account'),
      ),
      isTrue,
    );
    expect(events.single.title, 'Edited by dedicated account');
  });

  test(
    'selected linked club account is recognized and can apply event edits',
    () async {
      const boardMemberId = 'board-member';
      final club = _club(
        id: 'club-linked',
        boardMemberIds: const [boardMemberId],
      );
      final boardMember = User(
        id: boardMemberId,
        name: 'Board Member',
        email: 'board@ku.edu.tr',
        password: '135790',
        role: 'student',
        subscribedClubIds: const [],
      );
      clubs.add(club);
      events.add(_event(club.id));
      users.add(boardMember);

      expect(
        authService.login(boardMember.email, boardMember.password),
        isTrue,
      );
      await accountSwitcherService.prepare();
      expect(
        await accountSwitcherService.select(SwitchableAccount.club(club: club)),
        isTrue,
      );

      expect(currentAccountManagesClubId(club.id), isTrue);
      expect(
        contentStore.updateEventForCurrentAccount(
          _event(club.id, title: 'Edited by linked account'),
        ),
        isTrue,
      );
      expect(events.single.title, 'Edited by linked account');
    },
  );

  test('an unrelated account still cannot edit another club event', () {
    final club = _club(id: 'club-owner');
    clubs.add(club);
    events.add(_event(club.id));
    authService.setClubAdmin(
      AppAdmin(
        id: 'different-club',
        name: 'Different Club',
        email: 'different@ku.edu.tr',
        password: '',
      ),
    );

    expect(currentAccountManagesClubId(club.id), isFalse);
    expect(
      contentStore.updateEventForCurrentAccount(
        _event(club.id, title: 'Unauthorized edit'),
      ),
      isFalse,
    );
    expect(events.single.title, 'Original event');
  });
}

Club _club({required String id, List<String> boardMemberIds = const []}) {
  return Club(
    id: id,
    name: 'Test Club',
    description: '',
    adminUserIds: const [],
    boardMemberIds: boardMemberIds,
  );
}

Event _event(String clubId, {String title = 'Original event'}) {
  return Event(
    id: 'event-for-$clubId',
    clubId: clubId,
    title: title,
    description: 'Event edit regression fixture',
    dateTime: DateTime(2026, 9, 1, 12),
    endTime: DateTime(2026, 9, 1, 14),
    location: 'Campus',
    attendeeUserIds: const [],
  );
}
