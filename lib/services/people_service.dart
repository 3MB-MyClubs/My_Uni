import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/user.dart';
import 'supabase_config.dart';
import 'user_state.dart';

class PeopleService {
  List<User> _cachedPeople = const [];
  Set<String> _cachedFollowerIds = const {};
  final Map<String, Set<String>> _followersByUserId = {};
  final Map<String, Set<String>> _followingByUserId = {};

  List<User> get cachedPeople => _cachedPeople;
  Set<String> get cachedFollowerIds => _cachedFollowerIds;

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
    final loaded = rows.map((row) {
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
        subscribedClubIds: const [],
      );
    });

    _cachedPeople = [
      ..._cachedPeople.where((user) => !missingIds.contains(user.id)),
      ...loaded,
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
