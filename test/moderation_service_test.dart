import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/moderation_service.dart';

void main() {
  test(
    'reported posts are hidden immediately and persist for the account',
    () async {
      SharedPreferences.setMockInitialValues({});
      authService.login('alice@ku.edu.tr');
      final userId = authService.currentUser!.id;
      await moderationService.activateForUser(userId);

      final post = NewsPost(
        id: 'local-objectionable-post',
        clubId: 'c1',
        authorId: 'u4',
        content: 'Content submitted for moderation',
        createdAt: DateTime(2026, 7, 18),
      );

      await moderationService.reportPost(post, reason: 'harassment');
      expect(moderationService.isPostHidden(post), isTrue);

      moderationService.clearActiveUser();
      expect(moderationService.isPostHidden(post), isFalse);
      await moderationService.activateForUser(userId);
      expect(moderationService.isPostHidden(post), isTrue);
    },
  );

  test('blocking a user hides posts authored by that user', () async {
    SharedPreferences.setMockInitialValues({});
    authService.login('alice@ku.edu.tr');
    final userId = authService.currentUser!.id;
    await moderationService.activateForUser(userId);

    await moderationService.blockUser('u4', reason: 'harassment');

    final post = NewsPost(
      id: 'another-local-post',
      clubId: 'c1',
      authorId: 'u4',
      content: 'Blocked author content',
      createdAt: DateTime(2026, 7, 18),
    );
    expect(moderationService.isUserBlocked('u4'), isTrue);
    expect(moderationService.isPostHidden(post), isTrue);
  });
}
