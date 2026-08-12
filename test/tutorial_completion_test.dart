import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/onboarding/onboarding_service.dart';

void main() {
  test('automatic completion follows a student across devices', () async {
    final rows = <String, bool>{};

    OnboardingService device() => OnboardingService(
      completionLoader: (profileId) async => rows[profileId],
      completionWriter: (profileId) async => rows[profileId] = true,
    );

    final firstDevice = device();
    await firstDevice.loadFor('student-profile');
    expect(firstDevice.isComplete('student-profile'), isFalse);

    await firstDevice.finish(
      'student-profile',
      source: TutorialLaunchSource.automatic,
    );

    final secondDevice = device();
    await secondDevice.loadFor('student-profile');
    expect(secondDevice.isComplete('student-profile'), isTrue);
  });

  test('student and club profile completion stays isolated', () async {
    final rows = <String, bool>{};
    final service = OnboardingService(
      completionLoader: (profileId) async => rows[profileId],
      completionWriter: (profileId) async => rows[profileId] = true,
    );

    await service.loadFor('student-profile');
    await service.loadFor('club-profile');
    await service.finish(
      'student-profile',
      source: TutorialLaunchSource.automatic,
    );

    expect(service.isComplete('student-profile'), isTrue);
    expect(service.isComplete('club-profile'), isFalse);
  });

  test('repeated manual replays never mutate backend completion', () async {
    var writes = 0;
    final service = OnboardingService(
      completionLoader: (_) async => true,
      completionWriter: (_) async => writes++,
    );
    await service.loadFor('club-profile');

    service.requestReplay();
    await service.finish('club-profile', source: TutorialLaunchSource.manual);
    service.requestReplay();
    await service.finish('club-profile', source: TutorialLaunchSource.manual);

    expect(service.replayRequests.value, 2);
    expect(writes, 0);
    expect(service.isComplete('club-profile'), isTrue);
  });

  test('missing and null backend fields are safely incomplete', () async {
    final service = OnboardingService(
      completionLoader: (_) async => null,
      completionWriter: (_) async {},
    );

    await service.loadFor('legacy-profile');

    expect(service.isComplete('legacy-profile'), isFalse);
  });

  test('failed backend reads fail closed instead of launching twice', () async {
    final service = OnboardingService(
      completionLoader: (_) async => throw Exception('offline'),
      completionWriter: (_) async {},
    );

    await service.loadFor('returning-profile');

    expect(service.isComplete('returning-profile'), isTrue);
  });

  test('failed completion writes are not treated as persisted', () async {
    final service = OnboardingService(
      completionLoader: (_) async => false,
      completionWriter: (_) async => throw Exception('offline'),
    );
    await service.loadFor('student-profile');

    await expectLater(
      service.finish('student-profile', source: TutorialLaunchSource.automatic),
      throwsException,
    );

    expect(service.isComplete('student-profile'), isFalse);
  });
}
