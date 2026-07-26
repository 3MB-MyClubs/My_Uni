import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/content_safety_service.dart';

void main() {
  test('rejects clear abusive content before publication', () {
    expect(
      contentSafetyService.rejectionMessage(['You should kill yourself']),
      isNotNull,
    );
  });

  test('allows ordinary campus content', () {
    expect(
      contentSafetyService.rejectionMessage([
        'Join our photography walk on Saturday afternoon.',
      ]),
      isNull,
    );
  });
}
