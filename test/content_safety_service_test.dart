import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/content_safety_service.dart';

void main() {
  test('rejects clear abusive content before publication', () {
    expect(
      contentSafetyService.isRejected(['You should kill yourself']),
      isTrue,
    );
  });

  test('allows ordinary campus content', () {
    expect(
      contentSafetyService.isRejected([
        'Join our photography walk on Saturday afternoon.',
      ]),
      isFalse,
    );
  });
}
