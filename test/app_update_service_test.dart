import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/app_update_service.dart';

void main() {
  AppUpdateService service({
    required TargetPlatform platform,
    required int currentBuild,
    int androidMinimumBuild = 2,
    int iosMinimumBuild = 2,
    String androidStoreUrl =
        'https://play.google.com/store/apps/details?id=com.threemb.clupup',
    String iosStoreUrl = 'https://apps.apple.com/us/search?term=ClubUp',
  }) {
    return AppUpdateService(
      targetPlatform: platform,
      isWeb: false,
      configLoader: () async => {
        'android_min_build': androidMinimumBuild,
        'ios_min_build': iosMinimumBuild,
        'android_store_url': androidStoreUrl,
        'ios_store_url': iosStoreUrl,
      },
      installedAppInfoLoader: () async =>
          InstalledAppInfo(version: '1.1.0', buildNumber: currentBuild),
    );
  }

  test(
    'requires an Android update below the configured minimum build',
    () async {
      final requirement = await service(
        platform: TargetPlatform.android,
        currentBuild: 1,
      ).checkForRequiredUpdate();

      expect(requirement, isNotNull);
      expect(requirement!.currentBuild, 1);
      expect(requirement.minimumBuild, 2);
      expect(requirement.storeUrl, contains('play.google.com'));
    },
  );

  test('allows Android at or above the configured minimum build', () async {
    final requirement = await service(
      platform: TargetPlatform.android,
      currentBuild: 2,
    ).checkForRequiredUpdate();

    expect(requirement, isNull);
  });

  test('uses the iOS minimum and store URL independently', () async {
    final requirement = await service(
      platform: TargetPlatform.iOS,
      currentBuild: 3,
      iosMinimumBuild: 4,
    ).checkForRequiredUpdate();

    expect(requirement, isNotNull);
    expect(requirement!.minimumBuild, 4);
    expect(requirement.storeUrl, contains('apps.apple.com'));
  });

  test('does not gate web or desktop builds', () async {
    for (final platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      final requirement = await service(
        platform: platform,
        currentBuild: 1,
        androidMinimumBuild: 99,
        iosMinimumBuild: 99,
      ).checkForRequiredUpdate();

      expect(requirement, isNull);
    }

    final webRequirement = await AppUpdateService(
      targetPlatform: TargetPlatform.android,
      isWeb: true,
      configLoader: () async => {'android_min_build': 99, 'ios_min_build': 99},
      installedAppInfoLoader: () async =>
          const InstalledAppInfo(version: '1.0.0', buildNumber: 1),
    ).checkForRequiredUpdate();

    expect(webRequirement, isNull);
  });

  test('fails open when the remote config cannot be read', () async {
    final requirement = await AppUpdateService(
      targetPlatform: TargetPlatform.android,
      isWeb: false,
      configLoader: () async => throw StateError('offline'),
      installedAppInfoLoader: () async =>
          const InstalledAppInfo(version: '1.0.0', buildNumber: 1),
    ).checkForRequiredUpdate();

    expect(requirement, isNull);
  });
}
