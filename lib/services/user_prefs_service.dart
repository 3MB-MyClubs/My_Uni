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
      'coverPhotoPath_$userId': s.coverPhotoPaths[userId],
      'bio_$userId': s.bios[userId],
      'major_$userId': s.majors[userId],
      'year_$userId': s.years[userId],
      'interests_$userId': s.interests[userId],
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

  /// Loads every saved profile photo, banner, and club photo into [userState]
  /// so that any user's/club's picture is visible to everyone at startup.
  void loadAllPhotos() {
    if (!_initialized) return;
    for (final key in _box.keys) {
      final k = key as String;
      if (k.startsWith('profilePhotoPath_')) {
        final uid = k.substring('profilePhotoPath_'.length);
        final path = _box.get(k);
        if (path != null) userState.profilePhotoPaths[uid] = path as String;
      } else if (k.startsWith('coverPhotoPath_')) {
        final uid = k.substring('coverPhotoPath_'.length);
        final path = _box.get(k);
        if (path != null) userState.coverPhotoPaths[uid] = path as String;
      } else if (k.startsWith('clubPhotoPath_')) {
        final cid = k.substring('clubPhotoPath_'.length);
        final path = _box.get(k);
        if (path != null) userState.clubPhotoPaths[cid] = path as String;
      } else if (k.startsWith('clubBannerPath_')) {
        final cid = k.substring('clubBannerPath_'.length);
        final path = _box.get(k);
        if (path != null) userState.clubBannerPaths[cid] = path as String;
      }
    }
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  void load(String userId) {
    if (!_initialized) return;
    final s = userState;

    final photoPath = _box.get('profilePhotoPath_$userId');
    if (photoPath != null) s.profilePhotoPaths[userId] = photoPath as String;

    final coverPhotoPath = _box.get('coverPhotoPath_$userId');
    if (coverPhotoPath != null) {
      s.coverPhotoPaths[userId] = coverPhotoPath as String;
    }

    final bio = _box.get('bio_$userId');
    if (bio != null) s.bios[userId] = bio as String;

    final major = _box.get('major_$userId');
    if (major != null) s.majors[userId] = major as String;

    final year = _box.get('year_$userId');
    if (year != null) s.years[userId] = year as String;

    final interests = _box.get('interests_$userId');
    if (interests != null) {
      s.interests[userId] = List<String>.from(interests as List);
    }

    _restoreSet(
      s.followedUserIds,
      _box.get('followedUserIds_$userId'),
      fallback: {'u1', 'u4'},
    );

    _restoreSet(
      s.followedClubIds,
      _box.get('followedClubIds_$userId'),
      fallback: {'c1'},
    );

    _restoreSet(
      s.likedPostIds,
      _box.get('likedPostIds_$userId'),
      fallback: {'n1'},
    );

    _restoreSet(s.savedPostIds, _box.get('savedPostIds_$userId'));

    _restoreSet(
      s.pendingFollowRequests,
      _box.get('pendingFollowRequests_$userId'),
    );

    _restoreSet(s.shownFollowNotice, _box.get('shownFollowNotice_$userId'));

    _restoreSet(
      s.acceptedMessageRequests,
      _box.get('acceptedMessageRequests_$userId'),
    );

    _restoreSet(
      s.pendingBoardRequests,
      _box.get('pendingBoardRequests_$userId'),
    );

    final storedUsernames = _box.get('usernames');
    if (storedUsernames != null) {
      s.usernames.clear();
      (storedUsernames as Map).forEach(
        (k, v) => s.usernames[k as String] = v as String,
      );
    }
  }

  /// Persists a club's profile photo path globally (not per-user).
  Future<void> saveClubPhoto(String clubId, String path) async {
    if (!_initialized) return;
    await _box.put('clubPhotoPath_$clubId', path);
  }

  /// Persists a club's banner/cover image path globally.
  Future<void> saveClubBanner(String clubId, String path) async {
    if (!_initialized) return;
    await _box.put('clubBannerPath_$clubId', path);
  }

  /// Removes the club banner from storage.
  Future<void> removeClubBanner(String clubId) async {
    if (!_initialized) return;
    await _box.delete('clubBannerPath_$clubId');
  }

  /// Removes a specific board request entry from the stored prefs of [userId]
  /// without overwriting other fields (used when declining a request while
  /// logged in as a different user).
  Future<void> removeBoardRequest(String userId, String clubId) async {
    if (!_initialized) return;
    final key = 'pendingBoardRequests_$userId';
    final raw = _box.get(key);
    final existing = raw != null ? List<String>.from(raw as List) : <String>[];
    existing.remove('$userId:$clubId');
    await _box.put(key, existing);
  }

  void _restoreSet(
    Set<String> target,
    dynamic raw, {
    Set<String> fallback = const {},
  }) {
    target.clear();
    if (raw == null) {
      target.addAll(fallback);
      return;
    }
    target.addAll(List<String>.from(raw as List));
  }
}

final userPrefsService = UserPrefsService();
