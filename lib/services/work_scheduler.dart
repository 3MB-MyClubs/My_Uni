import 'dart:async';

/// One refresh at a time, with a trailing pass when invalidated mid-request.
class CoalescingRefresh {
  Future<void>? _task;
  bool _again = false;
  int _generation = 0;

  Future<void> run(Future<void> Function() refresh) {
    _again = true;
    if (_task != null) return _task!;
    final generation = _generation;
    late final Future<void> task;
    task =
        Future<void>(() async {
          if (generation != _generation) return;
          do {
            _again = false;
            await refresh();
          } while (generation == _generation && _again);
        }).whenComplete(() {
          if (identical(_task, task)) _task = null;
        });
    return _task = task;
  }

  void reset() {
    _generation++;
    _task = null;
    _again = false;
  }
}

Future<void> runWithConcurrency<T>(
  Iterable<T> values,
  Future<void> Function(T) operation, {
  int concurrency = 3,
  bool Function()? shouldContinue,
}) async {
  if (concurrency < 1) throw ArgumentError.value(concurrency, 'concurrency');
  final iterator = values.iterator;
  Future<void> worker() async {
    while ((shouldContinue?.call() ?? true) && iterator.moveNext()) {
      final value = iterator.current;
      await operation(value);
    }
  }

  await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
}
