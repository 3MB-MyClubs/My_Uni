import 'package:hive/hive.dart';
import '../models/user.dart';
import 'mock_data.dart';

/// Tracks who has viewed each post or event.
/// Key: contentId (postId or eventId)
/// Value: Set of userIds
///
/// Stored in Hive box "view_tracker_v1" so views survive logout/restart.
class ViewTracker {
  static const _boxName = 'view_tracker_v1';
  late Box<dynamic> _box;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _box = await Hive.openBox<dynamic>(_boxName);
    _initialized = true;
  }

  // ── Record a view ─────────────────────────────────────────────────────────────

  void recordView(String contentId, String userId) {
    if (userId.isEmpty) return;
    final existing = _viewerIds(contentId);
    if (existing.contains(userId)) return;
    existing.add(userId);
    _box.put(contentId, existing.toList());
  }

  // ── Read ──────────────────────────────────────────────────────────────────────

  int viewCount(String contentId) => _viewerIds(contentId).length;

  Set<String> viewerIds(String contentId) => _viewerIds(contentId);

  List<User> viewers(String contentId) {
    final ids = _viewerIds(contentId);
    return users.where((u) => ids.contains(u.id)).toList();
  }

  // ── Private ───────────────────────────────────────────────────────────────────

  Set<String> _viewerIds(String contentId) {
    if (!_initialized) return {};
    final raw = _box.get(contentId);
    if (raw == null) return {};
    return Set<String>.from(raw as List);
  }
}

final viewTracker = ViewTracker();
