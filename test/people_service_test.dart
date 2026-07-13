import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_test/flutter_test.dart';

User _student(String id, String name) {
  return User(
    id: id,
    name: name,
    email: '$id@ku.edu.tr',
    password: '',
    role: 'student',
    subscribedClubIds: const [],
  );
}

void main() {
  group('club member reconciliation', () {
    final currentStudent = _student('current', 'Current Student');
    final pastMember = _student('past', 'Past Member');

    test('keeps a new follower visible when the remote list is stale', () {
      final members = PeopleService().reconcileCurrentClubMember(
        fetchedMembers: [pastMember],
        fallbackMembers: [pastMember, currentStudent],
        currentUser: currentStudent,
        currentUserIsFollowing: true,
      );

      expect(
        members.map((member) => member.id),
        containsAll(['past', 'current']),
      );
      expect(
        members.where((member) => member.id == currentStudent.id),
        hasLength(1),
      );
    });

    test('removes an unfollower returned by a stale remote list', () {
      final members = PeopleService().reconcileCurrentClubMember(
        fetchedMembers: [pastMember, currentStudent],
        fallbackMembers: [pastMember],
        currentUser: currentStudent,
        currentUserIsFollowing: false,
      );

      expect(members.map((member) => member.id), ['past']);
    });

    test('uses local members when the remote list is unavailable', () {
      final members = PeopleService().reconcileCurrentClubMember(
        fetchedMembers: const [],
        fallbackMembers: [pastMember, currentStudent],
        currentUser: currentStudent,
        currentUserIsFollowing: true,
      );

      expect(members.map((member) => member.id), ['past', 'current']);
    });
  });
}
