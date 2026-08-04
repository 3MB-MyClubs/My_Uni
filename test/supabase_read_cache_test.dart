import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/supabase_read_cache.dart';

void main() {
  test(
    'deduplicates concurrent reads and reuses the result within the TTL',
    () async {
      final cache = SupabaseReadCache();
      final completer = Completer<String>();
      var calls = 0;

      Future<String> fetch() {
        calls++;
        return completer.future;
      }

      final first = cache.getOrFetch<String>(
        key: 'profile:1',
        ttl: const Duration(minutes: 1),
        fetch: fetch,
      );
      final second = cache.getOrFetch<String>(
        key: 'profile:1',
        ttl: const Duration(minutes: 1),
        fetch: fetch,
      );

      expect(calls, 1);
      completer.complete('cached');
      await expectLater(first, completion('cached'));
      await expectLater(second, completion('cached'));

      expect(
        await cache.getOrFetch<String>(
          key: 'profile:1',
          ttl: const Duration(minutes: 1),
          fetch: () async {
            calls++;
            return 'refetched';
          },
        ),
        'cached',
      );
      expect(calls, 1);
    },
  );

  test('invalidating a key forces the next read to fetch again', () async {
    final cache = SupabaseReadCache();
    var calls = 0;

    Future<String> fetch() async {
      calls++;
      return 'value-$calls';
    }

    await cache.getOrFetch<String>(
      key: 'post:1',
      ttl: const Duration(minutes: 1),
      fetch: fetch,
    );
    cache.invalidate('post:1');
    expect(
      await cache.getOrFetch<String>(
        key: 'post:1',
        ttl: const Duration(minutes: 1),
        fetch: fetch,
      ),
      'value-2',
    );
  });
}
