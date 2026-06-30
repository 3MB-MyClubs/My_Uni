import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'user_state.dart';

class StudentProfileData {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final String? majorId;
  final String? majorName;
  final String? academicYearId;
  final String? academicYearName;
  final List<String> interestIds;
  final List<String> interestNames;
  final List<String> doubleMajorIds;
  final List<String> doubleMajorNames;
  final List<String> minorIds;
  final List<String> minorNames;

  const StudentProfileData({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.bio,
    this.majorId,
    this.majorName,
    this.academicYearId,
    this.academicYearName,
    this.interestIds = const [],
    this.interestNames = const [],
    this.doubleMajorIds = const [],
    this.doubleMajorNames = const [],
    this.minorIds = const [],
    this.minorNames = const [],
  });
}

class ProfileLookupItem {
  final String id;
  final String name;

  const ProfileLookupItem({required this.id, required this.name});
}

class UpdateStudentProfileInput {
  final String userId;
  final String fullName;
  final String bio;
  final String? majorId;
  final String? academicYearId;
  final List<String> interestIds;
  final List<String> doubleMajorIds;
  final List<String> minorIds;

  const UpdateStudentProfileInput({
    required this.userId,
    required this.fullName,
    required this.bio,
    required this.majorId,
    required this.academicYearId,
    required this.interestIds,
    required this.doubleMajorIds,
    required this.minorIds,
  });
}

class StudentProfileService {
  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<StudentProfileData?> fetchCurrentProfile() async {
    final userId = _client?.auth.currentUser?.id;
    if (userId == null) return null;
    return fetchProfile(userId);
  }

  Future<StudentProfileData?> fetchProfile(String userId) async {
    final client = _client;
    if (client == null) return null;

    final profile = await client
        .from('profiles')
        .select(
          'id, email, full_name, role, avatar_url, bio, major_id, academic_year_id',
        )
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) return null;

    final majorId = _nullableString(profile['major_id']);
    final academicYearId = _nullableString(profile['academic_year_id']);

    final results = await Future.wait([
      _fetchLookupName('majors', majorId),
      _fetchLookupName('academic_years', academicYearId),
      _fetchStudentInterestItems(userId),
      _fetchProfileMajorItems('profile_double_majors', userId),
      _fetchProfileMajorItems('profile_minors', userId),
    ]);
    final interests = results[2] as List<ProfileLookupItem>;
    final doubleMajors = results[3] as List<ProfileLookupItem>;
    final minors = results[4] as List<ProfileLookupItem>;

