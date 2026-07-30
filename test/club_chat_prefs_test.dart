import 'dart:io';

import 'package:flutter_application_1/services/club_chat_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('club backgrounds persist independently by community thread', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'club_chat_prefs_test_',
    );
    addTearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Hive.init(tempDir.path);
    final prefs = ClubChatPrefs();
    await prefs.initialize();
    prefs.setBackground('club:c5', ClubChatBackground.ocean);
    prefs.setBackground('club:c6', ClubChatBackground.forest);
    await Hive.box<dynamic>('club_chat_prefs_v1').flush();

    await Hive.close();
    Hive.init(tempDir.path);
    final reloaded = ClubChatPrefs();
    await reloaded.initialize();

    expect(reloaded.backgroundFor('club:c5'), ClubChatBackground.ocean);
    expect(reloaded.backgroundFor('club:c6'), ClubChatBackground.forest);
    expect(reloaded.backgroundFor('club:c7'), ClubChatBackground.classic);
  });
}
