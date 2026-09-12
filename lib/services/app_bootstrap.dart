/// Handle to the deferred part of app startup.
///
/// The branded launch screen needs no plugin-backed state. Remaining Hive
/// boxes open after runApp; callers await [readyFor] for the specific stores
/// they use. [ready] remains available for legacy aggregate readiness.
class AppBootstrap {
  Future<void> ready = Future.value();
  bool localDataReady = false;

  final Map<String, Future<bool>> _features = {};
  final Set<String> _completed = {};

  /// Failures are isolated to the feature that owns the unavailable storage.
  Future<bool> start(String feature, Future<void> Function() initialize) {
    return _features.putIfAbsent(feature, () async {
      try {
        await initialize().timeout(const Duration(seconds: 5));
        _completed.add(feature);
        return true;
      } catch (_) {
        return false;
      }
    });
  }

  bool isReady(String feature) =>
      _completed.contains(feature) || localDataReady;

  Future<bool> readyFor(Iterable<String> features) async {
    final results = await Future.wait([
      for (final feature in features)
        _features[feature] ?? Future.value(localDataReady),
    ]);
    return results.every((ready) => ready);
  }
}

final appBootstrap = AppBootstrap();
