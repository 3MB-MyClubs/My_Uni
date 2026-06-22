import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/user_state.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('user_prefs_test_');
    Hive.init(tempDir.path);
    await userPrefsService.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('new users do not inherit demo followed clubs or people', () {
    const newUserId = 'new_user_without_follows';
    users.removeWhere((user) => user.id == newUserId);
    users.add(
      User(
        id: newUserId,
        name: 'New Student',
        email: 'newstudent@ku.edu.tr',
        password: '111111',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );

    userState.followedClubIds
      ..clear()
      ..add('c1');
    userState.followedUserIds
      ..clear()
      ..addAll(['u1', 'u4']);

    userPrefsService.load(newUserId);

    expect(userState.followedClubIds, isEmpty);
    expect(userState.followedUserIds, isEmpty);
  });
}
