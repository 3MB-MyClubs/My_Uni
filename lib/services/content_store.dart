import 'package:hive/hive.dart';
import '../models/board_member_request.dart';
import '../models/comment.dart';
import '../models/event.dart';
import '../models/like.dart';
import '../models/news_post.dart';
import '../models/notification.dart';
import '../models/share.dart';
import 'mock_data.dart';

/// Persists all user-generated content (posts, events, stories, comments,
/// likes, shares, dynamic notifications) to a Hive box.
///
/// On first run the lists keep their seed data from mock_data.dart.
/// Every subsequent run loads the last saved state.
///
/// [_seedVersion] must be incremented whenever mock_data.dart changes event or
/// post seed data. A version mismatch causes the stored events/posts/stories
/// to be discarded so the fresh mock data is used instead.
class ContentStore {
  static const _boxName = 'content_v1';

  /// Bump this integer any time you change mock event / post seed data.
  /// The stored version is compared on startup; a mismatch clears stale data.
  static const int _seedVersion = 6;

  late Box<dynamic> _box;
  bool _initialized = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    // Hive.init() is already called by MessageService — just open the box.
    _box = await Hive.openBox<dynamic>(_boxName);
    _initialized = true;
  }

  /// Call once after [initialize] to replace in-memory lists with stored data.
  /// If nothing is stored yet, or the seed version has changed, the lists keep
  /// (or reset to) their mock-data seed values.
  void applyToLists() {
    final storedVersion = _box.get('seedVersion') as int? ?? 0;
    final versionMatch = storedVersion == _seedVersion;

    // Always load user-generated interaction data (safe across versions)
    _load('comments', comments,
        (m) => Comment.fromMap(Map<String, dynamic>.from(m as Map)));
    _load('likes', likes,
        (m) => Like.fromMap(Map<String, dynamic>.from(m as Map)));
    _load('shares', shares,
        (m) => Share.fromMap(Map<String, dynamic>.from(m as Map)));

    if (versionMatch) {
      // Load seed data that may have been mutated by user actions
      _load('posts', newsPosts,
          (m) => NewsPost.fromMap(Map<String, dynamic>.from(m as Map)));
      _load('events', events,
          (m) => Event.fromMap(Map<String, dynamic>.from(m as Map)));
      _load('stories', clubStories,
          (m) => ClubStory.fromMap(Map<String, dynamic>.from(m as Map)));
    } else {
      // Seed data changed — discard stale Hive data, use fresh mock data,
      // and write the new version so this only triggers once.
      _box.delete('posts');
      _box.delete('events');
      _box.delete('stories');
      _box.put('seedVersion', _seedVersion);
    }
  }

  void _load<T>(String key, List<T> target, T Function(dynamic) fromRaw) {
    final raw = _box.get(key);
    if (raw == null) return; // nothing stored yet — keep seed data
    target
      ..clear()
      ..addAll((raw as List).map(fromRaw));
  }

  // ── Save helpers ─────────────────────────────────────────────────────────────

  Future<void> saveNewsPosts() async =>
      _box.put('posts', newsPosts.map((p) => p.toMap()).toList());

  Future<void> saveEvents() async =>
      _box.put('events', events.map((e) => e.toMap()).toList());

  Future<void> saveClubStories() async =>
      _box.put('stories', clubStories.map((s) => s.toMap()).toList());

  Future<void> saveComments() async =>
      _box.put('comments', comments.map((c) => c.toMap()).toList());

  Future<void> saveLikes() async =>
      _box.put('likes', likes.map((l) => l.toMap()).toList());

  Future<void> saveShares() async =>
      _box.put('shares', shares.map((s) => s.toMap()).toList());

  Future<void> saveDynamicNotifications(List<AppNotification> ns) async =>
      _box.put('dynNotifs', ns.map((n) => n.toMap()).toList());

  List<AppNotification>? loadDynamicNotifications() {
    final raw = _box.get('dynNotifs');
    if (raw == null) return null;
    return (raw as List)
        .map((m) => AppNotification.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  // ── Board member requests ────────────────────────────────────────────────────

  Future<void> saveBoardMemberRequests() async => _box.put(
      'boardRequests',
      boardMemberRequests.map((r) => r.toMap()).toList());

  void loadBoardMemberRequests() {
    final raw = _box.get('boardRequests');
    if (raw == null) return;
    boardMemberRequests
      ..clear()
      ..addAll((raw as List).map(
          (m) => BoardMemberRequest.fromMap(Map<String, dynamic>.from(m as Map))));
  }

  // ── Club board member IDs ────────────────────────────────────────────────────
  // Only the mutable boardMemberIds list is persisted; static club data stays
  // in mock_data.dart as the source of truth for names/descriptions etc.

  Future<void> saveBoardMemberIds() async {
    final map = <String, List<String>>{};
    for (final club in clubs) {
      map[club.id] = List<String>.from(club.boardMemberIds);
    }
    await _box.put('boardMemberIds', map);
  }

  void loadBoardMemberIds() {
    final raw = _box.get('boardMemberIds');
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);
    for (final club in clubs) {
      final stored = map[club.id];
      if (stored != null) {
        club.boardMemberIds
          ..clear()
          ..addAll(List<String>.from(stored as List));
      }
    }
  }

  // ── Club board member titles ─────────────────────────────────────────────────

  Future<void> saveBoardMemberTitles() async {
    // Hive cannot serialise nested typed maps — store as Map<String, dynamic>
    // where each value is itself a Map<String, dynamic> (userId → title).
    final outer = <String, dynamic>{};
    for (final club in clubs) {
      outer[club.id] = Map<String, dynamic>.from(club.boardMemberTitles);
    }
    await _box.put('boardMemberTitles', outer);
  }

  void loadBoardMemberTitles() {
    final raw = _box.get('boardMemberTitles');
    if (raw == null) return;
    final outer = Map<String, dynamic>.from(raw as Map);
    for (final club in clubs) {
      final stored = outer[club.id];
      if (stored == null) continue;
      final inner = Map<String, dynamic>.from(stored as Map);
      club.boardMemberTitles
        ..clear()
        ..addAll(inner.map((k, v) => MapEntry(k, v as String)));
    }
  }

  // ── Ownership-based deletion ──────────────────────────────────────────────────
  // Allowed when requester is the creator OR the admin of the content's club.

  bool _isClubAdmin(String clubId, String userId) =>
      clubs.any((c) => c.id == clubId && c.adminUserIds.contains(userId));

  bool deleteEvent(String eventId, String requestingUserId) {
    final idx = events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return false;
    final ev = events[idx];
    final allowed = ev.createdByUserId == requestingUserId ||
        _isClubAdmin(ev.clubId, requestingUserId);
    if (!allowed) return false;
    events.removeAt(idx);
    saveEvents();
    return true;
  }

  bool deletePost(String postId, String requestingUserId) {
    final idx = newsPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) return false;
    final post = newsPosts[idx];
    final allowed = post.authorId == requestingUserId ||
        _isClubAdmin(post.clubId, requestingUserId);
    if (!allowed) return false;
    newsPosts.removeAt(idx);
    saveNewsPosts();
    return true;
  }

  bool deleteStory(String storyId, String requestingUserId) {
    final idx = clubStories.indexWhere((s) => s.id == storyId);
    if (idx == -1) return false;
    final story = clubStories[idx];
    final allowed = story.createdByUserId == requestingUserId ||
        _isClubAdmin(story.clubId, requestingUserId);
    if (!allowed) return false;
    clubStories.removeAt(idx);
    saveClubStories();
    return true;
  }

  // ── Save everything at once ───────────────────────────────────────────────────

  Future<void> saveAll(List<AppNotification> dynamicNotifs) async {
    await Future.wait([
      saveNewsPosts(),
      saveEvents(),
      saveClubStories(),
      saveComments(),
      saveLikes(),
      saveShares(),
      saveDynamicNotifications(dynamicNotifs),
      saveBoardMemberRequests(),
      saveBoardMemberIds(),
      saveBoardMemberTitles(),
    ]);
  }
}

final contentStore = ContentStore();
