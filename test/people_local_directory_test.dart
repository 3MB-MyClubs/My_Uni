import 'dart:io';

import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('chat directory persists only explicitly registered local users', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'people_local_directory_test_',
    );
    Hive.init(tempDir.path);
    addTearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final firstSession = PeopleService();
    await firstSession.initialize();
    expect(firstSession.cachedPeople, isEmpty);

    await firstSession.registerLocalUser(
      User(
        id: 'local-real-user',
        name: 'Local Student',
        email: 'local.student@ku.edu.tr',
        password: '135790',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );

    final nextSession = PeopleService();
    await nextSession.initialize();
    expect(nextSession.cachedPeople, hasLength(1));
    expect(nextSession.cachedPeople.single.id, 'local-real-user');
    expect(nextSession.cachedPeople.single.name, 'Local Student');
    expect(nextSession.cachedPeople.single.password, isEmpty);
  });
}
