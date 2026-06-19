import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/news_post.dart';

void main() {
  test('serializes tagged clubs and tagged students', () {
    final post = NewsPost(
      id: 'p1',
      clubId: 'c1',
      authorId: 'a1',
      content: '@Computer Club hello @Alice',
      createdAt: DateTime(2026, 1, 1),
      taggedClubIds: const ['c2'],
      taggedUserIds: const ['u1'],
    );

    final restored = NewsPost.fromMap(post.toMap());

    expect(restored.taggedClubIds, ['c2']);
    expect(restored.taggedUserIds, ['u1']);
  });
}
