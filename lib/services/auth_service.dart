import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart'
    as supabase_auth
    show User;

import '../models/user.dart';
import '../models/app_admin.dart';
import 'mock_data.dart';
import 'club_follow_service.dart';
import 'rsvp_store.dart';
import 'student_profile_service.dart';
import 'supabase_interaction_service.dart';
import 'supabase_config.dart';
import 'push_notification_service.dart';
import 'auth_session_store.dart';
import 'user_state.dart';
import 'app_presence_service.dart';
import 'lazy_content_loader.dart';
import 'people_service.dart';
import 'terms_acceptance_service.dart';

// ...existing code...

class AuthService {
  User? _currentUser;
  AppAdmin? _currentAdmin;

  User? get currentUser => _currentUser;
  AppAdmin? get currentAdmin => _currentAdmin;

  bool get isStudentSession =>
      _currentAdmin == null &&
      _currentUser != null &&
      _currentUser!.role == 'student';

  void setClubAdmin(AppAdmin admin) {
    lazyContentLoader.invalidate();
    _currentAdmin = admin;
    _currentUser = null;
    _syncTermsAcceptance();
  }

  void _syncTermsAcceptance() {
    unawaited(
      termsAcceptanceService.syncForCurrentUser().catchError((_) {
        // Retry on the next login. Terms synchronization should not turn a
        // valid authenticated session into a failed login.
      }),
    );
  }

  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

  bool hasNoAdjacentRepeatedDigits(String password) {
    for (var i = 1; i < password.length; i++) {
      if (password.codeUnitAt(i) == password.codeUnitAt(i - 1)) {
        return false;
      }
    }
    return true;
  }

  bool hasNoAdjacentSequentialDigits(String password) {
    for (var i = 1; i < password.length; i++) {
      final current = password.codeUnitAt(i);
      final previous = password.codeUnitAt(i - 1);
      if ((current - previous).abs() == 1) {
        return false;
      }
    }
    return true;
  }

  bool isValidStudentPassword(String password) {
    return password.length == 6 && _digitsOnly.hasMatch(password);
  }

  bool isValidNewStudentPassword(String password) {
    return password.length == 6 &&
        _digitsOnly.hasMatch(password) &&
        hasNoAdjacentRepeatedDigits(password) &&
        hasNoAdjacentSequentialDigits(password);
  }

  bool isValidClubPassword(String password) {
    return password.length == 8 && _digitsOnly.hasMatch(password);
  }

  bool isValidNumericPassword(String password) {
    return isValidNewStudentPassword(password);
  }

  bool login(String email, String password) {
    if (appAdmin.id.isNotEmpty &&
        email == appAdmin.email &&
        appAdmin.password == password) {
      _currentAdmin = appAdmin;
      return true;
    }
    final clubAdmin = clubAdmins.firstWhere(
      (a) => a.email == email && a.password == password,
      orElse: () => AppAdmin(id: '', name: '', email: '', password: ''),
    );
    if (clubAdmin.id.isNotEmpty) {
      _currentAdmin = clubAdmin;
      return true;
    }
    final user = users.firstWhere(
      (u) => u.email == email && u.password == password,
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
        (appAdmin.id.isNotEmpty &&
            appAdmin.email.toLowerCase() == normalizedEmail) ||
        clubAdmins.any((a) => a.email.toLowerCase() == normalizedEmail);
    if (SupabaseConfig.canUseMockAuth && isMockAdmin) {
      return isValidClubPassword(password) && login(email, password);
    }

    if (!isValidStudentPassword(password)) return false;
    if (SupabaseConfig.canUseMockAuth &&
        users.any(
          (user) =>
              user.email.toLowerCase() == normalizedEmail &&
              user.password == password,
        )) {
      return login(email, password);
    }

    if (SupabaseConfig.isConfigured) {
      try {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: normalizedEmail,
          password: password,
        );
        final authUser = response.user;
        if (authUser == null) return false;
        await authSessionStore.startNewSession();
        lazyContentLoader.invalidate();

        // Login blocks only on the single `profiles` row (name/email/role/
        // avatar/bio); interests, majors and minors hydrate in the background
        // right after — the profile tab self-heals via its userState listener.
        Map<String, dynamic>? profileRow;
        try {
          profileRow = await studentProfileService.fetchProfileCore(
            authUser.id,
          );
        } catch (_) {
          profileRow = null;
        }

        String? rowString(String key) {
          final text = profileRow?[key]?.toString().trim() ?? '';
          return text.isEmpty ? null : text;
        }

        _currentUser = User(
          id: authUser.id,
          name:
              rowString('full_name') ??
              (authUser.userMetadata?['full_name'] as String?) ??
              normalizedEmail,
          email: rowString('email') ?? normalizedEmail,
          password: '',
          role: rowString('role') ?? 'student',
          subscribedClubIds: const [],
        );
        unawaited(peopleService.registerLocalUser(_currentUser!));
        _currentAdmin = null;
        if (profileRow != null) {
          studentProfileService.applyCoreToUserState(profileRow);
          unawaited(studentProfileService.hydrateDetails(profileRow));
        }
        unawaited(_hydrateStudentState(authUser.id));
        _syncTermsAcceptance();
        return true;
      } on AuthException {
        return false;
      } catch (_) {
        return false;
      }
    }

    return SupabaseConfig.canUseMockAuth && login(email, password);
  }

