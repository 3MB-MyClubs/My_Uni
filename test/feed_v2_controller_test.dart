import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/feed_v2.dart';
import 'package:flutter_application_1/services/feed_v2_controller.dart';
import 'package:flutter_application_1/services/feed_v2_service.dart';

void main() {
  test('loads first, second, and final pages without duplicates', () async {
    final timestamp = DateTime.utc(2026, 8, 12, 9);
    final source = _FakeSource((cursor, _, _, _) async {
      if (cursor == null) {
        return _page([
          _post('c', timestamp),
          _post('b', timestamp),
        ], next: FeedCursorV2(createdAt: timestamp, id: 'b'));
      }
      return _page([
        _post('b', timestamp), // Defensive de-duplication at the boundary.
        _post('a', timestamp.subtract(const Duration(seconds: 1))),
      ]);
    });
    final controller = FeedV2Controller(source: source, pageSize: 2);

    await controller.loadFirstPage();
    expect(controller.items.map((item) => item.id), ['c', 'b']);
    expect(controller.hasMore, isTrue);

    await controller.loadNextPage();
    expect(controller.items.map((item) => item.id), ['c', 'b', 'a']);
    expect(controller.hasMore, isFalse);
    expect(source.cursors, [null, 'b']);
  });

  test('empty first page reaches end-of-feed state', () async {
    final controller = FeedV2Controller(
      source: _FakeSource((_, _, _, _) async => _page(const [])),
    );

    await controller.loadFirstPage();

    expect(controller.hasLoadedFirstPage, isTrue);
    expect(controller.items, isEmpty);
    expect(controller.hasMore, isFalse);
    expect(controller.initialError, isNull);
  });

  test('suppresses simultaneous next-page requests', () async {
    final gate = Completer<FeedPageV2>();
    var calls = 0;
    final timestamp = DateTime.utc(2026, 8, 12, 9);
    final source = _FakeSource((cursor, _, _, _) {
      calls++;
      if (cursor == null) {
        return Future.value(
          _page([
            _post('b', timestamp),
          ], next: FeedCursorV2(createdAt: timestamp, id: 'b')),
        );
      }
      return gate.future;
    });
    final controller = FeedV2Controller(source: source);
    await controller.loadFirstPage();

    final first = controller.loadNextPage();
    final duplicate = controller.loadNextPage();
    expect(identical(first, duplicate), isTrue);
    expect(calls, 2);

    gate.complete(
      _page([_post('a', timestamp.subtract(const Duration(microseconds: 1)))]),
    );
    await Future.wait([first, duplicate]);
    expect(calls, 2);
  });

  test('refresh resets the cursor chain and replaces loaded history', () async {
    final timestamp = DateTime.utc(2026, 8, 12, 9);
    var firstPageCalls = 0;
    final source = _FakeSource((cursor, _, _, force) async {
      if (cursor == null) {
        firstPageCalls++;
        if (firstPageCalls == 1) {
          return _page([
            _post('b', timestamp),
          ], next: FeedCursorV2(createdAt: timestamp, id: 'b'));
        }
        expect(force, isTrue);
        return _page([_post('new', timestamp.add(const Duration(minutes: 1)))]);
      }
      return _page([
        _post('a', timestamp.subtract(const Duration(minutes: 1))),
      ]);
    });
    final controller = FeedV2Controller(source: source);

    await controller.loadFirstPage();
    await controller.loadNextPage();
    expect(controller.items.map((item) => item.id), ['b', 'a']);

    await controller.refresh();
    expect(controller.items.map((item) => item.id), ['new']);
    expect(controller.hasMore, isFalse);
    expect(source.cursors, [null, 'b', null]);
  });

  test('page failure is retryable with the same cursor', () async {
    final timestamp = DateTime.utc(2026, 8, 12, 9);
    var nextAttempts = 0;
    final source = _FakeSource((cursor, _, _, _) async {
      if (cursor == null) {
        return _page([
          _post('b', timestamp),
        ], next: FeedCursorV2(createdAt: timestamp, id: 'b'));
      }
      nextAttempts++;
      if (nextAttempts == 1) throw StateError('temporary page failure');
      return _page([
        _post('a', timestamp.subtract(const Duration(seconds: 1))),
      ]);
    });
    final controller = FeedV2Controller(source: source);
    await controller.loadFirstPage();

    await controller.loadNextPage();
    expect(controller.pageError, isA<StateError>());
    expect(controller.items.map((item) => item.id), ['b']);

    await controller.retry();
    expect(controller.pageError, isNull);
    expect(controller.items.map((item) => item.id), ['b', 'a']);
    expect(nextAttempts, 2);
  });

  test('a stale next-page response cannot append after refresh', () async {
    final timestamp = DateTime.utc(2026, 8, 12, 9);
    final staleNext = Completer<FeedPageV2>();
    var firstPageCalls = 0;
    final source = _FakeSource((cursor, _, _, _) {
      if (cursor != null) return staleNext.future;
      firstPageCalls++;
      return Future.value(
        firstPageCalls == 1
            ? _page([
                _post('old', timestamp),
              ], next: FeedCursorV2(createdAt: timestamp, id: 'old'))
            : _page([_post('new', timestamp.add(const Duration(minutes: 1)))]),
      );
    });
    final controller = FeedV2Controller(source: source);

    await controller.loadFirstPage();
    final oldChain = controller.loadNextPage();
    await controller.refresh();
    staleNext.complete(
      _page([_post('stale', timestamp.subtract(const Duration(minutes: 1)))]),
    );
    await oldChain;

    expect(controller.items.map((item) => item.id), ['new']);
    expect(controller.hasMore, isFalse);
  });

  test(
    'targeted deletion removes an item without resetting pagination',
    () async {
      final timestamp = DateTime.utc(2026, 8, 12, 9);
      final controller = FeedV2Controller(
        source: _FakeSource(
          (_, _, _, _) async => _page([
            _post('b', timestamp),
            _post('a', timestamp),
          ], next: FeedCursorV2(createdAt: timestamp, id: 'a')),
        ),
      );
      await controller.loadFirstPage();
      final revision = controller.dataRevision;

      controller.removeItems(const ['b']);

      expect(controller.items.map((item) => item.id), ['a']);
      expect(controller.hasMore, isTrue);
      expect(controller.dataRevision, revision + 1);
    },
  );

  test('typed DTO parses aggregates and contains no email contract', () {
    final json = <String, dynamic>{
      'version': 2,
      'page_size': 25,
      'has_more': false,
      'next_cursor': null,
      'items': [
        {
          'id': 'post',
          'type': 'post',
          'created_at': '2026-08-12T09:00:00Z',
          'content': 'Hello',
          'club': {'id': 'club', 'name': 'Club'},
          'author': {'id': 'author', 'name': 'Author', 'role': 'student'},
          'engagement': {
            'like_count': 4,
            'comment_count': 3,
            'view_count': 9,
            'viewer_has_liked': true,
          },
          'viewer': {'follows_club': true},
          'poll': {
            'id': 'poll',
            'question': 'Choose',
            'options': ['A', 'B'],
            'option_counts': {'0': 2, '1': 1},
            'total_votes': 3,
            'viewer_option_index': 1,
          },
        },
      ],
      'upcoming_events': const [],
      'suggested_people': const [],
      'suggested_clubs': const [],
    };

    final page = FeedPageV2.fromJson(json);

    expect(page.items.single.engagement.likeCount, 4);
    expect(page.items.single.poll!.optionCounts, [2, 1]);
    expect(page.items.single.poll!.viewerOptionIndex, 1);
    expect(_containsKeyRecursively(json, 'email'), isFalse);
  });
}

