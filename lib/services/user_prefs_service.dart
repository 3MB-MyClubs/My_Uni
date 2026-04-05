import 'package:hive/hive.dart';
import 'user_state.dart';

/// Persists UserState to a Hive box so settings survive logout / app restarts.
/// All keys are namespaced by userId so multiple accounts stay isolated.
class UserPrefsService {
  static const _boxName = 'user_prefs';
  late Box<dynamic> _box;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    // Hive.init() is already called by MessageService — just open the box.
    _box = await Hive.openBox<dynamic>(_boxName);
    _initialized = true;
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> save(String userId) async {
    if (!_initialized) return;
    final s = userState;

    await _box.putAll({
      'isPrivate_$userId': s.isPrivate,
      'profilePhotoPath_$userId': s.profilePhotoPaths[userId],
      'followedUserIds_$userId': s.followedUserIds.toList(),
      'followedClubIds_$userId': s.followedClubIds.toList(),
      'likedPostIds_$userId': s.likedPostIds.toList(),
      'savedPostIds_$userId': s.savedPostIds.toList(),
      'pendingFollowRequests_$userId': s.pendingFollowRequests.toList(),
      'shownFollowNotice_$userId': s.shownFollowNotice.toList(),
      'acceptedMessageRequests_$userId': s.acceptedMessageRequests.toList(),
      // privateUserIds is global (shared across sessions, not per-user).
      'privateUserIds': s.privateUserIds.toList(),
    });
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  void load(String userId) {
    if (!_initialized) return;
    final s = userState;

    s.isPrivate = _box.get('isPrivate_$userId', defaultValue: false) as bool;

    final photoPath = _box.get('profilePhotoPath_$userId');
    if (photoPath != null) s.profilePhotoPaths[userId] = photoPath as String;

    _restoreSet(s.followedUserIds, _box.get('followedUserIds_$userId'),
        fallback: {'u1', 'u4'});

    _restoreSet(s.followedClubIds, _box.get('followedClubIds_$userId'),
        fallback: {'c1'});

    _restoreSet(s.likedPostIds, _box.get('likedPostIds_$userId'),
        fallback: {'n1'});

    _restoreSet(s.savedPostIds, _box.get('savedPostIds_$userId'));

    _restoreSet(
        s.pendingFollowRequests, _box.get('pendingFollowRequests_$userId'));

    _restoreSet(s.shownFollowNotice, _box.get('shownFollowNotice_$userId'));

    _restoreSet(s.acceptedMessageRequests,
        _box.get('acceptedMessageRequests_$userId'));

    final storedPrivate = _box.get('privateUserIds');
    if (storedPrivate != null) {
      s.privateUserIds
        ..clear()
        ..addAll(List<String>.from(storedPrivate as List));
      // Always keep the demo default.
      s.privateUserIds.add('u3');
    }
  }

  void _restoreSet(Set<String> target, dynamic raw,
      {Set<String> fallback = const {}}) {
    if (raw == null) {
      if (fallback.isNotEmpty) {
        target
          ..clear()
          ..addAll(fallback);
      }
      return;
    }
    target
      ..clear()
      ..addAll(List<String>.from(raw as List));
  }
}

final userPrefsService = UserPrefsService();
