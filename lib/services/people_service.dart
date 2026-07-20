import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/user.dart';
import 'supabase_config.dart';
import 'user_state.dart';

class PeopleService {
  List<User> _cachedPeople = const [];
  Set<String> _cachedFollowerIds = const {};
  final Map<String, Set<String>> _followersByUserId = {};
  final Map<String, Set<String>> _followingByUserId = {};
  final Map<String, Set<String>> _clubIdsByUserId = {};

  List<User> get cachedPeople => _cachedPeople;
  Set<String> get cachedFollowerIds => _cachedFollowerIds;
  Set<String> clubIdsFor(String userId) => _clubIdsByUserId[userId] ?? const {};

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  // The people-directory query is identical for every caller (query/excludeId
  // are applied client-side), and at startup Feed, Explore and Profile all
  // trigger it concurrently because the tab stack mounts them together — so
  // the raw rows are in-flight-deduped and cached for a short TTL. Explicit
  // pull-to-refresh passes force: true.
  List<Map<String, dynamic>> _peopleRows = const [];
  DateTime? _peopleRowsFetchedAt;
  Future<List<Map<String, dynamic>>>? _peopleRowsInFlight;
  static const _peopleRowsTtl = Duration(seconds: 60);

  Future<List<Map<String, dynamic>>> _peopleRowsFor({required bool force}) {
    final fetchedAt = _peopleRowsFetchedAt;
    if (!force &&
        fetchedAt != null &&
        _peopleRows.isNotEmpty &&
        DateTime.now().difference(fetchedAt) < _peopleRowsTtl) {
      return Future.value(_peopleRows);
    }

    final inFlight = _peopleRowsInFlight;
    if (inFlight != null) return inFlight;

    final future = _fetchPeopleRows();
    _peopleRowsInFlight = future;
    return future;
  }

  Future<List<Map<String, dynamic>>> _fetchPeopleRows() async {
    try {
      final rows = await _client!
          .from('profiles')
          .select(
            'id, email, full_name, role, avatar_url, bio, major_id, academic_year_id',
          )
          .eq('role', 'student')
          .order('full_name', ascending: true)
          .limit(100);
      _peopleRows = [for (final row in rows) Map<String, dynamic>.from(row)];
      _peopleRowsFetchedAt = DateTime.now();
      return _peopleRows;
    } finally {
      _peopleRowsInFlight = null;
    }
  }

  Future<List<User>> fetchPeople({
    String query = '',
    String? excludeId,
    bool force = false,
  }) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await _peopleRowsFor(force: force);

    final majorNames = await _lookupNames('majors');
    final yearNames = await _lookupNames('academic_years');
    final q = query.toLowerCase().trim();

    final people = <User>[];
    for (final row in rows) {
      final id = row['id'].toString();
      if (excludeId != null && id == excludeId) continue;

      final name = _string(row['full_name']);
      final email = _string(row['email']);
      if (q.isNotEmpty &&
          !name.toLowerCase().contains(q) &&
          !email.toLowerCase().contains(q)) {
        continue;
      }

      final avatarUrl = _nullableString(row['avatar_url']);
      if (avatarUrl != null) userState.setProfilePhotoUrl(id, avatarUrl);

      final bio = _nullableString(row['bio']);
      if (bio != null) userState.setBio(id, bio);

      final majorName = majorNames[_nullableString(row['major_id'])];
      if (majorName != null) userState.setMajor(id, majorName);

      final yearName = yearNames[_nullableString(row['academic_year_id'])];
      if (yearName != null) userState.setYear(id, yearName);

      people.add(
        User(
          id: id,
          name: name.isEmpty ? email : name,
          email: email,
          password: '',
          role: _string(row['role'], fallback: 'student'),
          subscribedClubIds: const [],
        ),
      );
    }

