import 'dart:async';

import 'package:flutter_application_1/services/terms_acceptance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const userId = 'user-1';
  final acceptedAt = DateTime.utc(2026, 7, 18, 12);

  test('legacy account with no stored version requires acceptance', () async {
    final service = TermsAcceptanceService(
      userIdProvider: () => userId,
      rowLoader: (_) async => null,
    );

    await service.loadForCurrentUser();

    expect(service.status, TermsAcceptanceStatus.acceptanceRequired);
    expect(service.acceptedTermsVersion, isNull);
    expect(service.hasAcceptedCurrentTerms, isFalse);
  });

  test('an older stored version requires acceptance', () async {
    final service = TermsAcceptanceService(
      userIdProvider: () => userId,
      rowLoader: (_) async =>
          TermsAcceptanceRecord(version: '2025-01-01', acceptedAt: acceptedAt),
    );

    await service.loadForCurrentUser();

    expect(service.status, TermsAcceptanceStatus.acceptanceRequired);
    expect(service.acceptedTermsVersion, '2025-01-01');
    expect(service.hasAcceptedCurrentTerms, isFalse);
  });

  test('a matching backend version grants access on another device', () async {
    TermsAcceptanceRecord? backendRecord;

    TermsAcceptanceService device() => TermsAcceptanceService(
      userIdProvider: () => userId,
      rowLoader: (_) async => backendRecord,
      recorder: (_, version) async {
        backendRecord = TermsAcceptanceRecord(
          version: version,
          acceptedAt: acceptedAt,
        );
        return backendRecord!;
      },
    );

    final firstDevice = device();
    await firstDevice.loadForCurrentUser();
    expect(firstDevice.hasAcceptedCurrentTerms, isFalse);

    await firstDevice.acceptCurrentTerms();
    expect(firstDevice.hasAcceptedCurrentTerms, isTrue);
    expect(firstDevice.termsAcceptedAt, acceptedAt);

    final secondDevice = device();
    await secondDevice.loadForCurrentUser();
    expect(secondDevice.hasAcceptedCurrentTerms, isTrue);
    expect(
      secondDevice.acceptedTermsVersion,
      TermsAcceptanceService.currentVersion,
    );
  });

  test('failed backend save keeps the session gated', () async {
    final service = TermsAcceptanceService(
      userIdProvider: () => userId,
      rowLoader: (_) async => null,
      recorder: (_, _) async => throw Exception('network unavailable'),
    );
    await service.loadForCurrentUser();

    await expectLater(service.acceptCurrentTerms(), throwsException);

    expect(service.status, TermsAcceptanceStatus.error);
    expect(service.hasAcceptedCurrentTerms, isFalse);
    expect(service.lastError, isNotNull);
  });

  test('a late response from another account cannot grant access', () async {
    var activeUserId = 'user-1';
    final firstLoad = Completer<TermsAcceptanceRecord?>();
    final secondLoad = Completer<TermsAcceptanceRecord?>();
    final service = TermsAcceptanceService(
      userIdProvider: () => activeUserId,
      rowLoader: (requestedUserId) =>
          requestedUserId == 'user-1' ? firstLoad.future : secondLoad.future,
    );

    final firstRequest = service.loadForCurrentUser();
    activeUserId = 'user-2';
    final secondRequest = service.loadForCurrentUser();

    firstLoad.complete(
      TermsAcceptanceRecord(
        version: TermsAcceptanceService.currentVersion,
        acceptedAt: acceptedAt,
      ),
    );
    await firstRequest;
    expect(service.hasAcceptedCurrentTerms, isFalse);

    secondLoad.complete(null);
    await secondRequest;
    expect(service.status, TermsAcceptanceStatus.acceptanceRequired);
    expect(service.hasAcceptedCurrentTerms, isFalse);
  });

  test('acceptance requires an authenticated account', () async {
    final service = TermsAcceptanceService(userIdProvider: () => null);

    await expectLater(service.acceptCurrentTerms(), throwsA(isA<StateError>()));

    expect(service.hasAcceptedCurrentTerms, isFalse);
  });
}
