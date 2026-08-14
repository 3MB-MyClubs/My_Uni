import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chat v2 notification opening does not start legacy broad sync', () {
    final source = File(
      'lib/services/notification_navigation.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('startDirectMessageSync(currentUserId)')));
    expect(source, isNot(contains('startClubMessageSync(currentUserId)')));
  });
}
