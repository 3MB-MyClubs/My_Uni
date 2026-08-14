import 'dart:async';

import 'package:flutter_application_1/services/startup_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unreachable Supabase initialization cannot hold startup', () async {
    final pendingInitialization = Completer<void>();

    final outcome = await runBoundedStartupOperation(
      () => pendingInitialization.future,
      const Duration(milliseconds: 10),
    );

    expect(outcome.result, StartupOperationResult.timedOut);
    expect(outcome.error, isA<TimeoutException>());
  });
}