  /// Rebuilds the app's in-memory account from Supabase's persisted session.
  ///
  /// Supabase Flutter restores the access/refresh token pair during
  /// [Supabase.initialize]. The app still needs to reconstruct [_currentUser]
  /// or [_currentAdmin], otherwise the root router incorrectly shows Login.
  Future<bool> restorePersistedSession() async {
    if (!SupabaseConfig.isConfigured) return false;

    try {
      final client = Supabase.instance.client;
      var session = client.auth.currentSession;
      if (session == null) return false;

      if (!await authSessionStore.isSessionActive()) {
        await client.auth.signOut();
        return false;
      }

      // Supabase.initialize starts recovery in the background. Explicitly
      // finish the refresh here when the cached access token is already stale,
      // so the account lookup below never races an expired JWT.
      if (session.isExpired) {
        session = (await client.auth.refreshSession()).session;
      }
      final authUser = session?.user;
      if (authUser == null) {
        await _clearPersistedSession(client);
        return false;
      }

      final accountRows = await client
          .from('club_auth_accounts')
          .select('club_id')
          .eq('auth_user_id', authUser.id)
          .limit(1);
      final accounts = accountRows as List;
      if (accounts.isNotEmpty) {
        final clubId = (accounts.first as Map)['club_id']?.toString() ?? '';
        final clubRows = await client
            .from('clubs')
            .select('id, name, email')
            .eq('id', clubId)
            .limit(1);
        final linkedClubs = clubRows as List;
        if (clubId.isEmpty || linkedClubs.isEmpty) {
          await _clearPersistedSession(client);
          return false;
        }

        final club = Map<String, dynamic>.from(linkedClubs.first as Map);
        setClubAdmin(
          AppAdmin(
            id: clubId,
            name: club['name']?.toString() ?? '',
            email: club['email']?.toString() ?? authUser.email ?? '',
            password: '',
          ),
        );
        return true;
      }

      await _setStudentFromAuthUser(authUser);
      return true;
    } on AuthException {
      await _clearPersistedSession();
      return false;
    } catch (_) {
      // A temporary profile/network failure should not destroy a refresh token
      // that may still be valid. Supabase will retry token refresh on resume.
      return false;
    }
  }

  Future<void> _setStudentFromAuthUser(supabase_auth.User authUser) async {
    lazyContentLoader.invalidate();
    Map<String, dynamic>? profileRow;
    try {
      profileRow = await studentProfileService.fetchProfileCore(authUser.id);
    } catch (_) {
      profileRow = null;
    }

    String? rowString(String key) {
      final text = profileRow?[key]?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    final email = rowString('email') ?? authUser.email?.toString() ?? '';
    _currentUser = User(
      id: authUser.id.toString(),
      name:
          rowString('full_name') ??
          (authUser.userMetadata?['full_name'] as String?) ??
          email,
      email: email,
      password: '',
      role: rowString('role') ?? 'student',
      subscribedClubIds: const [],
    );
    _currentAdmin = null;
    unawaited(peopleService.registerLocalUser(_currentUser!));
    if (profileRow != null) {
      studentProfileService.applyCoreToUserState(profileRow);
      unawaited(studentProfileService.hydrateDetails(profileRow));
    }
    unawaited(_hydrateStudentState(authUser.id.toString()));
    _syncTermsAcceptance();
  }

  Future<void> _clearPersistedSession([SupabaseClient? client]) async {
    _currentUser = null;
    _currentAdmin = null;
    try {
      await authSessionStore.clear();
    } catch (_) {
      // Local Supabase token deletion must still run if prefs are unavailable.
    }
    try {
      await (client ?? Supabase.instance.client).auth.signOut();
    } catch (_) {
      // signOut removes the local session before attempting server revocation.
    }
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
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      email: email,
      password: password,
      role: 'student',
      subscribedClubIds: [],
    );
    users.add(newUser);
    unawaited(peopleService.registerLocalUser(newUser));
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
      if (!isValidNewStudentPassword(newPassword)) return false;
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

  void updateCurrentUserName(String name) {
    final user = _currentUser;
    if (user == null) return;

    _currentUser = User(
      id: user.id,
      name: name,
      email: user.email,
      password: user.password,
      role: user.role,
      subscribedClubIds: user.subscribedClubIds,
      followingUserIds: user.followingUserIds,
    );

    final index = users.indexWhere((u) => u.id == user.id);
    if (index >= 0) {
      final existing = users[index];
      users[index] = User(
        id: existing.id,
        name: name,
        email: existing.email,
        password: existing.password,
        role: existing.role,
        subscribedClubIds: existing.subscribedClubIds,
        followingUserIds: existing.followingUserIds,
      );
    }
  }

  Future<void> logout() async {
    final presenceStop = appPresenceService.stop();
    lazyContentLoader.invalidate();
    _currentUser = null;
    _currentAdmin = null;

    try {
      await authSessionStore.clear();
    } catch (_) {
      // Token deletion below must still run if preferences are unavailable.
    }
    if (SupabaseConfig.isConfigured) {
      try {
        await pushNotificationService.unregisterCurrentDevice();
      } catch (_) {
        // Device cleanup must never prevent local credential deletion.
      }
      try {
        // signOut removes the persisted local token before attempting remote
        // revocation, so logout remains reliable while offline.
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // Tests may exercise logout without bootstrapping Supabase.
      }
    }
    await presenceStop;
  }
}

final authService = AuthService();
