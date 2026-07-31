import 'dart:io';

import 'package:flutter_application_1/models/comment.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/services/comment_store.dart';
import 'package:flutter_application_1/services/content_safety_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/moderation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('comment_store_test_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    // Windows keeps a handle on the box file briefly after close; the temp
    // directory is disposable either way, so a failed cleanup must not fail
    // the suite.
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Left for the OS to reclaim.
    }
  });

  setUp(() {
    comments.clear();
    moderationService.clearActiveUser();
  });

  Comment seed(String id, {String author = 'author-1'}) {
    final comment = Comment(
      id: id,
      postId: 'post-1',
      userId: author,
      content: 'comment $id',
      createdAt: DateTime(2026, 7, 31),
    );
    comments.add(comment);
    return comment;
  }

  test('commentsFor returns this post only, oldest first', () {
    comments.addAll([
      Comment(
        id: 'b',
        postId: 'post-1',
        userId: 'u1',
        content: 'second',
        createdAt: DateTime(2026, 7, 31, 12),
      ),
      Comment(
        id: 'a',
        postId: 'post-1',
        userId: 'u1',
        content: 'first',
        createdAt: DateTime(2026, 7, 31, 10),
      ),
      Comment(
        id: 'c',
        postId: 'post-2',
        userId: 'u1',
        content: 'other post',
        createdAt: DateTime(2026, 7, 31, 11),
      ),
    ]);

    final list = commentStore.commentsFor('post-1');
    expect(list.map((c) => c.id), ['a', 'b']);
  });

  test('reported comments disappear from the list and the badge', () async {
    final reported = seed('c1');
    seed('c2');
    expect(commentStore.countFor('post-1'), 2);

    // No Supabase in tests, so the queued report is a local hide only.
    await moderationService.reportComment(reported, reason: 'spam_or_scam');

    expect(commentStore.commentsFor('post-1').map((c) => c.id), ['c2']);
    expect(commentStore.countFor('post-1'), 1);
    expect(moderationService.isCommentHidden(reported), isTrue);
  });

  test('comments from blocked accounts are filtered out', () async {
    seed('c1', author: 'blocked-user');
    seed('c2', author: 'ok-user');

    await moderationService.blockUser('blocked-user', reason: 'harassment');

    expect(commentStore.commentsFor('post-1').map((c) => c.id), ['c2']);
    expect(commentStore.countFor('post-1'), 1);
  });

  test('unsafe content is rejected before anything is stored', () async {
    final post = NewsPost(
      id: 'post-1',
      clubId: 'club-1',
      authorId: 'author-1',
      content: 'body',
      createdAt: DateTime(2026, 7, 31),
    );

    await expectLater(
      commentStore.add(post: post, content: 'kill yourself'),
      throwsA(isA<ContentSafetyException>()),
    );
    expect(comments, isEmpty);
  });

  test('hydrate is a no-op for seed posts and marks them settled', () async {
    seed('c1');
    // 'post-1' is not a uuid, so there is no server thread to reconcile with
    // and the local comment must survive.
    await commentStore.hydrate('post-1');
    expect(commentStore.commentsFor('post-1').map((c) => c.id), ['c1']);
  });

  test('remove drops the comment and its counted total', () async {
    final comment = seed('c1');
    expect(commentStore.countFor('post-1'), 1);

    // Not a uuid, so the Supabase delete is skipped and cannot throw.
    await commentStore.remove(comment);

    expect(commentStore.commentsFor('post-1'), isEmpty);
    expect(commentStore.countFor('post-1'), 0);
  });

  test('watching a seed post opens no channel', () async {
    // Supabase is not initialised in tests; a uuid post id would throw here if
    // watch() did not screen non-uuid ids out first.
    commentStore.watch('post-1');
    await commentStore.unwatch();
  });

  test('a comment that cannot reach Supabase is not kept locally', () async {
    // Supabase is not initialised here, so the insert cannot succeed. The
    // comment must be reported as undelivered rather than banked on-device.
    final post = NewsPost(
      id: '11111111-2222-3333-4444-555555555555',
      clubId: 'club-1',
      authorId: 'author-1',
      content: 'body',
      createdAt: DateTime(2026, 7, 31),
    );

    await expectLater(
      commentStore.add(post: post, content: 'never lands'),
      throwsA(isA<CommentNotDeliveredException>()),
    );
    expect(comments, isEmpty);
  });

  test('a post with no server row rejects comments outright', () async {
    final post = NewsPost(
      id: 'post-1',
      clubId: 'club-1',
      authorId: 'author-1',
      content: 'body',
      createdAt: DateTime(2026, 7, 31),
    );

    await expectLater(
      commentStore.add(post: post, content: 'nowhere to attach'),
      throwsA(isA<CommentNotDeliveredException>()),
    );
    expect(comments, isEmpty);
  });

  test('blank comments are ignored', () async {
    final post = NewsPost(
      id: 'post-1',
      clubId: 'club-1',
      authorId: 'author-1',
      content: 'body',
      createdAt: DateTime(2026, 7, 31),
    );

    await commentStore.add(post: post, content: '   ');
    expect(comments, isEmpty);
  });
}
