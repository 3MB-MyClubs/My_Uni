import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/calendar/services/calendar_service.dart';

void main() {
  test('initial calendar permission question is remembered app-wide', () async {
    SharedPreferences.setMockInitialValues({});
    final firstSession = CalendarService();

    expect(await firstSession.hasShownInitialPermissionPrompt(), isFalse);

    await firstSession.markInitialPermissionPromptShown();

    final laterLogin = CalendarService();
    expect(await laterLogin.hasShownInitialPermissionPrompt(), isTrue);
  });
}
