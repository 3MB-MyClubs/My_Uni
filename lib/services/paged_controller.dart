import 'dart:async';
import 'performance_metrics.dart';
import 'package:flutter/foundation.dart';

class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor});
  final List<T> items;
  final Map<String, dynamic>? nextCursor;
  bool get hasMore => nextCursor != null;
}

typedef PageFetcher<T> =
    Future<CursorPage<T>> Function(Map<String, dynamic>? cursor);

/// Owns one query's visible rows. Late responses cannot replace a newer query,
/// a disposed screen or an account reset. Failed refreshes preserve the rows.
class PagedController<T> extends ChangeNotifier {
  PagedController({required this.idOf});
  final String Function(T) idOf;
  List<T> items = const [];
  List<T> changedItems = const [];
  Map<String, dynamic>? nextCursor;
  bool loading = false;
  bool loaded = false;
  Object? error;
  int revision = 0;
  int _generation = 0;
  bool _disposed = false;
  bool _failedAppend = false;
  PageFetcher<T>? _fetch;
  Future<void>? _task;
  Timer? _debounce;

  bool get hasMore => nextCursor != null;

  Future<void> load(
    PageFetcher<T> fetch, {
    bool preserveItems = false,
    CursorPage<T>? cached,
    Duration debounce = Duration.zero,
  }) {
    final generation = ++_generation;
    _debounce?.cancel();
    _fetch = fetch;
    _task = null;
    if (!preserveItems) {
      items = cached?.items ?? const [];
      changedItems = items;
      nextCursor = cached?.nextCursor;
      loaded = cached != null;
      revision++;
    }
    error = null;
    loading = true;
    notifyListeners();
    if (debounce != Duration.zero) {
      _debounce = Timer(debounce, () {
        if (!_disposed && generation == _generation) {
          _task = _read(fetch, null, generation, append: false);
        }
      });
      return Future.value();
    }
    return _task = _read(fetch, null, generation, append: false);
  }

  Future<void> loadMore() {
    if (_task != null) return _task!;
    final fetch = _fetch;
    if (loading || !hasMore || fetch == null) return Future.value();
    loading = true;
    error = null;
    notifyListeners();
    return _task = _read(fetch, nextCursor, _generation, append: true);
  }

  Future<void> retry() {
    final fetch = _fetch;
    if (fetch == null) return Future.value();
    return _failedAppend && hasMore
        ? loadMore()
        : load(fetch, preserveItems: true);
  }

  Future<void> _read(
    PageFetcher<T> fetch,
    Map<String, dynamic>? cursor,
    int generation, {
    required bool append,
  }) async {
    try {
      final page = await performanceMetrics.measure(
        'content.page',
        () => fetch(cursor),
      );
      if (_disposed || generation != _generation) return;
      final byId = <String, T>{
        if (append)
          for (final item in items) idOf(item): item,
        for (final item in page.items) idOf(item): item,
      };
      items = List.unmodifiable(byId.values);
      changedItems = page.items;
      nextCursor = page.nextCursor;
      loaded = true;
      revision++;
    } catch (failure) {
      if (!_disposed && generation == _generation) {
        error = failure;
        _failedAppend = append;
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _task = null;
        notifyListeners();
      }
    }
  }

  void reset() {
    _generation++;
    _debounce?.cancel();
    _task = null;
    _fetch = null;
    items = const [];
    changedItems = const [];
    nextCursor = null;
    loading = loaded = false;
    error = null;
    revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    super.dispose();
  }
}
