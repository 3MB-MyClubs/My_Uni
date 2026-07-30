import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/services/terms_acceptance_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('accept stores the current Terms version on this device', () async {
    final service = TermsAcceptanceService(clientProvider: () => null);

    await service.initialize();
    expect(service.hasAcceptedCurrentTerms, isFalse);

    await service.accept();

    expect(service.hasAcceptedCurrentTerms, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'accepted_terms_version',
      ),
      TermsAcceptanceService.currentVersion,
    );
  });

  test(
    'signup cannot claim durable acceptance without a signed-in user',
    () async {
      final service = TermsAcceptanceService(clientProvider: () => null);

      await expectLater(
        service.accept(requireAuthenticatedRecord: true),
        throwsStateError,
      );

      expect(service.hasAcceptedCurrentTerms, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'accepted_terms_version',
        ),
        isNull,
      );
    },
  );
}
