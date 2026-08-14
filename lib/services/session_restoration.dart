import 'dart:async';

enum SessionRestorationResult {
  restored,
  noSavedSession,
  expiredByDevicePolicy,
  timedOut,
  authenticationFailure,
  networkFailure,
}

class CachedSessionIdentity {
  const CachedSessionIdentity({
    required this.userId,
    required this.email,
    required this.isExpired,
  });

  final String userId;
  final String? email;
  final bool isExpired;
}

class RestoredClubIdentity {
  const RestoredClubIdentity({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;
}

/// Marks a confirmed invalid/revoked refresh credential. Only this failure
/// class authorizes deletion of the locally persisted Supabase session.
class InvalidPersistedSession implements Exception {
  const InvalidPersistedSession();
}

class SessionRestorationOperations {
  const SessionRestorationOperations({
    required this.cachedSession,
    required this.isDeviceSessionActive,
    required this.refreshSession,
    required this.loadPlatformAdminEmail,
    required this.loadClubId,
    required this.loadClub,
    required this.isClubBanned,
    required this.isUserBanned,
    required this.restorePlatformAdmin,
    required this.restoreClubAdmin,
    required this.restoreStudent,
    required this.clearInvalidSession,
  });

  final Future<CachedSessionIdentity?> Function() cachedSession;
  final Future<bool> Function() isDeviceSessionActive;
  final Future<CachedSessionIdentity?> Function() refreshSession;
  final Future<String?> Function(String userId) loadPlatformAdminEmail;
  final Future<String?> Function(String userId) loadClubId;
  final Future<RestoredClubIdentity?> Function(String clubId) loadClub;
  final Future<bool> Function(RestoredClubIdentity club) isClubBanned;
  final Future<bool> Function(CachedSessionIdentity identity) isUserBanned;
  final Future<void> Function(CachedSessionIdentity identity)
  restorePlatformAdmin;
  final Future<void> Function(RestoredClubIdentity club) restoreClubAdmin;
  final Future<void> Function(CachedSessionIdentity identity) restoreStudent;
  final Future<void> Function() clearInvalidSession;
}

/// Runs all refresh, role classification, profile, moderation, and Terms work
/// under one deadline. A timeout/network failure intentionally leaves the
/// persisted refresh token untouched for a later retry.
class SessionRestorationRunner {
  const SessionRestorationRunner({
    required this.operations,
    this.timeout = const Duration(seconds: 8),
    this.cleanupTimeout = const Duration(seconds: 2),
  });

  final SessionRestorationOperations operations;
  final Duration timeout;
  final Duration cleanupTimeout;

  Future<SessionRestorationResult> restore() async {
    try {
      return await _restore().timeout(timeout);
    } on TimeoutException {
      return SessionRestorationResult.timedOut;
    } on InvalidPersistedSession {
      await _boundedClear();
      return SessionRestorationResult.authenticationFailure;
    } catch (_) {
      return SessionRestorationResult.networkFailure;
    }
  }

  Future<SessionRestorationResult> _restore() async {
    var identity = await operations.cachedSession();
    if (identity == null) return SessionRestorationResult.noSavedSession;

    if (!await operations.isDeviceSessionActive()) {
      await _boundedClear();
      return SessionRestorationResult.expiredByDevicePolicy;
    }

    if (identity.isExpired) {
      identity = await operations.refreshSession();
      if (identity == null) throw const InvalidPersistedSession();
    }

    final platformAdminEmail = await operations.loadPlatformAdminEmail(
      identity.userId,
    );
    if (platformAdminEmail != null) {
      if (platformAdminEmail.trim().toLowerCase() !=
          identity.email?.trim().toLowerCase()) {
        throw const InvalidPersistedSession();
      }
      await operations.restorePlatformAdmin(identity);
      return SessionRestorationResult.restored;
    }

    final clubId = await operations.loadClubId(identity.userId);
    if (clubId != null) {
      final club = await operations.loadClub(clubId);
      if (club == null) throw const InvalidPersistedSession();
      if (await operations.isClubBanned(club)) {
        throw const InvalidPersistedSession();
      }
      await operations.restoreClubAdmin(club);
      return SessionRestorationResult.restored;
    }

    if (await operations.isUserBanned(identity)) {
      throw const InvalidPersistedSession();
    }
    await operations.restoreStudent(identity);
    return SessionRestorationResult.restored;
  }

  Future<void> _boundedClear() async {
    try {
      await operations.clearInvalidSession().timeout(cleanupTimeout);
    } catch (_) {
      // In-memory auth remains closed even if plugin/server cleanup fails.
    }
  }
}
