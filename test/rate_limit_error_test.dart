import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/services/rate_limit_error.dart';

void main() {
  test('parses PostgREST retry metadata', () {
    const error = PostgrestException(
      message: 'Too many requests. Try again later.',
      code: 'rate_limit_exceeded',
      details: {'retry_after_seconds': 42, 'action': 'comment_create:actor'},
    );

    final result = RateLimitInfo.from(error);

    expect(result, isNotNull);
    expect(result!.retryAfter, const Duration(seconds: 42));
    expect(result.displayMessage, contains('42 seconds'));
  });

  test('parses Edge Function 429 response bodies', () {
    const error = FunctionException(
      status: 429,
      details: {
        'error': 'rate_limit_exceeded',
        'message': 'Too many requests. Try again later.',
        'retry_after_seconds': 120,
      },
    );

    final result = RateLimitInfo.from(error);

    expect(result, isNotNull);
    expect(result!.retryAfter, const Duration(minutes: 2));
    expect(result.displayMessage, contains('2 minutes'));
  });

  test('does not misclassify ordinary failures', () {
    const error = PostgrestException(
      message: 'Row violates row-level security policy',
      code: '42501',
    );

    expect(RateLimitInfo.from(error), isNull);
  });
}
