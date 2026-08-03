import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chat_media_selection.dart';
import 'package:flutter_application_1/screens/media_preview_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/widgets/chat_video_player.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  late Directory tempDir;
  late File firstImage;
  late File secondImage;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('media_preview_test_');
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    firstImage = File('${tempDir.path}/first.png')..writeAsBytesSync(png);
    secondImage = File('${tempDir.path}/second.png')..writeAsBytesSync(png);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SelectedChatMedia imageMedia(File file) => SelectedChatMedia(
    file: XFile(file.path, mimeType: 'image/png'),
    type: ChatMediaType.image,
    sizeBytes: file.lengthSync(),
  );

  testWidgets(
    'requires explicit send and returns edited selection with caption',
    (tester) async {
      MediaPreviewResult? result;
      var routeCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              key: const ValueKey('open-preview'),
              onPressed: () async {
                result = await Navigator.of(context).push<MediaPreviewResult>(
                  MaterialPageRoute(
                    builder: (_) => MediaPreviewScreen(
                      initialMedia: [
                        imageMedia(firstImage),
                        imageMedia(secondImage),
                      ],
                    ),
                  ),
                );
                routeCompleted = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-preview')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('media-preview-screen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('media-preview-carousel')),
        findsOneWidget,
      );
      expect(find.text(S.mediaPreviewPosition(1, 2)), findsOneWidget);
      expect(result, isNull);
      expect(routeCompleted, isFalse);

      await tester.drag(
        find.byKey(const ValueKey('media-preview-carousel')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.mediaPreviewPosition(2, 2)), findsOneWidget);
      expect(result, isNull);

      await tester.tap(find.byKey(const ValueKey('media-preview-remove')));
      await tester.pumpAndSettle();
      expect(find.text(S.mediaPreviewPosition(1, 1)), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('media-preview-caption')),
        'After class',
      );
      await tester.tap(find.byKey(const ValueKey('media-preview-send')));
      await tester.pumpAndSettle();

      expect(routeCompleted, isTrue);
      expect(result, isNotNull);
      expect(result!.caption, 'After class');
      expect(result!.items, hasLength(1));
      expect(result!.items.single.file.path, firstImage.path);
    },
  );

  testWidgets('backing out returns no confirmation', (tester) async {
    MediaPreviewResult? result;
    var routeCompleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            key: const ValueKey('open-preview'),
            onPressed: () async {
              result = await Navigator.of(context).push<MediaPreviewResult>(
                MaterialPageRoute(
                  builder: (_) => MediaPreviewScreen(
                    initialMedia: [imageMedia(firstImage)],
                    initialCaption: 'Original draft',
                  ),
                ),
              );
              routeCompleted = true;
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-preview')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('media-preview-caption')),
      'Discard this',
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(routeCompleted, isTrue);
    expect(result, isNull);
    expect(find.byKey(const ValueKey('media-preview-screen')), findsNothing);
  });

  testWidgets('removing the final item cancels the preview', (tester) async {
    MediaPreviewResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            key: const ValueKey('open-preview'),
            onPressed: () async {
              result = await Navigator.of(context).push<MediaPreviewResult>(
                MaterialPageRoute(
                  builder: (_) => MediaPreviewScreen(
                    initialMedia: [imageMedia(firstImage)],
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-preview-remove')));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byKey(const ValueKey('media-preview-screen')), findsNothing);
  });

  testWidgets('video initialization failure leaves a retryable preview', (
    tester,
  ) async {
    final video = File('${tempDir.path}/unplayable.mp4')
      ..writeAsBytesSync([0, 1, 2]);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaPreviewScreen(
          initialMedia: [
            SelectedChatMedia(
              file: XFile(video.path, mimeType: 'video/mp4'),
              type: ChatMediaType.video,
              sizeBytes: video.lengthSync(),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ChatVideoPlayer), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-video-playback-toggle')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    // Drain the bounded cleanup timer used when a platform controller fails
    // before completing its initialization handshake.
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  test(
    'inspects mixed media and rejects unavailable or oversized files',
    () async {
      final video = File('${tempDir.path}/clip.mp4')
        ..writeAsBytesSync([0, 1, 2]);
      final unsupported = File('${tempDir.path}/notes.txt')
        ..writeAsStringSync('not media');
      final oversized = File('${tempDir.path}/large.mov');
      final oversizedHandle = oversized.openSync(mode: FileMode.write);
      oversizedHandle.truncateSync(maxChatMediaFileBytes + 1);
      oversizedHandle.closeSync();

      final inspected = await inspectChatMediaFiles([
        XFile(firstImage.path, mimeType: 'image/png'),
        XFile(video.path, mimeType: 'video/mp4'),
        XFile(unsupported.path, mimeType: 'text/plain'),
        XFile(oversized.path, mimeType: 'video/quicktime'),
        XFile('${tempDir.path}/missing.jpg', mimeType: 'image/jpeg'),
      ]);

      expect(inspected.items, hasLength(2));
      expect(inspected.items.map((item) => item.type), [
        ChatMediaType.image,
        ChatMediaType.video,
      ]);
      expect(inspected.rejectedCount, 3);
    },
  );
}
