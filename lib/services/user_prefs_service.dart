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
      'profilePhotoPath_$userId': s.profilePhotoPaths[userId],
      'bannerPath_$userId': s.bannerPaths[userId],
      'followedUserIds_$userId': s.followedUserIds.toList(),
      'followedClubIds_$userId': s.followedClubIds.toList(),
      'likedPostIds_$userId': s.likedPostIds.toList(),
      'savedPostIds_$userId': s.savedPostIds.toList(),
      'pendingFollowRequests_$userId': s.pendingFollowRequests.toList(),
      'shownFollowNotice_$userId': s.shownFollowNotice.toList(),
      'acceptedMessageRequests_$userId': s.acceptedMessageRequests.toList(),
      'pendingBoardRequests_$userId': s.pendingBoardRequests.toList(),
      // usernames are global (visible to everyone).
      'usernames': s.usernames.map((k, v) => MapEntry(k, v)),
    });
  }

  // ── Load all profile photos (called once at startup) ────────────────────────

  /// Loads every saved profile photo and banner into [userState] so that any
  /// user's picture is visible to everyone — regardless of who is logged in.
  void loadAllPhotos() {
    if (!_initialized) return;
    for (final key in _box.keys) {
      final k = key as String;
      if (k.startsWith('profilePhotoPath_')) {
        final uid = k.substring('profilePhotoPath_'.length);
        final path = _box.get(k);
        if (path != null) userState.profilePhotoPaths[uid] = path as String;
      } else if (k.startsWith('bannerPath_')) {
        final uid = k.substring('bannerPath_'.length);
        final path = _box.get(k);
        if (path != null) userState.bannerPaths[uid] = path as String;
      }
    }
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  void load(String userId) {
    if (!_initialized) return;
    final s = userState;

    final photoPath = _box.get('profilePhotoPath_$userId');
    if (photoPath != null) s.profilePhotoPaths[userId] = photoPath as String;

    final bannerPath = _box.get('bannerPath_$userId');
    if (bannerPath != null) s.bannerPaths[userId] = bannerPath as String;

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

    _restoreSet(s.pendingBoardRequests,
        _box.get('pendingBoardRequests_$userId'));

    final storedUsernames = _box.get('usernames');
    if (storedUsernames != null) {
      s.usernames.clear();
      (storedUsernames as Map).forEach(
        (k, v) => s.usernames[k as String] = v as String,
      );
    }
  }

  /// Removes a specific board request entry from the stored prefs of [userId]
  /// without overwriting other fields (used when declining a request while
  /// logged in as a different user).
  Future<void> removeBoardRequest(String userId, String clubId) async {
    if (!_initialized) return;
    final key = 'pendingBoardRequests_$userId';
    final raw = _box.get(key);
    final existing =
        raw != null ? List<String>.from(raw as List) : <String>[];
    existing.remove('$userId:$clubId');
    await _box.put(key, existing);
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