    _cachedPeople = people;
    return people;
  }

  // Multiple screens hydrate the same user's follow graph at startup; run the
  // network fetch once per session (join any in-flight call) unless forced.
  final Set<String> _followingHydratedThisSession = {};
  final Map<String, Future<void>> _followingInFlight = {};

  Future<void> hydrateFollowing(String userId, {bool force = false}) {
    final client = _client;
    if (client == null || userId.isEmpty) return Future.value();

    if (!force && _followingHydratedThisSession.contains(userId)) {
      return Future.value();
    }

    final inFlight = _followingInFlight[userId];
    if (inFlight != null) return inFlight;

    final future = _hydrateFollowing(client, userId);
    _followingInFlight[userId] = future;
    return future;
  }

  Future<void> _hydrateFollowing(SupabaseClient client, String userId) async {
    try {
      final results = await Future.wait([
        client
            .from('profile_follows')
            .select('following_id')
            .eq('follower_id', userId),
        client
            .from('profile_follows')
            .select('follower_id')
            .eq('following_id', userId),
      ]);
      final followingRows = results[0];
      final followerRows = results[1];

      userState.replaceFollowedUsers(
        followingRows.map((row) => row['following_id'].toString()),
      );
      _followingByUserId[userId] = followingRows
          .map((row) => row['following_id'].toString())
          .toSet();

      _cachedFollowerIds = followerRows
          .map((row) => row['follower_id'].toString())
          .toSet();
      _followersByUserId[userId] = _cachedFollowerIds;

      _followingHydratedThisSession.add(userId);
    } finally {
      _followingInFlight.remove(userId);
    }
  }

  Future<void> hydrateConnectionsFor(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return;
    if (_cachedPeople.isEmpty) await fetchPeople();

    // For the current user, hydrateFollowing fetches the same two halves of
    // the follow graph — join a live run (the startup race) or reuse this
    // session's result instead of issuing the or() query again.
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == userId) {
      await _followingInFlight[userId];
      if (_followingHydratedThisSession.contains(userId)) {
        await _cacheProfilesByIds({
          ...?_followersByUserId[userId],
          ...?_followingByUserId[userId],
        });
        return;
      }
    }

    final rows = await client
        .from('profile_follows')
        .select('follower_id, following_id')
        .or('follower_id.eq.$userId,following_id.eq.$userId');

    _followersByUserId[userId] = rows
        .where((row) => row['following_id'].toString() == userId)
        .map((row) => row['follower_id'].toString())
        .toSet();
    _followingByUserId[userId] = rows
        .where((row) => row['follower_id'].toString() == userId)
        .map((row) => row['following_id'].toString())
        .toSet();

    await _cacheProfilesByIds({
      ...?_followersByUserId[userId],
      ...?_followingByUserId[userId],
    });

    if (myId == userId) {
      _cachedFollowerIds = _followersByUserId[userId] ?? const {};
      userState.replaceFollowedUsers(_followingByUserId[userId] ?? const {});
    }
  }

  Future<void> hydrateProfileDetailsFor(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return;

    // Everything here is independent: the reference lookups are
    // session-cached, and the three per-user reads fire together instead of
    // one after another. A null result preserves that branch's old
    // swallow-and-continue semantics.
    final results = await Future.wait<dynamic>([
      _lookupNames('majors'),
      _lookupNames('academic_years'),
      _lookupNames('interests'),
      client
          .from('profiles')
          .select(
            'id, email, full_name, role, avatar_url, bio, major_id, academic_year_id',
          )
          .eq('id', userId)
          .maybeSingle()
          .then<dynamic>((row) => row)
          .catchError((_) => null),
      client
          .from('student_interests')
          .select('interest_id')
          .eq('user_id', userId)
          .then<dynamic>((rows) => rows)
          .catchError((_) => null),
      client
          .from('club_followers')
          .select('club_id')
          .eq('profile_id', userId)
          .then<dynamic>((rows) => rows)
          .catchError((_) => null),
    ]);

    final majorNames = results[0] as Map<String, String>;
    final yearNames = results[1] as Map<String, String>;
    final interestNames = results[2] as Map<String, String>;

    final profile = results[3];
    if (profile != null) {
      final user = _userFromProfileRow(
        Map<String, dynamic>.from(profile as Map),
        majorNames: majorNames,
        yearNames: yearNames,
        subscribedClubIds: _clubIdsByUserId[userId]?.toList() ?? const [],
      );
      _upsertCachedUser(user);
    }

    final interestRows = results[4];
    if (interestRows != null) {
      final interestIds = (interestRows as List)
          .map((row) => _nullableString((row as Map)['interest_id']))
          .whereType<String>()
          .toList();
      // Resolved from the session-cached map in join-row order — the same
      // order the old per-ids lookup query produced.
      userState.setInterests(userId, [
        for (final id in interestIds)
          if ((interestNames[id] ?? '').isNotEmpty) interestNames[id]!,
      ]);
    }

    final clubRows = results[5];
    if (clubRows != null) {
      final clubIds = (clubRows as List)
          .map((row) => _nullableString((row as Map)['club_id']))
          .whereType<String>()
          .toSet();
      _clubIdsByUserId[userId] = clubIds;
      _replaceCachedUserClubIds(userId, clubIds.toList());
    }
  }

  // Same-visit cache: club_profile_screen.dart independently opens the Board
  // tab and the Members sheet, each of which used to re-fetch this list (plus
  // the majors/academic_years lookups) from scratch.
  final Map<String, List<User>> _clubMembersCache = {};
  final Map<String, Future<List<User>>> _clubMembersInFlight = {};
  final Map<String, int> _clubMembersCacheVersions = {};

  Future<List<User>> fetchClubMembers(String clubId) async {
    if (_client == null || clubId.isEmpty) return const [];

    final cached = _clubMembersCache[clubId];
    if (cached != null) return cached;

    final inFlight = _clubMembersInFlight[clubId];
    if (inFlight != null) return inFlight;

    final cacheVersion = _clubMembersCacheVersions[clubId] ?? 0;
    final future = _fetchClubMembers(clubId);
    _clubMembersInFlight[clubId] = future;
    try {
      final result = await future;
      if (result.isNotEmpty &&
          (_clubMembersCacheVersions[clubId] ?? 0) == cacheVersion) {
        _clubMembersCache[clubId] = result;
      }
      return result;
    } finally {
      if (identical(_clubMembersInFlight[clubId], future)) {
        _clubMembersInFlight.remove(clubId);
      }
    }
  }

  /// Call after a membership/board-role change so the next [fetchClubMembers]
  /// re-fetches instead of serving a now-stale cached list.
  void invalidateClubMembers(String clubId) {
    _clubMembersCache.remove(clubId);
    _clubMembersCacheVersions[clubId] =
        (_clubMembersCacheVersions[clubId] ?? 0) + 1;
  }

  /// Reconciles a remote member snapshot with the signed-in student's
  /// optimistic follow state. This prevents a response captured just before a
  /// follow/unfollow commit from hiding or re-adding that student in the sheet.
  List<User> reconcileCurrentClubMember({
    required Iterable<User> fetchedMembers,
    required Iterable<User> fallbackMembers,
    required User? currentUser,
    required bool currentUserIsFollowing,
  }) {
    final fetched = fetchedMembers.toList();
    final fallback = fallbackMembers.toList();
    final source = fetched.isNotEmpty || fallback.isEmpty ? fetched : fallback;
    final byId = <String, User>{for (final member in source) member.id: member};

    if (currentUser != null) {
      if (currentUserIsFollowing) {
        byId[currentUser.id] = currentUser;
      } else {
        byId.remove(currentUser.id);
      }
    }

    return byId.values.toList();
  }

  Future<List<User>> _fetchClubMembers(String clubId) async {
    final client = _client;
    if (client == null) return const [];

    final followerRows = await client
        .from('club_followers')
        .select('profile_id')
        .eq('club_id', clubId);

    final profileIds = followerRows
        .map((row) => row['profile_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (profileIds.isEmpty) return const [];

    final rows = await client
        .from('profiles')
        .select(
          'id, email, full_name, role, avatar_url, bio, major_id, academic_year_id',
        )
        .inFilter('id', profileIds);

    final majorNames = await _lookupNames('majors');
    final yearNames = await _lookupNames('academic_years');
    final members = rows.map((row) {
      return _userFromProfileRow(
        Map<String, dynamic>.from(row as Map),
        majorNames: majorNames,
        yearNames: yearNames,
        subscribedClubIds: [clubId],
      );
    }).toList();

    final fetchedIds = members.map((user) => user.id).toSet();
    _cachedPeople = [
      ..._cachedPeople.where((user) => !fetchedIds.contains(user.id)),
      ...members,
    ];
    return members;
  }

  Future<void> refreshPeopleDirectory({
    String? excludeId,
    bool force = false,
  }) async {
    final currentUserId = excludeId ?? '';
    // The follow graph and the directory rows are independent queries.
    await Future.wait([
      hydrateFollowing(currentUserId, force: force),
      fetchPeople(
        excludeId: currentUserId.isEmpty ? null : currentUserId,
        force: force,
      ),
    ]);
  }

  void setCachedFollower(String userId, bool followsMe) {
    _cachedFollowerIds = {
      ..._cachedFollowerIds.where((id) => id != userId),
      if (followsMe) userId,
    };
  }

  void setCachedFollowing(String userId, bool follow) {
    userState.setFollowingUser(userId, follow);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    final following = {...?_followingByUserId[myId]};
    if (follow) {
      following.add(userId);
      final followers = {...?_followersByUserId[userId]}..add(myId);
      _followersByUserId[userId] = followers;
    } else {
      following.remove(userId);
      final followers = {...?_followersByUserId[userId]}..remove(myId);
      _followersByUserId[userId] = followers;
    }
    _followingByUserId[myId] = following;
  }

  List<User> peopleByIds(Iterable<String> ids) {
    final byId = {for (final user in _cachedPeople) user.id: user};
    return ids
        .map(
          (id) =>
              byId[id] ??
              User(
                id: id,
                name: 'Student profile',
                email: '',
                password: '',
                role: 'student',
                subscribedClubIds: const [],
              ),
        )
        .toList();
  }

  /// Ensures persisted messaging participants have their current name and
  /// avatar cached even when the people directory has not been opened yet.
  Future<void> hydrateProfilesByIds(Iterable<String> ids) async {
    final requestedIds = ids.where((id) => id.isNotEmpty).toSet();
    if (requestedIds.isEmpty) return;
    try {
      await _cacheProfilesByIds(requestedIds);
    } catch (_) {
      // Messaging remains usable with its initials fallback while offline.
    }
  }

  List<User> followersFor(String userId) {
    return peopleByIds(_followersByUserId[userId] ?? const {});
  }

  List<User> followingFor(String userId) {
    return peopleByIds(_followingByUserId[userId] ?? const {});
  }

  /// Maps many profile rows at once, sharing a single majors/academic_years
  /// lookup instead of re-querying them per row (avoids N+1 round trips when
  /// hydrating e.g. a post's likers/viewers/attendees/commenters).
  Future<List<User>> usersFromProfileMaps(
    List<Map<dynamic, dynamic>> profiles,
  ) async {
    if (profiles.isEmpty) return const [];
    final lookups = await Future.wait([
      _lookupNames('majors'),
      _lookupNames('academic_years'),
    ]);
    final majorNames = lookups[0];
    final yearNames = lookups[1];
    final users = [
      for (final profile in profiles)
        _userFromProfileRow(
          Map<String, dynamic>.from(profile),
          majorNames: majorNames,
          yearNames: yearNames,
        ),
    ];
    for (final user in users) {
      _upsertCachedUser(user);
    }
    return users;
  }

  List<User> randomProfiles({String? excludeId}) {
    final people = _cachedPeople.where((user) => user.id != excludeId).toList()
      ..sort(
        (a, b) =>
            _stableSuggestionRank(a.id).compareTo(_stableSuggestionRank(b.id)),
      );
    return people;
  }

  int _stableSuggestionRank(String id) {
    final seed = DateTime.now().day + DateTime.now().month * 37;
    return (id.hashCode ^ seed).abs();
  }

  Future<void> setFollowing({
    required String followerId,
    required String followingId,
    required bool follow,
  }) async {
    final client = _client;
    if (client == null || followerId.isEmpty || followingId.isEmpty) return;

    if (follow) {
      // Insert-ignoring-duplicate: one round trip instead of check-then-insert.
      try {
        await client.from('profile_follows').insert({
          'follower_id': followerId,
          'following_id': followingId,
        });
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
      }
      setCachedFollowing(followingId, true);
    } else {
      await client
          .from('profile_follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
      setCachedFollowing(followingId, false);
    }
  }

  // majors/academic_years/interests are static reference tables — cache them
  // for the life of the app session instead of re-querying on every profile
  // mapped. Shared with StudentProfileService so login detail hydration and
  // the people directory reuse the same fetch.
  final Map<String, Map<String, String>> _lookupNameCache = {};
  final Map<String, Future<Map<String, String>>> _lookupNameInFlight = {};

  /// Session-cached id→name map for a reference table, in `sort_order` — so
  /// iterating entries reproduces the chip ordering the profile screens show.
  Future<Map<String, String>> lookupNameMap(String tableName) =>
      _lookupNames(tableName);

  Future<Map<String, String>> _lookupNames(String tableName) async {
    final cached = _lookupNameCache[tableName];
    if (cached != null) return cached;

    final inFlight = _lookupNameInFlight[tableName];
    if (inFlight != null) return inFlight;

    final future = _fetchLookupNames(tableName);
    _lookupNameInFlight[tableName] = future;
    try {
      final result = await future;
      // Don't cache empty results — could be a transient error or an
      // unconfigured client, and either deserves a retry on the next call.
      if (result.isNotEmpty) _lookupNameCache[tableName] = result;
      return result;
    } finally {
      _lookupNameInFlight.remove(tableName);
    }
  }

  Future<Map<String, String>> _fetchLookupNames(String tableName) async {
    final client = _client;
    if (client == null) return const {};

    try {
      final rows = await client
          .from(tableName)
          .select('id, name')
          .order('sort_order', ascending: true);
      return {
        for (final row in rows)
          if (_nullableString(row['id']) != null)
            row['id'].toString(): _string(row['name']),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> _cacheProfilesByIds(Set<String> ids) async {
    final client = _client;
    if (client == null || ids.isEmpty) return;

    final cachedIds = _cachedPeople.map((user) => user.id).toSet();
    final missingIds = ids.where((id) => !cachedIds.contains(id)).toList();
    if (missingIds.isEmpty) return;

    final rows = await client
        .from('profiles')
        .select(
          'id, email, full_name, role, avatar_url, bio, major_id, academic_year_id',
        )
        .inFilter('id', missingIds);

    final majorNames = await _lookupNames('majors');
    final yearNames = await _lookupNames('academic_years');
    final loaded = rows.map(
      (row) => _userFromProfileRow(
        Map<String, dynamic>.from(row as Map),
        majorNames: majorNames,
        yearNames: yearNames,
      ),
    );

    _cachedPeople = [
      ..._cachedPeople.where((user) => !missingIds.contains(user.id)),
      ...loaded,
    ];
  }

  User _userFromProfileRow(
    Map<String, dynamic> row, {
    required Map<String, String> majorNames,
    required Map<String, String> yearNames,
    List<String> subscribedClubIds = const [],
  }) {
    final id = row['id'].toString();
    final avatarUrl = _nullableString(row['avatar_url']);
    if (avatarUrl != null) userState.setProfilePhotoUrl(id, avatarUrl);

    final bio = _nullableString(row['bio']);
    if (bio != null) userState.setBio(id, bio);

    final majorName = majorNames[_nullableString(row['major_id'])];
    if (majorName != null) userState.setMajor(id, majorName);

    final yearName = yearNames[_nullableString(row['academic_year_id'])];
    if (yearName != null) userState.setYear(id, yearName);

    final name = _string(row['full_name']);
    final email = _string(row['email']);
    return User(
      id: id,
      name: name.isEmpty ? email : name,
      email: email,
      password: '',
      role: _string(row['role'], fallback: 'student'),
      subscribedClubIds: subscribedClubIds,
    );
  }

  void _upsertCachedUser(User user) {
    final exists = _cachedPeople.any((cached) => cached.id == user.id);
    _cachedPeople = [
      ..._cachedPeople.where((cached) => cached.id != user.id),
      user,
    ];
    if (!exists) {
      _cachedPeople.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
  }

  void _replaceCachedUserClubIds(String userId, List<String> clubIds) {
    final index = _cachedPeople.indexWhere((user) => user.id == userId);
    if (index == -1) return;

    final user = _cachedPeople[index];
    final updated = User(
      id: user.id,
      name: user.name,
      email: user.email,
      password: user.password,
      role: user.role,
      subscribedClubIds: clubIds,
      followingUserIds: user.followingUserIds,
    );
    _cachedPeople = [
      for (var i = 0; i < _cachedPeople.length; i++)
        if (i == index) updated else _cachedPeople[i],
    ];
  }

  String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

final peopleService = PeopleService();
