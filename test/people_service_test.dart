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
  group('mutual followers', () {
    test('indexes people I follow who also follow each suggestion', () {
      final service = PeopleService();

      service.replaceMutualFollowersForSuggestions(
        currentUserFollowingIds: const ['mutual-1', 'mutual-2'],
        suggestedUserIds: const ['suggestion-1', 'suggestion-2'],
        edges: const [
          (followerId: 'mutual-1', followingId: 'suggestion-1'),
          (followerId: 'mutual-2', followingId: 'suggestion-1'),
          (followerId: 'mutual-1', followingId: 'suggestion-2'),
          // The reverse edge is a shared-following relationship, not a
          // mutual follower for suggestion-1.
          (followerId: 'suggestion-1', followingId: 'mutual-1'),
          // An unknown person's follow must not become social proof.
          (followerId: 'stranger', followingId: 'suggestion-1'),
        ],
      );

      expect(service.mutualFollowerIdsFor('suggestion-1'), {
        'mutual-1',
        'mutual-2',
      });
      expect(service.mutualFollowerIdsFor('suggestion-2'), {'mutual-1'});
      expect(service.mutualFollowerIdsFor('not-suggested'), isEmpty);
    });

    test('replaces stale mutual-follower snapshots on refresh', () {
      final service = PeopleService();
      service.replaceMutualFollowersForSuggestions(
        currentUserFollowingIds: const ['mutual'],
        suggestedUserIds: const ['old-suggestion'],
        edges: const [(followerId: 'mutual', followingId: 'old-suggestion')],
      );

      service.replaceMutualFollowersForSuggestions(
        currentUserFollowingIds: const ['mutual'],
        suggestedUserIds: const ['new-suggestion'],
        edges: const [(followerId: 'mutual', followingId: 'new-suggestion')],
      );

      expect(service.mutualFollowerIdsFor('old-suggestion'), isEmpty);
      expect(service.mutualFollowerIdsFor('new-suggestion'), {'mutual'});
    });
  });

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
