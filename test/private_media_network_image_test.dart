import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/media_delivery_service.dart';
import 'package:flutter_application_1/widgets/app_network_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var transformedFails = false;
  var originalFails = false;
  late List<MediaRendition> resolutions;

  setUp(() {
    transformedFails = false;
    originalFails = false;
    resolutions = <MediaRendition>[];
  });

  Future<void> pumpImage(WidgetTester tester) async {
    Future<ResolvedMedia> resolver(
      String reference,
      MediaRendition rendition,
      MediaDimensions dimensions,
    ) async {
      resolutions.add(rendition);
      return ResolvedMedia(
        url: rendition == MediaRendition.original
            ? 'https://signed.test/object/sign/chat-attachments/owner/message.jpg?token=original'
            : 'https://signed.test/render/image/sign/chat-attachments/owner/message.jpg?token=transformed',
        cacheKey:
            'private-account/chat-attachments/owner/message.jpg/${rendition.name}',
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 150,
            child: PrivateMediaNetworkImage(
              reference: 'chat-attachment://owner/message.jpg',
              rendition: MediaRendition.thumbnail,
              cacheWidth: 320,
              width: 200,
              height: 150,
              resolver: resolver,
              resolvedBuilder: (context, media, rendition, errorBuilder) {
                final failed = rendition == MediaRendition.original
                    ? originalFails
                    : transformedFails;
                if (failed) return errorBuilder(context);
                return ColoredBox(
                  key: ValueKey('rendered-${rendition.name}'),
                  color: Colors.green,
                );
              },
              placeholderBuilder: (_) => const ColoredBox(
                key: ValueKey('loading'),
                color: Colors.grey,
              ),
              errorBuilder: (_) => const ColoredBox(
                key: ValueKey('normal-image-error'),
                color: Colors.grey,
                child: Icon(Icons.image_outlined),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders transformed private chat image when it succeeds', (
    tester,
  ) async {
    await pumpImage(tester);

    expect(resolutions, [MediaRendition.thumbnail]);
    expect(find.byKey(const ValueKey('rendered-thumbnail')), findsOneWidget);
    expect(find.byKey(const ValueKey('normal-image-error')), findsNothing);
  });

  testWidgets('403 transformed image falls back to signed original', (
    tester,
  ) async {
    transformedFails = true;
    await pumpImage(tester);

    expect(resolutions, [MediaRendition.thumbnail, MediaRendition.original]);
    expect(find.byKey(const ValueKey('rendered-original')), findsOneWidget);
    expect(find.byKey(const ValueKey('normal-image-error')), findsNothing);
  });

  testWidgets(
    'failed transformed and original image uses bounded app error UI',
    (tester) async {
      transformedFails = true;
      originalFails = true;
      await pumpImage(tester);

      final error = find.byKey(const ValueKey('normal-image-error'));
      expect(error, findsOneWidget);
      expect(tester.getSize(error), const Size(200, 150));
      expect(resolutions, [MediaRendition.thumbnail, MediaRendition.original]);
    },
  );
}
