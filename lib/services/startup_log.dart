import 'dart:async';
import 'performance_metrics.dart';
import 'dart:developer' as developer;

import 'package:package_info_plus/package_info_plus.dart';

enum StartupOperationResult { completed, timedOut, failed }

class StartupOperationOutcome {
  const StartupOperationOutcome(this.result, [this.error]);

  final StartupOperationResult result;
  final Object? error;
}

Future<StartupOperationOutcome> runBoundedStartupOperation(
  Future<void> Function() operation,
  Duration timeout,
) async {
  try {
    await operation().timeout(timeout);
    return const StartupOperationOutcome(StartupOperationResult.completed);
  } on TimeoutException catch (error) {
    return StartupOperationOutcome(StartupOperationResult.timedOut, error);
  } catch (error) {
    return StartupOperationOutcome(StartupOperationResult.failed, error);
  }
}

/// Release-safe, structured launch diagnostics.
///
/// No account or credential data is logged. Build metadata is loaded from the
/// installed application package so pubspec.yaml remains the sole version
/// source of truth.
class StartupLog {
  static String appVersion = 'unknown';
  static String buildNumber = 'unknown';

  static final Stopwatch _processClock = Stopwatch()..start();
  static final Map<String, Stopwatch> _stageClocks = {};

  static Future<void> loadBuildInfo() async {
    final info = await PackageInfo.fromPlatform();
    appVersion = info.version;
    buildNumber = info.buildNumber;
  }

  static void event(
    String stage, {
    String result = 'ok',
    Object? error,
    int? durationMs,
  }) {
    if (result != 'begin') {
      performanceMetrics.record(
        'startup.$stage',
        Duration(milliseconds: durationMs ?? _processClock.elapsedMilliseconds),
        failed: error != null,
      );
    }
    final fields = <String>[
      '[STARTUP]',
      stage,
      'duration_ms=${durationMs ?? _processClock.elapsedMilliseconds}',
      'result=$result',
      'app_version=$appVersion',
      'build_number=$buildNumber',
      if (error != null) 'exception_type=${error.runtimeType}',
    ];
    developer.log(fields.join(' '), name: 'clubup.startup');
  }

  static void begin(String stage) {
    _stageClocks[stage] = Stopwatch()..start();
    event(stage, result: 'begin', durationMs: 0);
  }

  static void end(String stage, {String result = 'ok', Object? error}) {
    final clock = _stageClocks.remove(stage);
    event(
      stage,
      result: result,
      error: error,
      durationMs: clock?.elapsedMilliseconds,
    );
  }

  static void uncaught(String source, Object error) {
    event('S99_UNCAUGHT_$source', result: 'error', error: error);
  }
}
