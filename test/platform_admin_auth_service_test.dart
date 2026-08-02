import 'package:flutter_application_1/services/platform_admin_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'platform admin login rejects every other email before authentication',
    () async {
      const service = PlatformAdminAuthService();

      final result = await service.login(
        email: 'club@ku.edu.tr',
        passcode: '12345678',
      );

      expect(result.success, isFalse);
      expect(result.errorCode, PlatformAdminAuthError.invalidCredentials);
    },
  );

  test(
    'platform admin login requires the existing 8 digit passcode format',
    () async {
      const service = PlatformAdminAuthService();

      final result = await service.login(
        email: platformAdminEmail,
        passcode: '123456',
      );

      expect(result.success, isFalse);
      expect(result.errorCode, PlatformAdminAuthError.invalidPasscodeFormat);
    },
  );
}
