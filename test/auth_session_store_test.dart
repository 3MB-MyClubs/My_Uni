import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/services/auth_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts a 30-day password-free session for existing installs', () async {
    expect(await authSessionStore.isSessionActive(), isTrue);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('auth_session_started_at_v1'), isNotNull);
  });

  test('rejects a session after 30 days', () async {
    final expiredAt = DateTime.now()
        .toUtc()
        .subtract(AuthSessionStore.sessionLifetime)
        .subtract(const Duration(minutes: 1));
    SharedPreferences.setMockInitialValues({
      'auth_session_started_at_v1': expiredAt.millisecondsSinceEpoch,
    });

    expect(await authSessionStore.isSessionActive(), isFalse);
  });

  test('logout marker clearing removes the session start', () async {
    await authSessionStore.startNewSession();
    await authSessionStore.clear();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('auth_session_started_at_v1'), isNull);
  });
}
