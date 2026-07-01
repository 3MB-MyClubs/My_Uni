import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/post_detail_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/message_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';

/// Drives the Instagram-style full-screen image viewer on a post banner:
/// tap to open (hero flight), double-tap to zoom in/out, swipe down to
/// dismiss back to the post.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 300));
    await binding.takeScreenshot(name);
  }

  testWidgets('Post image — full-screen viewer open / zoom / dismiss', (
    tester,
  ) async {
    await messageService.initialize();
    await contentStore.initialize();
    authService.login('alice@ku.edu.tr');

    final post = newsPosts.firstWhere(
      (p) => p.imagePath != null && p.imagePath!.startsWith('http'),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PostDetailScreen(post: post, clubColor: const Color(0xFF9E2045)),
      ),
    );
    // Give the network banner image time to load.
    await tester.pump(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await shot(tester, '01-post-detail');

    // PostDetailScreen renders the banner via buildPostBanner(height: 220);
    // match on that (the club-avatar header also renders an Image, so
    // find.byType(Image).first would grab the wrong one).
    final bannerImage = find.byWidgetPredicate((w) => w is Image && w.height == 220);
    expect(bannerImage, findsOneWidget);

    // Tap opens the full-screen viewer with a hero flight.
    await tester.tap(bannerImage);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300)); // flight
    await shot(tester, '02-viewer-opened');
    expect(find.byIcon(Icons.close), findsOneWidget);

    final fullImage = find.byWidgetPredicate(
      (w) => w is Image && w.fit == BoxFit.contain && w.width == double.infinity,
    );
    expect(fullImage, findsOneWidget);

    // Double-tap to zoom in.
    await tester.tap(fullImage);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(fullImage);
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '03-double-tap-zoomed-in');

    // Double-tap again to zoom back out.
    await tester.tap(fullImage);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(fullImage);
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '04-double-tap-zoomed-out');

    // Swipe down to dismiss back to the post. The app has repeating
    // shimmer/pulse animations elsewhere, so use fixed pumps, not
    // pumpAndSettle (which would never settle).
    await tester.dragFrom(const Offset(200, 400), const Offset(0, 550));
    await tester.pump(const Duration(milliseconds: 100));
    await shot(tester, '05-dismiss-drag');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '06-dismissed-back-to-post');
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
