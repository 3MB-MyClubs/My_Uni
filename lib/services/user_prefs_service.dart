import 'package:hive/hive.dart';
import 'mock_data.dart';
import 'supabase_config.dart';
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
      'bio_$userId': s.bios[userId],
      'major_$userId': s.majors[userId],
      'year_$userId': s.years[userId],
      'interests_$userId': s.interests[userId],
      'minors_$userId': s.minors[userId],
      'doubleMajors_$userId': s.doubleMajors[userId],
      'followedUserIds_$userId': s.followedUserIds.toList(),
      'followedClubIds_$userId': s.followedClubIds.toList(),
      'likedPostIds_$userId': s.likedPostIds.toList(),
      'savedPostIds_$userId': s.savedPostIds.toList(),
      'pendingFollowRequests_$userId': s.pendingFollowRequests.toList(),
      'shownFollowNotice_$userId': s.shownFollowNotice.toList(),
      'acceptedMessageRequests_$userId': s.acceptedMessageRequests.toList(),
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
      } else if (k.startsWith('clubPhotoPath_')) {
        final cid = k.substring('clubPhotoPath_'.length);
        final path = _box.get(k);
        if (path != null) userState.clubPhotoPaths[cid] = path as String;
      } else if (k.startsWith('clubDesc_')) {
        final cid = k.substring('clubDesc_'.length);
        final desc = _box.get(k);
        final idx = clubs.indexWhere((c) => c.id == cid);
        if (desc != null && idx >= 0) clubs[idx].description = desc as String;
      }
    }
    // Pinned club posts (global, set by club admins).
    final pinned = _box.get('pinnedPostIds');
    if (pinned != null) {
      userState.pinnedPostIds
        ..clear()
        ..addAll(List<String>.from(pinned as List));
    }
  }

  /// Persists a club's description globally (visible to everyone).
  Future<void> saveClubDescription(String clubId, String description) async {
    if (!_initialized) return;
    await _box.put('clubDesc_$clubId', description);
  }

  /// Persists the set of pinned club post ids globally.
  Future<void> savePinnedPosts() async {
    if (!_initialized) return;
    await _box.put('pinnedPostIds', userState.pinnedPostIds.toList());
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  void load(String userId) {
    if (!_initialized) return;
    final s = userState;

    final photoPath = _box.get('profilePhotoPath_$userId');
    if (photoPath != null) s.profilePhotoPaths[userId] = photoPath as String;

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

    final minors = _box.get('minors_$userId');
    if (minors != null) {
      s.minors[userId] = List<String>.from(minors as List);
    }

    final doubleMajors = _box.get('doubleMajors_$userId');
    if (doubleMajors != null) {
      s.doubleMajors[userId] = List<String>.from(doubleMajors as List);
    }

    _restoreSet(
      s.followedUserIds,
      _box.get('followedUserIds_$userId'),
      fallback: {'u1', 'u4'},
    );

    if (!SupabaseConfig.isConfigured) {
      _restoreSet(
        s.followedClubIds,
        _box.get('followedClubIds_$userId'),
        fallback: {'c1'},
      );
    }

    if (!SupabaseConfig.isConfigured) {
      _restoreSet(
        s.likedPostIds,
        _box.get('likedPostIds_$userId'),
        fallback: {'n1'},
      );
    }

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
