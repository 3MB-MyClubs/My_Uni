import 'dart:async';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/services/app_bootstrap.dart';
import 'package:flutter_application_1/services/paged_controller.dart';
import 'package:flutter_application_1/services/performance_metrics.dart';
import 'package:flutter_application_1/services/supabase_read_cache.dart';
import 'package:flutter_application_1/services/work_scheduler.dart';

void main() {
  test(
    'partial directory rows preserve known memberships and follow graph',
    () {
      final people = PeopleService();
      people.seedChatParticipants([
        User(
          id: 'member',
          name: 'Old',
          email: '',
          password: '',
          role: 'student',
          subscribedClubIds: ['club-a'],
          followingUserIds: ['friend'],
        ),
      ]);
      final result = people.mergeDirectoryRows([
        {'id': 'member', 'full_name': 'Updated'},
      ], clubId: 'club-b').single;
      expect(result.name, 'Updated');
      expect(result.subscribedClubIds, ['club-a', 'club-b']);
      expect(result.followingUserIds, ['friend']);
    },
  );

  testWidgets('chat account reset does not leave a persistence timer', (
    tester,
  ) async {
    chatStore.clearChatV2AuthBoundary();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test(
    'cache evicts least recently read values and exposes stale data synchronously',
    () async {
      var now = DateTime(2026);
      final cache = SupabaseReadCache(maxEntries: 2, now: () => now);
      Future<void> put(String key) async => cache.getOrFetch<String>(
        key: key,
        ttl: const Duration(seconds: 10),
        fetch: () async => key,
      );
      await put('a');
      await put('b');
      expect(cache.peek<String>('a'), 'a');
      await put('c');
      expect(cache.entryCount, 2);
      expect(cache.peek<String>('b'), isNull);
      now = now.add(const Duration(seconds: 11));
      expect(cache.peek<String>('a'), 'a');
      expect(cache.isFresh('a', const Duration(seconds: 10)), isFalse);
    },
  );

  test(
    'out-of-order invalidated requests cannot resurrect data after newer completion',
    () async {
      final cache = SupabaseReadCache();
      final old = Completer<String>();
      final first = cache.getOrFetch<String>(
        key: 'x',
        ttl: const Duration(minutes: 1),
        fetch: () => old.future,
      );
      cache.invalidate('x');
      await cache.getOrFetch<String>(
        key: 'x',
        ttl: const Duration(minutes: 1),
        fetch: () async => 'new',
      );
      old.complete('old');
      await first;
      expect(cache.peek<String>('x'), 'new');
      cache.clear();
      expect(cache.peek<String>('x'), isNull);
    },
  );

  test('failed refresh preserves last successful cached value', () async {
    final cache = SupabaseReadCache();
    await cache.getOrFetch<String>(
      key: 'x',
      ttl: Duration.zero,
      fetch: () async => 'cached',
    );
    await expectLater(
      cache.getOrFetch<String>(
        key: 'x',
        ttl: Duration.zero,
        fetch: () async => throw StateError('offline'),
      ),
      throwsStateError,
    );
    expect(cache.peek<String>('x'), 'cached');
  });

  test(
    'feature readiness does not wait for an unrelated hung feature',
    () async {
      final bootstrap = AppBootstrap();
      final optional = Completer<void>();
      final slow = bootstrap.start('calendar', () => optional.future);
      await bootstrap.start('chat', () async {});
      expect(await bootstrap.readyFor(['chat']), isTrue);
      expect(bootstrap.isReady('calendar'), isFalse);
      optional.complete();
      await slow;
      await bootstrap.start('failed', () async => throw StateError('storage'));
      expect(await bootstrap.readyFor(['failed']), isFalse);
      expect(await bootstrap.readyFor(['chat']), isTrue);
    },
  );

  test(
    'paging rejects stale searches and coalesces load-more requests',
    () async {
      final controller = PagedController<String>(idOf: (value) => value);
      final old = Completer<CursorPage<String>>();
      final first = controller.load((_) => old.future);
      final next = Completer<CursorPage<String>>();
      var calls = 0;
      await controller.load((cursor) async {
        calls++;
        if (cursor == null) {
          return const CursorPage(items: ['new'], nextCursor: {'id': 'new'});
        }
        return next.future;
      });
      final second = controller.loadMore();
      final duplicate = controller.loadMore();
      expect(calls, 2);
      next.complete(const CursorPage(items: ['new', 'older']));
      await Future.wait([second, duplicate]);
      old.complete(const CursorPage(items: ['stale']));
      await first;
      expect(controller.items, ['new', 'older']);
      expect(controller.hasMore, isFalse);
      controller.dispose();
    },
  );

  testWidgets('250ms search debounce only requests the final query', (
    tester,
  ) async {
    final controller = PagedController<String>(idOf: (value) => value);
    var calls = 0;
    Future<CursorPage<String>> fetch(Map<String, dynamic>? _) async {
      calls++;
      return const CursorPage(items: ['last']);
    }

    controller.load(fetch, debounce: const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 100));
    controller.load(fetch, debounce: const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 249));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 1);
    expect(controller.items, ['last']);
    controller.dispose();
  });

  test(
    'refresh keeps cached rows visible and reset rejects a late response',
    () async {
      final controller = PagedController<String>(idOf: (value) => value);
      final response = Completer<CursorPage<String>>();
      final task = controller.load(
        (_) => response.future,
        cached: const CursorPage(items: ['cached']),
      );
      expect(controller.items, ['cached']);
      expect(controller.loading, isTrue);
      controller.reset();
      response.complete(const CursorPage(items: ['old-account']));
      await task;
      expect(controller.items, isEmpty);
      controller.dispose();
    },
  );

  test('refresh coalesces bursts but retains a trailing refresh', () async {
    final scheduler = CoalescingRefresh();
    final first = Completer<void>();
    var calls = 0;
    Future<void> refresh() async {
      calls++;
      if (calls == 1) await first.future;
    }

    final task = scheduler.run(refresh);
    await Future<void>.delayed(Duration.zero);
    scheduler.run(refresh);
    scheduler.run(refresh);
    scheduler.run(refresh);
    first.complete();
    await task;
    expect(calls, 2);
  });

  test('reconciliation never exceeds three concurrent requests', () async {
    var active = 0;
    var peak = 0;
    var completed = 0;
    await runWithConcurrency(List.generate(12, (i) => i), (int _) async {
      active++;
      if (active > peak) peak = active;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      active--;
      completed++;
    });
    expect(peak, 3);
    expect(completed, 12);
  });

  test(
    'HTTP metrics count bytes and do not retain secrets or query values',
    () async {
      final metrics = PerformanceMetrics(enabled: true, capacity: 2);
      final client = MeasuredHttpClient(
        MockClient((_) async => http.Response('hello', 200)),
        metrics: metrics,
      );
      await client.get(
        Uri.parse('https://example.test/rest/v1/rpc/search?p_query=secret'),
        headers: {'Authorization': 'secret-token'},
      );
      final output = metrics.snapshot();
      expect((output['counters'] as Map)['rpc.search.bytes'], 5);
      expect(output.toString(), isNot(contains('secret')));
      metrics.record('one', Duration.zero);
      metrics.record('two', Duration.zero);
      expect((metrics.snapshot()['samples'] as List).length, 2);
      client.close();
    },
  );
}