    return StudentProfileData(
      id: profile['id'].toString(),
      email: _nullableString(profile['email']) ?? '',
      fullName: _nullableString(profile['full_name']) ?? '',
      role: _nullableString(profile['role']) ?? 'student',
      avatarUrl: _nullableString(profile['avatar_url']),
      bio: _nullableString(profile['bio']),
      majorId: majorId,
      majorName: results[0] as String?,
      academicYearId: academicYearId,
      academicYearName: results[1] as String?,
      interestIds: interests.map((item) => item.id).toList(),
      interestNames: interests.map((item) => item.name).toList(),
      doubleMajorIds: doubleMajors.map((item) => item.id).toList(),
      doubleMajorNames: doubleMajors.map((item) => item.name).toList(),
      minorIds: minors.map((item) => item.id).toList(),
      minorNames: minors.map((item) => item.name).toList(),
    );
  }

  Future<List<ProfileLookupItem>> fetchMajors() {
    return _fetchLookupItems('majors');
  }

  Future<List<ProfileLookupItem>> fetchAcademicYears() {
    return _fetchLookupItems('academic_years');
  }

  Future<List<ProfileLookupItem>> fetchInterests() {
    return _fetchLookupItems('interests');
  }

  Future<StudentProfileData?> updateProfile(
    UpdateStudentProfileInput input,
  ) async {
    final client = _client;
    if (client == null) return null;

    await client
        .from('profiles')
        .update({
          'full_name': input.fullName,
          'bio': input.bio.trim().isEmpty ? null : input.bio.trim(),
          'major_id': input.majorId,
          'academic_year_id': input.academicYearId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', input.userId);

    await Future.wait([
      _replaceJoinRows(
        tableName: 'student_interests',
        userColumn: 'user_id',
        userId: input.userId,
        targetColumn: 'interest_id',
        targetIds: input.interestIds,
      ),
      _replaceJoinRows(
        tableName: 'profile_double_majors',
        userColumn: 'profile_id',
        userId: input.userId,
        targetColumn: 'major_id',
        targetIds: input.doubleMajorIds,
        optional: true,
      ),
      _replaceJoinRows(
        tableName: 'profile_minors',
        userColumn: 'profile_id',
        userId: input.userId,
        targetColumn: 'major_id',
        targetIds: input.minorIds,
        optional: true,
      ),
    ]);

    final profile = await fetchProfile(input.userId);
    if (profile != null) applyToUserState(profile);
    return profile;
  }

  Future<StudentProfileData?> updateFullName({
    required String userId,
    required String fullName,
  }) async {
    final client = _client;
    final value = fullName.trim();
    if (client == null || userId.isEmpty || value.isEmpty) return null;

    await client
        .from('profiles')
        .update({
          'full_name': value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);

    final profile = await fetchProfile(userId);
    if (profile != null) applyToUserState(profile);
    return profile;
  }

  Future<String?> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    final client = _client;
    if (client == null || userId.isEmpty) return null;

    final path = '$userId/avatar.jpg';
    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final publicUrl = client.storage.from('avatars').getPublicUrl(path);

    await client
        .from('profiles')
        .update({
          'avatar_url': publicUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);

    userState.setProfilePhotoUrl(userId, publicUrl);
    return publicUrl;
  }

  Future<void> removeAvatar(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return;

    await client
        .from('profiles')
        .update({
          'avatar_url': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);

    try {
      final objects = await client.storage.from('avatars').list(path: userId);
      final paths = objects.map((object) => '$userId/${object.name}').toList();
      if (paths.isNotEmpty) await client.storage.from('avatars').remove(paths);
    } catch (_) {
      // Non-critical: the profile no longer points at the old avatar.
    }

    userState.removeProfilePhoto(userId);
  }

  Future<void> hydrateUserState(String userId) async {
    final profile = await fetchProfile(userId);
    if (profile == null) return;
    applyToUserState(profile);
  }

  void applyToUserState(StudentProfileData profile) {
    final userId = profile.id;
    userState.setBio(userId, profile.bio ?? '');
    userState.setMajor(userId, profile.majorName ?? '');
    userState.setYear(userId, profile.academicYearName ?? '');
    userState.setInterests(userId, profile.interestNames);
    userState.setDoubleMajors(userId, profile.doubleMajorNames);
    userState.setMinors(userId, profile.minorNames);
    if (profile.avatarUrl != null) {
      userState.setProfilePhotoUrl(userId, profile.avatarUrl!);
    }
  }

  Future<List<ProfileLookupItem>> _fetchLookupItems(String tableName) async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from(tableName)
          .select('id, name')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return rows
          .map(
            (row) => ProfileLookupItem(
              id: row['id'].toString(),
              name: row['name'].toString(),
            ),
          )
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _fetchLookupName(String tableName, String? id) async {
    final client = _client;
    if (client == null || id == null) return null;

    try {
      final row = await client
          .from(tableName)
          .select('name')
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return _nullableString(row['name']);
    } catch (_) {
      return null;
    }
  }

  Future<List<ProfileLookupItem>> _fetchStudentInterestItems(
    String userId,
  ) async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('student_interests')
          .select('interest_id')
          .eq('user_id', userId);

      final interestIds = rows
          .map((row) => _nullableString(row['interest_id']))
          .whereType<String>()
          .toList();

      return _fetchLookupItemsByIds('interests', interestIds);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ProfileLookupItem>> _fetchProfileMajorItems(
    String tableName,
    String userId,
  ) async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from(tableName)
          .select('major_id')
          .eq('profile_id', userId);

      final majorIds = rows
          .map((row) => _nullableString(row['major_id']))
          .whereType<String>()
          .toList();

      return _fetchLookupItemsByIds('majors', majorIds);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ProfileLookupItem>> _fetchLookupItemsByIds(
    String tableName,
    List<String> ids,
  ) async {
    final client = _client;
    if (client == null || ids.isEmpty) return const [];

    final rows = await client
        .from(tableName)
        .select('id, name')
        .inFilter('id', ids)
        .order('sort_order', ascending: true);

    return rows
        .map(
          (row) => ProfileLookupItem(
            id: row['id'].toString(),
            name: row['name'].toString(),
          ),
        )
        .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
        .toList();
  }

  Future<void> _replaceJoinRows({
    required String tableName,
    required String userColumn,
    required String userId,
    required String targetColumn,
    required List<String> targetIds,
    bool optional = false,
  }) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from(tableName).delete().eq(userColumn, userId);

      final rows = targetIds
          .toSet()
          .map((id) => {userColumn: userId, targetColumn: id})
          .toList();
      if (rows.isEmpty) return;

      await client.from(tableName).insert(rows);
    } catch (_) {
      if (!optional) rethrow;
    }
  }

  String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

final studentProfileService = StudentProfileService();