class _FakeSource implements FeedPageV2Source {
  _FakeSource(this.handler);

  final Future<FeedPageV2> Function(
    FeedCursorV2? cursor,
    int limit,
    bool followedOnly,
    bool force,
  )
  handler;
  final List<String?> cursors = [];

  @override
  Future<FeedPageV2> fetchPage({
    FeedCursorV2? cursor,
    int limit = 25,
    bool followedOnly = false,
    bool force = false,
  }) {
    cursors.add(cursor?.id);
    return handler(cursor, limit, followedOnly, force);
  }
}

FeedPageV2 _page(List<FeedPostV2> items, {FeedCursorV2? next}) => FeedPageV2(
  items: items,
  nextCursor: next,
  hasMore: next != null,
  pageSize: 25,
);

FeedPostV2 _post(String id, DateTime createdAt) => FeedPostV2(
  id: id,
  createdAt: createdAt,
  content: id,
  isAnnouncement: false,
  club: const FeedClubV2(id: 'club', name: 'Club', description: ''),
  engagement: const FeedEngagementV2(
    likeCount: 0,
    commentCount: 0,
    viewCount: 0,
    viewerHasLiked: false,
  ),
  viewerFollowsClub: false,
);

bool _containsKeyRecursively(Object? value, String key) {
  if (value is Map) {
    if (value.keys.any((candidate) => candidate.toString() == key)) return true;
    return value.values.any((item) => _containsKeyRecursively(item, key));
  }
  if (value is List) {
    return value.any((item) => _containsKeyRecursively(item, key));
  }
  return false;
}
