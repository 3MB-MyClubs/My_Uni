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

  Future<List<User>> fetchPeople({String query = '', String? excludeId}) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('profiles')
        .select(
          'id, email, full_name, role, avatar_url, bio, major_id, academic_year_id',
        )
        .eq('role', 'student')
        .order('full_name', ascending: true)
        .limit(100);

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

  Future<void> hydrateFollowing(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return;

    final followingRows = await client
        .from('profile_follows')
        .select('following_id')
        .eq('follower_id', userId);

    userState.replaceFollowedUsers(
      followingRows.map((row) => row['following_id'].toString()),
    );
    _followingByUserId[userId] = followingRows
        .map((row) => row['following_id'].toString())
        .toSet();

    final followerRows = await client
        .from('profile_follows')
        .select('follower_id')
        .eq('following_id', userId);

    _cachedFollowerIds = followerRows
        .map((row) => row['follower_id'].toString())
        .toSet();
    _followersByUserId[userId] = _cachedFollowerIds;
  }

  Future<void> hydrateConnectionsFor(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return;
    if (_cachedPeople.isEmpty) await fetchPeople();

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

    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == userId) {
      _cachedFollowerIds = _followersByUserId[userId] ?? const {};
      userState.replaceFollowedUsers(_followingByUserId[userId] ?? const {});
    }
  }

  Future<void> hydrateProfileDetailsFor(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return;

    final majorNames = await _lookupNames('majors');
    final yearNames = await _lookupNames('academic_years');

    try {
      final profile = await client
          .from('profiles')
          .select(
            'id, email, full_name, role, avatar_url, bio, major_id, academic_year_id',
          )
          .eq('id', userId)
          .maybeSingle();
      if (profile != null) {
        final user = _userFromProfileRow(
          Map<String, dynamic>.from(profile),
          majorNames: majorNames,
          yearNames: yearNames,
          subscribedClubIds: _clubIdsByUserId[userId]?.toList() ?? const [],
        );
        _upsertCachedUser(user);
      }
    } catch (_) {
      // Keep whatever profile details are already cached locally.
    }

    try {
      final interestRows = await client
          .from('student_interests')
          .select('interest_id')
          .eq('user_id', userId);
      final interestIds = interestRows
          .map((row) => _nullableString(row['interest_id']))
          .whereType<String>()
          .toList();
      final interestNames = await _lookupNamesByIds('interests', interestIds);
      userState.setInterests(userId, interestNames);
    } catch (_) {
      // Missing permissions/tables should not block opening a profile.
    }

    try {
      final clubRows = await client
          .from('club_followers')
          .select('club_id')
          .eq('profile_id', userId);
      final clubIds = clubRows
          .map((row) => _nullableString(row['club_id']))
          .whereType<String>()
          .toSet();
      _clubIdsByUserId[userId] = clubIds;
      _replaceCachedUserClubIds(userId, clubIds.toList());
    } catch (_) {
      // Fall back to static/mock subscribedClubIds.
    }
  }

  Future<List<User>> fetchClubMembers(String clubId) async {
    final client = _client;
    if (client == null || clubId.isEmpty) return const [];

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

  Future<void> refreshPeopleDirectory({String? excludeId}) async {
    final currentUserId = excludeId ?? '';
    await hydrateFollowing(currentUserId);
    await fetchPeople(excludeId: currentUserId.isEmpty ? null : currentUserId);
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

  List<User> followersFor(String userId) {
    return peopleByIds(_followersByUserId[userId] ?? const {});
  }

  List<User> followingFor(String userId) {
    return peopleByIds(_followingByUserId[userId] ?? const {});
  }

  Future<User> userFromProfileMap(Map<dynamic, dynamic> profile) async {
    final majorNames = await _lookupNames('majors');
    final yearNames = await _lookupNames('academic_years');
    final user = _userFromProfileRow(
      Map<String, dynamic>.from(profile),
      majorNames: majorNames,
      yearNames: yearNames,
    );
    _upsertCachedUser(user);
    return user;
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
      final existing = await client
          .from('profile_follows')
          .select('id')
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .limit(1);
      if (existing.isEmpty) {
        await client.from('profile_follows').insert({
          'follower_id': followerId,
          'following_id': followingId,
        });
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

  Future<Map<String, String>> _lookupNames(String tableName) async {
    final client = _client;
    if (client == null) return const {};

    try {
      final rows = await client.from(tableName).select('id, name');
      return {
        for (final row in rows)
          if (_nullableString(row['id']) != null)
            row['id'].toString(): _string(row['name']),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<List<String>> _lookupNamesByIds(
    String tableName,
    List<String> ids,
  ) async {
    final client = _client;
    if (client == null || ids.isEmpty) return const [];

    try {
      final rows = await client
          .from(tableName)
          .select('id, name')
          .inFilter('id', ids);
      final byId = {
        for (final row in rows)
          if (_nullableString(row['id']) != null)
            row['id'].toString(): _string(row['name']),
      };
      return [
        for (final id in ids)
          if ((byId[id] ?? '').isNotEmpty) byId[id]!,
      ];
    } catch (_) {
      return const [];
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
