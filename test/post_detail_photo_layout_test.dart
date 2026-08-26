import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/post_detail_screen.dart';
import 'package:flutter_application_1/services/image_aspect_ratio.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _writePhoto(
  Directory directory,
  String name, {
  required int width,
  required int height,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF800020),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final path = '${directory.path}/$name.png';
  await File(path).writeAsBytes(data!.buffer.asUint8List(), flush: true);
  return path;
}

void main() {
  late Directory tempDir;
  late List<Club> originalClubs;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'post_detail_photo_layout_',
    );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() {
    originalClubs = List<Club>.from(clubs);
    clubs
      ..clear()
      ..add(
        Club(
          id: 'post-detail-photo-club',
          name: 'Photography Club',
          description: 'Photo layout fixture',
          adminUserIds: const [],
        ),
      );
  });

  tearDown(() {
    clubs
      ..clear()
      ..addAll(originalClubs);
  });

  Widget host(NewsPost post) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PostDetailScreen(post: post, clubColor: const Color(0xFF800020)),
    ),
  );

  NewsPost post(String id, String imagePath) => NewsPost(
    id: id,
    clubId: 'post-detail-photo-club',
    authorId: 'post-detail-photo-admin',
    content: '$id caption',
    createdAt: DateTime.now(),
    imagePath: imagePath,
  );

  testWidgets('opened photos use the exact Home media viewport bounds', (
    tester,
  ) async {
    final portraitPath = (await tester.runAsync(
      () => _writePhoto(tempDir, 'portrait', width: 80, height: 160),
    ))!;
    final landscapePath = (await tester.runAsync(
      () => _writePhoto(tempDir, 'landscape', width: 160, height: 80),
    ))!;

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(host(post('portrait-post', portraitPath)));
    await tester.pump();

    final portrait = find.byKey(
      const ValueKey('post-detail-photo-portrait-post'),
    );
    final portraitSize = tester.getSize(portrait);
    expect(portraitSize.width, 390);
    expect(
      portraitSize.height,
      closeTo(homePostMediaHeight(390, aspectRatio: 0.5), 0.1),
    );
    expect(portraitSize.height, greaterThan(portraitSize.width));
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .maxScrollExtent,
      0,
    );

    await tester.pumpWidget(host(post('landscape-post', landscapePath)));
    await tester.pump();

    final landscape = find.byKey(
      const ValueKey('post-detail-photo-landscape-post'),
    );
    final landscapeSize = tester.getSize(landscape);
    expect(landscapeSize.width, 390);
    expect(
      landscapeSize.height,
      closeTo(homePostMediaHeight(390, aspectRatio: 2), 0.1),
    );
    expect(landscapeSize.height, lessThan(landscapeSize.width));
    expect(tester.takeException(), isNull);
  });
}
