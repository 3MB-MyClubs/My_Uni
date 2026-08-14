import 'dart:io';

import 'package:flutter_application_1/services/chat_attachment_staging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory sourceDirectory;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('chat-stage-root-');
    sourceDirectory = await Directory.systemTemp.createTemp(
      'chat-stage-source-',
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
    if (await sourceDirectory.exists()) {
      await sourceDirectory.delete(recursive: true);
    }
  });

  test('stages by account and successful cleanup removes the copy', () async {
    final source = File('${sourceDirectory.path}/photo.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final staged = await chatAttachmentStagingService.stage(
      source.path,
      accountId: 'account-a',
      rootOverride: root,
    );

    expect(staged, contains('account-a'));
    expect(await File(staged).exists(), isTrue);
    await chatAttachmentStagingService.deleteIfStaged(
      staged,
      rootOverride: root,
    );
    expect(await File(staged).exists(), isFalse);
  });

  test(
    'sweeper preserves active outbox files and removes abandoned files',
    () async {
      final source = File('${sourceDirectory.path}/photo.jpg');
      await source.writeAsBytes([1]);
      final active = await chatAttachmentStagingService.stage(
        source.path,
        accountId: 'account-a',
        rootOverride: root,
      );
      final abandoned = await chatAttachmentStagingService.stage(
        source.path,
        accountId: 'account-a',
        rootOverride: root,
      );
      final old = DateTime.now().subtract(const Duration(days: 8));
      await File(active).setLastModified(old);
      await File(abandoned).setLastModified(old);

      final count = await chatAttachmentStagingService.sweep(
        activePaths: {active},
        now: DateTime.now(),
        rootOverride: root,
      );
      expect(count, 1);
      expect(await File(active).exists(), isTrue);
      expect(await File(abandoned).exists(), isFalse);
    },
  );

  test('logout cleanup removes only the selected account directory', () async {
    final source = File('${sourceDirectory.path}/photo.jpg');
    await source.writeAsBytes([1]);
    final first = await chatAttachmentStagingService.stage(
      source.path,
      accountId: 'account-a',
      rootOverride: root,
    );
    final second = await chatAttachmentStagingService.stage(
      source.path,
      accountId: 'account-b',
      rootOverride: root,
    );

    await chatAttachmentStagingService.cleanupAccount(
      'account-a',
      rootOverride: root,
    );
    expect(await File(first).exists(), isFalse);
    expect(await File(second).exists(), isTrue);
  });
}
