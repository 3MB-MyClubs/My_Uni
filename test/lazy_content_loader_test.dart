import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/lazy_content_loader.dart';

void main() {
  test('deduplicates concurrent loads and reuses fresh content', () async {
    var now = DateTime(2026, 7, 26, 12);
    var contentCalls = 0;
    var countCalls = 0;
    final firstLoad = Completer<void>();

    final loader = LazyContentLoader(
      now: () => now,
      scopeProvider: () => 'user-a',
      cleanupExpiredEvents: () async {},
      contentRefresh: (shouldApply) async {
        contentCalls++;
        if (contentCalls == 1) await firstLoad.future;
        return shouldApply();
      },
      countsRefresh: (shouldApply) async {
        countCalls++;
        return shouldApply();
      },
    );

    final first = loader.ensureContentLoaded();
    final duplicate = loader.ensureContentLoaded();
    expect(identical(first, duplicate), isTrue);
    expect(contentCalls, 1);

    firstLoad.complete();
    await Future.wait([first, duplicate]);
    await Future<void>.delayed(Duration.zero);

    await loader.ensureContentLoaded();
    expect(contentCalls, 1);
    expect(countCalls, 1);

    now = now.add(const Duration(minutes: 3));
    await loader.ensureContentLoaded();
    expect(contentCalls, 2);
  });

  test('account changes reject stale in-flight responses', () async {
    var scope = 'user-a';
    final gates = <Completer<void>>[];
    final appliedScopes = <String>[];

    final loader = LazyContentLoader(
      scopeProvider: () => scope,
      cleanupExpiredEvents: () async {},
      contentRefresh: (shouldApply) async {
        final requestScope = scope;
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        if (shouldApply()) appliedScopes.add(requestScope);
        return shouldApply();
      },
      countsRefresh: (shouldApply) async => shouldApply(),
    );

    final oldRequest = loader.ensureContentLoaded();
    scope = 'user-b';
    final currentRequest = loader.ensureContentLoaded();
    expect(gates, hasLength(2));

    gates[1].complete();
    await currentRequest;
    gates[0].complete();
    await oldRequest;

    expect(appliedScopes, ['user-b']);
    await loader.ensureContentLoaded();
    expect(gates, hasLength(2));
  });

  test(
    'explicit invalidation rejects requests from the old generation',
    () async {
      final gate = Completer<void>();
      var applied = false;

      final loader = LazyContentLoader(
        scopeProvider: () => 'same-user',
        cleanupExpiredEvents: () async {},
        contentRefresh: (shouldApply) async {
          await gate.future;
          applied = shouldApply();
          return applied;
        },
        countsRefresh: (shouldApply) async => shouldApply(),
      );

      final request = loader.ensureContentLoaded();
      loader.invalidate(clearRemoteContent: false);
      gate.complete();
      await request;

      expect(applied, isFalse);
    },
  );
}
