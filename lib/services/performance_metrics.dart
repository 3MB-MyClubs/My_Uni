import 'dart:collection';
import 'dart:convert';
import 'package:flutter/scheduler.dart';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Bounded, opt-in diagnostics. Never retain URLs, queries, bodies or identities.
/// Enable in profile/release with --dart-define=CLUBUP_PERFORMANCE=true.
class PerformanceMetrics {
  PerformanceMetrics({this.enabled = false, this.capacity = 256});

  final bool enabled;
  final int capacity;
  final _samples = Queue<Map<String, Object>>();
  final _counters = <String, int>{};

  void increment(String name, [int amount = 1]) {
    if (!enabled) return;
    if (!_counters.containsKey(name) && _counters.length >= capacity) return;
    _counters.update(name, (value) => value + amount, ifAbsent: () => amount);
  }

  void record(
    String name,
    Duration duration, {
    int bytes = 0,
    bool failed = false,
  }) {
    if (!enabled || capacity <= 0) return;
    increment('$name.requests');
    increment('$name.bytes', bytes);
    if (failed) increment('$name.errors');
    final sample = <String, Object>{
      'operation': name,
      'duration_us': duration.inMicroseconds,
      'bytes': bytes,
      'failed': failed,
    };
    if (_samples.length >= capacity) _samples.removeFirst();
    _samples.add(sample);
    developer.log(jsonEncode(sample), name: 'clubup.performance');
  }

  Future<T> measure<T>(String name, Future<T> Function() operation) async {
    if (!enabled) return operation();
    final clock = Stopwatch()..start();
    var failed = false;
    try {
      return await operation();
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      record(name, clock.elapsed, failed: failed);
    }
  }

  Map<String, Object> snapshot() => {
    'counters': Map<String, int>.of(_counters),
    'samples': [for (final sample in _samples) Map<String, Object>.of(sample)],
  };

  String exportJson() => jsonEncode(snapshot());

  void reset() {
    _samples.clear();
    _counters.clear();
  }
}

final performanceMetrics = PerformanceMetrics(
  enabled: const bool.fromEnvironment(
    'CLUBUP_PERFORMANCE',
    defaultValue: kProfileMode,
  ),
);

/// Counts the delivered HTTP body without buffering or decoding it twice.
/// Storage image downloads use their own cache client; these metrics describe
/// Supabase API/auth/signing/upload traffic, not total device network traffic.
class MeasuredHttpClient extends http.BaseClient {
  MeasuredHttpClient(this._inner, {PerformanceMetrics? metrics})
    : metrics = metrics ?? performanceMetrics;

  final http.Client _inner;
  final PerformanceMetrics metrics;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!metrics.enabled) return _inner.send(request);
    final clock = Stopwatch()..start();
    final segments = request.url.pathSegments;
    final rest = segments.indexOf('rest');
    final String operation;
    if (rest >= 0 && segments.length > rest + 2) {
      final resource = segments[rest + 2];
      operation = resource == 'rpc' && segments.length > rest + 3
          ? 'rpc.${segments[rest + 3]}'
          : 'table.$resource';
    } else {
      operation = segments.contains('auth') ? 'auth' : 'storage';
    }
    try {
      final response = await _inner.send(request);
      Stream<List<int>> measured() async* {
        var bytes = 0;
        var failed = response.statusCode >= 400;
        try {
          await for (final chunk in response.stream) {
            bytes += chunk.length;
            yield chunk;
          }
        } catch (_) {
          failed = true;
          rethrow;
        } finally {
          metrics.record(
            operation,
            clock.elapsed,
            bytes: bytes,
            failed: failed,
          );
        }
      }

      return http.StreamedResponse(
        measured(),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (_) {
      metrics.record(operation, clock.elapsed, failed: true);
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}

/// Opt-in frame counters avoid logging or allocating a sample for every frame.
void startPerformanceFrameRecording(double Function() refreshRate) {
  if (!performanceMetrics.enabled) return;
  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> frames) {
    final hz = refreshRate();
    final budgetUs = 1000000 / (hz > 0 ? hz : 60);
    for (final frame in frames) {
      performanceMetrics.increment('frames.total');
      performanceMetrics.increment(
        'frames.build_us',
        frame.buildDuration.inMicroseconds,
      );
      performanceMetrics.increment(
        'frames.raster_us',
        frame.rasterDuration.inMicroseconds,
      );
      if (frame.buildDuration.inMicroseconds > budgetUs ||
          frame.rasterDuration.inMicroseconds > budgetUs) {
        performanceMetrics.increment('frames.over_budget');
      }
    }
  });
}
