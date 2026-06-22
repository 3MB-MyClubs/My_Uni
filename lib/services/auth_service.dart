import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/user.dart';
import '../models/app_admin.dart';
import 'mock_data.dart';
import 'club_follow_service.dart';
import 'rsvp_store.dart';
import 'student_profile_service.dart';
import 'supabase_interaction_service.dart';
import 'supabase_config.dart';
import 'user_state.dart';

// ...existing code...

class AuthService {
  User? _currentUser;
  AppAdmin? _currentAdmin;

  User? get currentUser => _currentUser;
  AppAdmin? get currentAdmin => _currentAdmin;

  void setClubAdmin(AppAdmin admin) {
    _currentAdmin = admin;
    _currentUser = null;
  }

  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

  bool isValidStudentPassword(String password) {
    return password.length == 6 && _digitsOnly.hasMatch(password);
  }

  bool isValidClubPassword(String password) {
    return password.length == 8 && _digitsOnly.hasMatch(password);
  }

  bool isValidNumericPassword(String password) {
    return isValidStudentPassword(password);
  }

  bool login(String email, [String? password]) {
    if (email == appAdmin.email &&
        (password == null || appAdmin.password == password)) {
      _currentAdmin = appAdmin;
      return true;
    }
    final clubAdmin = clubAdmins.firstWhere(
      (a) => a.email == email && (password == null || a.password == password),
      orElse: () => AppAdmin(id: '', name: '', email: '', password: ''),
    );
    if (clubAdmin.id.isNotEmpty) {
      _currentAdmin = clubAdmin;
      return true;
    }
    final user = users.firstWhere(
      (u) => u.email == email && (password == null || u.password == password),
      orElse: () => User(
        id: '',
        name: '',
        email: '',
        password: '',
        role: '',
        subscribedClubIds: [],
      ),
    );
    if (user.id.isNotEmpty) {
      _currentUser = user;
      return true;
    }
    return false;
  }

  Future<bool> loginStudent(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();

    final isMockAdmin =
        appAdmin.email.toLowerCase() == normalizedEmail ||
        clubAdmins.any((a) => a.email.toLowerCase() == normalizedEmail);
    if (isMockAdmin) {
      return isValidClubPassword(password) && login(email, password);
    }

    if (!isValidStudentPassword(password)) return false;

    if (SupabaseConfig.isConfigured) {
      try {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: normalizedEmail,
          password: password,
        );
        final authUser = response.user;
        if (authUser == null) return false;

        StudentProfileData? profile;
        try {
          profile = await studentProfileService.fetchProfile(authUser.id);
          if (profile != null) {
            studentProfileService.applyToUserState(profile);
          }
        } catch (_) {
          profile = null;
        }

        _currentUser = User(
          id: authUser.id,
          name:
              profile?.fullName ??
              (authUser.userMetadata?['full_name'] as String?) ??
              normalizedEmail,
          email: profile?.email ?? normalizedEmail,
          password: '',
          role: profile?.role ?? 'student',
          subscribedClubIds: const [],
        );
        _currentAdmin = null;
        unawaited(_hydrateStudentState(authUser.id));
        return true;
      } on AuthException {
        return false;
      } catch (_) {
        return false;
      }
    }

    return login(email, password);
  }

  Future<void> _hydrateStudentState(String userId) async {
    try {
      final userStateResults = await Future.wait<Set<String>>([
        clubFollowService
            .fetchFollowedClubIds(userId)
            .catchError((_) => <String>{}),
        supabaseInteractionService
            .fetchLikedPostIds(userId)
            .catchError((_) => <String>{}),
        supabaseInteractionService
            .fetchRsvpEventIds(userId)
            .catchError((_) => <String>{}),
      ]);
      final followedClubIds = userStateResults[0];
      userState.replaceFollowedClubs(followedClubIds);
      for (final clubId in followedClubIds) {
        final current = supabaseClubMemberCounts[clubId] ?? 0;
        if (current < 1) supabaseClubMemberCounts[clubId] = 1;
      }
      userState.replaceLikedPosts(userStateResults[1]);
      rsvpStore.replaceForUser(userStateResults[2], userId);
    } catch (_) {
      // Auth already succeeded; interaction hydration should never block login.
    }
  }

  bool signUp(String name, String email, String password) {
    if (users.any((u) => u.email == email)) {
      return false;
    }
    if (!isValidNumericPassword(password)) {
      return false;
    }
    final newUser = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      password: password,
      role: 'student',
      subscribedClubIds: [],
    );
    users.add(newUser);
    _currentUser = newUser;
    _currentAdmin = null;
    return true;
  }

  bool hasAccountEmail(String email) {
    final normalized = email.toLowerCase();
    return users.any((u) => u.email.toLowerCase() == normalized) ||
        appAdmin.email.toLowerCase() == normalized ||
        clubAdmins.any((a) => a.email.toLowerCase() == normalized);
  }

  bool resetAccountPassword(String email, String newPassword) {
    final normalized = email.toLowerCase();
    final index = users.indexWhere((u) => u.email.toLowerCase() == normalized);
    if (index >= 0) {
      if (!isValidStudentPassword(newPassword)) return false;
      final user = users[index];
      users[index] = User(
        id: user.id,
        name: user.name,
        email: user.email,
        password: newPassword,
        role: user.role,
        subscribedClubIds: user.subscribedClubIds,
        followingUserIds: user.followingUserIds,
      );
      if (_currentUser?.id == user.id) {
        _currentUser = users[index];
      }
      return true;
    }

    if (appAdmin.email.toLowerCase() == normalized) {
      if (!isValidClubPassword(newPassword)) return false;
      appAdmin = AppAdmin(
        id: appAdmin.id,
        name: appAdmin.name,
        email: appAdmin.email,
        password: newPassword,
      );
      if (_currentAdmin?.id == appAdmin.id) {
        _currentAdmin = appAdmin;
      }
      return true;
    }

    final adminIndex = clubAdmins.indexWhere(
      (a) => a.email.toLowerCase() == normalized,
    );
    if (adminIndex >= 0) {
      if (!isValidClubPassword(newPassword)) return false;
      final admin = clubAdmins[adminIndex];
      clubAdmins[adminIndex] = AppAdmin(
        id: admin.id,
        name: admin.name,
        email: admin.email,
        password: newPassword,
      );
      if (_currentAdmin?.id == admin.id) {
        _currentAdmin = clubAdmins[adminIndex];
      }
      return true;
    }

    return false;
  }

  void logout() {
    if (SupabaseConfig.isConfigured) {
      unawaited(Supabase.instance.client.auth.signOut());
    }
    _currentUser = null;
    _currentAdmin = null;
  }
}

final authService = AuthService();
