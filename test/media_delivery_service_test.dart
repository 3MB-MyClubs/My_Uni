import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/media_delivery_service.dart';
import 'package:flutter_application_1/services/original_media_bytes.dart';

void main() {
  group('rendition selection', () {
    test('selects sharp but bounded physical dimensions for every surface', () {
      expect(
        mediaDimensionsFor(
          rendition: MediaRendition.thumbnail,
          logicalWidth: 80,
          devicePixelRatio: 3,
        ).width,
        240,
      );
      expect(
        mediaDimensionsFor(
          rendition: MediaRendition.feed,
          logicalWidth: 500,
          devicePixelRatio: 3,
        ).width,
        1500,
      );
      expect(
        mediaDimensionsFor(
          rendition: MediaRendition.screen,
          logicalWidth: 1200,
          devicePixelRatio: 3,
        ).width,
        2500,
      );
      expect(
        mediaDimensionsFor(
          rendition: MediaRendition.original,
          logicalWidth: 80,
          devicePixelRatio: 3,
        ).isOriginal,
        isTrue,
      );
    });

    test('never requests larger than known source dimensions', () {
      final dimensions = mediaDimensionsFor(
        rendition: MediaRendition.screen,
        logicalWidth: 1000,
        logicalHeight: 800,
        devicePixelRatio: 3,
        sourceWidth: 640,
        sourceHeight: 480,
      );
      expect(dimensions.width, 640);
      expect(dimensions.height, 480);
    });

    test('surface matrix chooses sufficient bounded renditions', () {
      final cases =
          <
            ({
              String surface,
              MediaRendition rendition,
              double width,
              double dpr,
              int expected,
            })
          >[
            (
              surface: 'small avatar',
              rendition: MediaRendition.thumbnail,
              width: 48,
              dpr: 3,
              expected: 144,
            ),
            (
              surface: 'club icon',
              rendition: MediaRendition.thumbnail,
              width: 64,
              dpr: 3,
              expected: 192,
            ),
            (
              surface: 'feed card',
              rendition: MediaRendition.feed,
              width: 500,
              dpr: 3,
              expected: 1500,
            ),
            (
              surface: 'event card',
              rendition: MediaRendition.feed,
              width: 700,
              dpr: 3,
              expected: 1600,
            ),
            (
              surface: 'post detail',
              rendition: MediaRendition.screen,
              width: 800,
              dpr: 3,
              expected: 2400,
            ),
            (
              surface: 'fullscreen phone',
              rendition: MediaRendition.screen,
              width: 430,
              dpr: 3,
              expected: 1290,
            ),
            (
              surface: 'chat thumbnail',
              rendition: MediaRendition.thumbnail,
              width: 320,
              dpr: 3,
              expected: 768,
            ),
            (
              surface: 'chat fullscreen',
              rendition: MediaRendition.screen,
              width: 430,
              dpr: 3,
              expected: 1290,
            ),
          ];

      for (final value in cases) {
        final dimensions = mediaDimensionsFor(
          rendition: value.rendition,
          logicalWidth: value.width,
          devicePixelRatio: value.dpr,
        );
        expect(dimensions.width, value.expected, reason: value.surface);
      }
    });

    test('avatar surfaces share one thumbnail cache size', () {
      final smallAvatar = mediaDimensionsFor(
        rendition: MediaRendition.thumbnail,
        logicalWidth: avatarCacheLogicalSize,
        logicalHeight: avatarCacheLogicalSize,
        devicePixelRatio: 3,
      );
      final largeAvatar = mediaDimensionsFor(
        rendition: MediaRendition.thumbnail,
        logicalWidth: avatarCacheLogicalSize,
        logicalHeight: avatarCacheLogicalSize,
        devicePixelRatio: 3,
      );

      expect(smallAvatar.width, 384);
      expect(smallAvatar.height, 384);
      expect(largeAvatar.width, smallAvatar.width);
      expect(largeAvatar.height, smallAvatar.height);
    });
  });

  group('stable identity and original preservation', () {
    test(
      'canonical high-resolution upload bytes are byte-for-byte intact',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'media-original-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        // PNG signature + IHDR-like 4000x3000 dimensions + distinctive payload.
        final source = Uint8List.fromList([
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
          0x00,
          0x00,
          0x0f,
          0xa0,
          0x00,
          0x00,
          0x0b,
          0xb8,
          ...List<int>.generate(4096, (index) => index % 251),
        ]);
        final file = File('${directory.path}/high-resolution.png');
        await file.writeAsBytes(source, flush: true);

        final upload = await readCanonicalMediaBytes(file);
        expect(upload, orderedEquals(source));
        expect(identical(upload, source), isFalse);
      },
    );

    test('parses historical public and transformed private URLs', () {
      final public = StorageMediaReference.tryParse(
        'https://project.supabase.co/storage/v1/object/public/post-images/'
        'club_posts/c/p/cover.jpg?v=revision-2',
      );
      expect(public?.bucket, 'post-images');
      expect(public?.objectPath, 'club_posts/c/p/cover.jpg');
      expect(public?.revision, 'revision-2');

      final private = StorageMediaReference.tryParse(
        'https://project.supabase.co/storage/v1/render/image/sign/'
        'chat-attachments/u/message.jpg?width=384&token=rotating',
      );
      expect(private?.isPrivate, isTrue);
      expect(private?.objectPath, 'u/message.jpg');
    });

    test('original rendition returns the exact canonical URL unchanged', () {
      const original =
          'https://project.supabase.co/storage/v1/object/public/post-images/'
          'club_posts/c/p/cover.jpg?v=source-revision';
      final result = MediaDeliveryService().resolvePublic(
        value: original,
        rendition: MediaRendition.original,
        dimensions: const MediaDimensions(),
      );
      expect(result.url, same(original));
      expect(result.fallbackUrl, isNull);
    });
  });

  group('private signed URL cache', () {
    test(
      'sender and recipient resolve the same canonical private object',
      () async {
        final signed = <String>[];
        final service = MediaDeliveryService(
          privateSigner: (reference, rendition, dimensions, lifetime) async {
            signed.add('${reference.bucket}/${reference.objectPath}');
            return 'https://signed.test/${reference.objectPath}?token=${signed.length}';
          },
        );
        const value = 'chat-attachment://sender/message.jpg';
        const dimensions = MediaDimensions(width: 384);

        final sent = await service.resolvePrivate(
          value: value,
          actorId: 'sender',
          rendition: MediaRendition.thumbnail,
          dimensions: dimensions,
        );
        final received = await service.resolvePrivate(
          value: value,
          actorId: 'recipient',
          rendition: MediaRendition.thumbnail,
          dimensions: dimensions,
        );

        expect(signed, [
          'chat-attachments/sender/message.jpg',
          'chat-attachments/sender/message.jpg',
        ]);
        expect(sent.cacheKey, isNot(received.cacheKey));
      },
    );

    test(
      'deduplicates concurrent signing and reuses the same rendition',
      () async {
        var calls = 0;
        final gate = Completer<void>();
        final service = MediaDeliveryService(
          privateSigner: (reference, rendition, dimensions, lifetime) async {
            calls++;
            await gate.future;
            return 'https://signed.test/${reference.objectPath}?token=$calls';
          },
        );
        const dimensions = MediaDimensions(width: 384);
        final first = service.resolvePrivate(
          value: 'chat-attachment://actor/message.jpg',
          actorId: 'actor',
          rendition: MediaRendition.thumbnail,
          dimensions: dimensions,
        );
        final second = service.resolvePrivate(
          value: 'chat-attachment://actor/message.jpg',
          actorId: 'actor',
          rendition: MediaRendition.thumbnail,
          dimensions: dimensions,
        );
        expect(calls, 1);
        gate.complete();
        final results = await Future.wait([first, second]);
        expect(results[0].url, results[1].url);

        final third = await service.resolvePrivate(
          value: 'chat-attachment://actor/message.jpg',
          actorId: 'actor',
          rendition: MediaRendition.thumbnail,
          dimensions: dimensions,
        );
        expect(third.url, results[0].url);
        expect(calls, 1);
        expect(service.metrics.signedUrlInFlightHits, 1);
        expect(service.metrics.signedUrlCacheHits, 1);
      },
    );

    test('refreshes expired URLs and isolates account cache keys', () async {
      var now = DateTime.utc(2026, 8, 13, 10);
      var calls = 0;
      final service = MediaDeliveryService(
        now: () => now,
        privateSigner: (reference, rendition, dimensions, lifetime) async =>
            'https://signed.test/${reference.objectPath}?token=${++calls}',
      );
      const value = 'chat-attachment://owner/message.jpg';
      const dimensions = MediaDimensions(width: 384);
      final first = await service.resolvePrivate(
        value: value,
        actorId: 'account-a',
        rendition: MediaRendition.thumbnail,
        dimensions: dimensions,
      );
      final otherAccount = await service.resolvePrivate(
        value: value,
        actorId: 'account-b',
        rendition: MediaRendition.thumbnail,
        dimensions: dimensions,
      );
      expect(otherAccount.cacheKey, isNot(first.cacheKey));
      expect(calls, 2);

      now = now.add(const Duration(hours: 1));
      final refreshed = await service.resolvePrivate(
        value: value,
        actorId: 'account-a',
        rendition: MediaRendition.thumbnail,
        dimensions: dimensions,
      );
      expect(refreshed.url, isNot(first.url));
      expect(calls, 3);

      service.clearAccount('account-a');
      await service.resolvePrivate(
        value: value,
        actorId: 'account-a',
        rendition: MediaRendition.thumbnail,
        dimensions: dimensions,
      );
      expect(calls, 4);
    });
  });
}
