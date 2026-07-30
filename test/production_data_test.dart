import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'clubup-production-data-test-',
    );
    Hive.init(hiveDirectory.path);

    final box = await Hive.openBox<dynamic>('content_v1');
    await box.put('posts', [
      NewsPost(
        id: 'n1',
        clubId: 'c1',
        authorId: 'u1',
        content: 'legacy fixture',
        createdAt: DateTime(2025),
      ).toMap(),
      NewsPost(
        id: 'local-user-post',
        clubId: 'real-club',
        authorId: 'real-user',
        content: 'user content',
        createdAt: DateTime(2026),
      ).toMap(),
    ]);
    await box.put('likes', [
      {'id': 'fixture-like', 'postId': 'n1', 'userId': 'u1'},
    ]);

    await contentStore.initialize();
    contentStore.applyToLists();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  tearDownAll(() async {
    users.clear();
    clubs.clear();
    events.clear();
    newsPosts.clear();
    comments.clear();
    likes.clear();
    shares.clear();
    subscriptions.clear();
    notifications.clear();
    clubAdmins.clear();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('production registries contain no bundled fixtures', () {
    expect(users, isEmpty);
    expect(clubs, isEmpty);
    expect(events, isEmpty);
    expect(comments, isEmpty);
    expect(likes, isEmpty);
    expect(shares, isEmpty);
    expect(subscriptions, isEmpty);
    expect(notifications, isEmpty);
    expect(clubAdmins, isEmpty);
    expect(appAdmin.id, isEmpty);
    expect(userState.remotePhotoUrls, isEmpty);
    expect(userState.remoteClubPhotoUrls, isEmpty);
  });

  test('legacy fixtures are removed without deleting user content', () async {
    expect(newsPosts.map((post) => post.id), ['local-user-post']);

    final box = Hive.box<dynamic>('content_v1');
    expect(box.get('fixtureRemovalVersion'), 1);
    final stored = (box.get('posts') as List).cast<Map>();
    expect(stored.map((post) => post['id']), ['local-user-post']);
  });
}
