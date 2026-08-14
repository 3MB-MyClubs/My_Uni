import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chat v2 auth boundary persists its empty cache without a timer', () {
    final source = File('lib/services/chat_store.dart').readAsStringSync();
    final start = source.indexOf('void clearChatV2AuthBoundary(');
    final end = source.indexOf(
      'Future<void> _refreshChatV2Summaries()',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final method = source.substring(start, end);
    expect(method, contains('unawaited(saveAll())'));
    expect(method, isNot(contains('scheduleSave()')));
  });
}
