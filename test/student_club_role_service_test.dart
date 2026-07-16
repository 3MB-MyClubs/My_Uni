import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/services/student_club_role_service.dart';
import 'package:flutter_test/flutter_test.dart';

Club _club(
  String id, {
  List<String>? boardMemberIds,
  Map<String, String>? boardMemberTitles,
}) {
  return Club(
    id: id,
    name: 'Club $id',
    description: 'Test club',
    adminUserIds: const [],
    boardMemberIds: boardMemberIds,
    boardMemberTitles: boardMemberTitles,
  );
}

void main() {
  const studentId = 'student-1';

  test('resolves trimmed custom titles and Board Member fallback', () {
    final customRole = _club(
      'custom',
      boardMemberIds: [studentId],
      boardMemberTitles: {studentId: '  President  '},
    );
    final genericRole = _club(
      'generic',
      boardMemberIds: [studentId],
      boardMemberTitles: {studentId: '   '},
    );
    final ordinary = _club(
      'ordinary',
      boardMemberTitles: {studentId: 'Ignored title'},
    );

    final service = StudentClubRoleService();

    expect(service.roleTitleFor(customRole, studentId), 'President');
    expect(service.roleTitleFor(genericRole, studentId), 'Board Member');
    expect(service.roleTitleFor(ordinary, studentId), isNull);
  });

  test('pins every role club before followed clubs without duplicates', () {
    final followedA = _club('followed-a');
    final roleA = _club(
      'role-a',
      boardMemberIds: [studentId],
      boardMemberTitles: {studentId: 'President'},
    );
    final followedB = _club('followed-b');
    final roleOnly = _club(
      'role-only',
      boardMemberIds: [studentId],
      boardMemberTitles: {studentId: 'Treasurer'},
    );

    final ordered = StudentClubRoleService().orderedProfileClubs(
      userId: studentId,
      followedClubIds: [followedA.id, roleA.id, followedB.id, followedA.id],
      allClubs: [followedA, roleA, followedB, roleOnly, roleA],
    );

    expect(ordered.map((club) => club.id), [
      'role-a',
      'role-only',
      'followed-a',
      'followed-b',
    ]);
  });

  test('clearing a role restores followed order or removes the club', () {
    final ordinary = _club('ordinary');
    final roleClub = _club(
      'role',
      boardMemberIds: [studentId],
      boardMemberTitles: {studentId: 'Secretary'},
    );
    final service = StudentClubRoleService();

    expect(
      service
          .orderedProfileClubs(
            userId: studentId,
            followedClubIds: [ordinary.id, roleClub.id],
            allClubs: [ordinary, roleClub],
          )
          .map((club) => club.id),
      ['role', 'ordinary'],
    );

    roleClub.boardMemberIds.remove(studentId);
    roleClub.boardMemberTitles.remove(studentId);

    expect(
      service
          .orderedProfileClubs(
            userId: studentId,
            followedClubIds: [ordinary.id, roleClub.id],
            allClubs: [ordinary, roleClub],
          )
          .map((club) => club.id),
      ['ordinary', 'role'],
    );
    expect(
      service
          .orderedProfileClubs(
            userId: studentId,
            followedClubIds: [ordinary.id],
            allClubs: [ordinary, roleClub],
          )
          .map((club) => club.id),
      ['ordinary'],
    );
  });

  test(
    'role mutations persist both maps and notify profile listeners',
    () async {
      final club = _club('role-club');
      var setCalls = 0;
      var removeCalls = 0;
      var idSaves = 0;
      var titleSaves = 0;
      var notifications = 0;
      String? remoteTitle;
      final service = StudentClubRoleService(
        setRemoteBoardRole:
            ({required club, required userId, String? title}) async {
              setCalls++;
              remoteTitle = title;
            },
        removeRemoteBoardRole: ({required club, required userId}) async {
          removeCalls++;
        },
        saveBoardMemberIds: () async => idSaves++,
        saveBoardMemberTitles: () async => titleSaves++,
        notifyProfiles: () => notifications++,
      );

      await service.setBoardMembership(
        club: club,
        userId: studentId,
        isBoardMember: true,
        title: '  President  ',
      );

      expect(setCalls, 1);
      expect(remoteTitle, 'President');
      expect(club.boardMemberIds, contains(studentId));
      expect(club.boardMemberTitles[studentId], 'President');
      expect(idSaves, 1);
      expect(titleSaves, 1);
      expect(notifications, 1);

      await service.setBoardMembership(
        club: club,
        userId: studentId,
        isBoardMember: false,
      );

      expect(removeCalls, 1);
      expect(club.boardMemberIds, isNot(contains(studentId)));
      expect(club.boardMemberTitles, isNot(contains(studentId)));
      expect(idSaves, 2);
      expect(titleSaves, 2);
      expect(notifications, 2);
    },
  );

  test('failed remote update does not commit a local role', () async {
    final club = _club('failed-role');
    var saves = 0;
    var notifications = 0;
    final service = StudentClubRoleService(
      setRemoteBoardRole:
          ({required club, required userId, String? title}) async {
            throw StateError('server rejected update');
          },
      removeRemoteBoardRole: ({required club, required userId}) async {},
      saveBoardMemberIds: () async => saves++,
      saveBoardMemberTitles: () async => saves++,
      notifyProfiles: () => notifications++,
    );

    await expectLater(
      service.setBoardMembership(
        club: club,
        userId: studentId,
        isBoardMember: true,
        title: 'President',
      ),
      throwsStateError,
    );

    expect(club.boardMemberIds, isEmpty);
    expect(club.boardMemberTitles, isEmpty);
    expect(saves, 0);
    expect(notifications, 0);
  });
}
