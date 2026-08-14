import 'dart:async';

import 'package:flutter_application_1/services/session_restoration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const deadline = Duration(milliseconds: 10);
  const active = CachedSessionIdentity(
    userId: 'user-1',
    email: 'user@example.test',
    isExpired: false,
  );
  const expired = CachedSessionIdentity(
    userId: 'user-1',
    email: 'user@example.test',
    isExpired: true,
  );

  Future<Never> never<T>() => Completer<Never>().future;

  SessionRestorationOperations operations({
    Future<CachedSessionIdentity?> Function()? cachedSession,
    Future<CachedSessionIdentity?> Function()? refreshSession,
    Future<String?> Function(String)? loadPlatformAdminEmail,
    Future<String?> Function(String)? loadClubId,
    Future<RestoredClubIdentity?> Function(String)? loadClub,
    Future<void> Function(CachedSessionIdentity)? restoreStudent,
    Future<void> Function()? clearInvalidSession,
  }) {
    return SessionRestorationOperations(
      cachedSession: cachedSession ?? () async => active,
      isDeviceSessionActive: () async => true,
      refreshSession: refreshSession ?? () async => active,
      loadPlatformAdminEmail: loadPlatformAdminEmail ?? (_) async => null,
      loadClubId: loadClubId ?? (_) async => null,
      loadClub:
          loadClub ??
          (id) async => RestoredClubIdentity(
            id: id,
            name: 'Club',
            email: 'club@example.test',
          ),
      isClubBanned: (_) async => false,
      isUserBanned: (_) async => false,
      restorePlatformAdmin: (_) async {},
      restoreClubAdmin: (_) async {},
      restoreStudent: restoreStudent ?? (_) async {},
      clearInvalidSession: clearInvalidSession ?? () async {},
    );
  }

  Future<SessionRestorationResult> restore(
    SessionRestorationOperations value,
  ) => SessionRestorationRunner(operations: value, timeout: deadline).restore();

  test('refreshSession that never completes exits by the deadline', () async {
    var clears = 0;
    final result = await restore(
      operations(
        cachedSession: () async => expired,
        refreshSession: never,
        clearInvalidSession: () async => clears++,
      ),
    );
    expect(result, SessionRestorationResult.timedOut);
    expect(clears, 0, reason: 'temporary timeout must preserve refresh token');
  });

  test('app_admins request that never completes exits by deadline', () async {
    final result = await restore(
      operations(loadPlatformAdminEmail: (_) => never()),
    );
    expect(result, SessionRestorationResult.timedOut);
  });

  test('club_auth_accounts request that never completes exits', () async {
    final result = await restore(operations(loadClubId: (_) => never()));
    expect(result, SessionRestorationResult.timedOut);
  });

  test('clubs request that never completes exits', () async {
    final result = await restore(
      operations(loadClubId: (_) async => 'club-1', loadClub: (_) => never()),
    );
    expect(result, SessionRestorationResult.timedOut);
  });

  test('profiles restoration that never completes exits', () async {
    final result = await restore(operations(restoreStudent: (_) => never()));
    expect(result, SessionRestorationResult.timedOut);
  });

  test(
    'unreachable Supabase session recovery exits without clearing',
    () async {
      var clears = 0;
      final result = await restore(
        operations(
          cachedSession: never,
          clearInvalidSession: () async => clears++,
        ),
      );
      expect(result, SessionRestorationResult.timedOut);
      expect(clears, 0);
    },
  );

  test('expired access session refreshes safely', () async {
    var refreshes = 0;
    final result = await restore(
      operations(
        cachedSession: () async => expired,
        refreshSession: () async {
          refreshes++;
          return active;
        },
      ),
    );
    expect(result, SessionRestorationResult.restored);
    expect(refreshes, 1);
  });

  test('network loss during restoration preserves persisted session', () async {
    var clears = 0;
    final result = await restore(
      operations(
        loadPlatformAdminEmail: (_) async => throw Exception('offline'),
        clearInvalidSession: () async => clears++,
      ),
    );
    expect(result, SessionRestorationResult.networkFailure);
    expect(clears, 0);
  });

  test(
    'clean logged-out install does not perform network classification',
    () async {
      var networkCalls = 0;
      final result = await restore(
        operations(
          cachedSession: () async => null,
          loadPlatformAdminEmail: (_) async {
            networkCalls++;
            return null;
          },
        ),
      );
      expect(result, SessionRestorationResult.noSavedSession);
      expect(networkCalls, 0);
    },
  );

  test('confirmed invalid refresh token is cleared', () async {
    var clears = 0;
    final result = await restore(
      operations(
        cachedSession: () async => expired,
        refreshSession: () async => throw const InvalidPersistedSession(),
        clearInvalidSession: () async => clears++,
      ),
    );
    expect(result, SessionRestorationResult.authenticationFailure);
    expect(clears, 1);
  });
}
