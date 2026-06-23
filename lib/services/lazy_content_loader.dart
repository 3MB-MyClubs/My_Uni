import 'dart:async';

import 'event_cleanup_service.dart';
import 'supabase_content_service.dart';

class LazyContentLoader {
  Future<void>? _contentLoad;
  Future<void>? _countLoad;
  bool _contentLoaded = false;
  bool _countsLoaded = false;

  Future<void> ensureContentLoaded() {
    if (_contentLoaded) return Future.value();
    return _contentLoad ??= _loadContent();
  }

  Future<void> refreshContent() async {
    _contentLoaded = false;
    _countsLoaded = false;
    _contentLoad = null;
    _countLoad = null;
    await ensureContentLoaded();
    await ensureCountsLoaded();
  }

  Future<void> ensureCountsLoaded() {
    if (_countsLoaded) return Future.value();
    return _countLoad ??= _loadCounts();
  }

  Future<void> _loadContent() async {
    try {
      await supabaseContentService.refreshPublicContent();
      await eventCleanupService.cleanupExpiredEvents();
      _contentLoaded = true;
      unawaited(ensureCountsLoaded());
    } finally {
      _contentLoad = null;
    }
  }

  Future<void> _loadCounts() async {
    try {
      await supabaseContentService.refreshEngagementCounts();
      _countsLoaded = true;
    } finally {
      _countLoad = null;
    }
  }
}

final lazyContentLoader = LazyContentLoader();
