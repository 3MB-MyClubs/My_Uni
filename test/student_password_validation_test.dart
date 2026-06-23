import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/auth_service.dart';

void main() {
  group('student password validation', () {
    test('accepts exactly six non-adjacent numeric digits', () {
      expect(authService.isValidStudentPassword('135790'), isTrue);
    });

    test('rejects adjacent repeated digits', () {
      expect(authService.isValidStudentPassword('113579'), isFalse);
      expect(authService.isValidStudentPassword('135779'), isFalse);
    });

    test('rejects adjacent sequential digits in either direction', () {
      expect(authService.isValidStudentPassword('123579'), isFalse);
      expect(authService.isValidStudentPassword('975310'), isFalse);
    });

    test('still rejects non-numeric or non-six-digit values', () {
      expect(authService.isValidStudentPassword('13579'), isFalse);
      expect(authService.isValidStudentPassword('13579a'), isFalse);
    });
  });
}
