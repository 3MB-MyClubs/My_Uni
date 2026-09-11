import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/content_audience.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/content_audience_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// The picker is the only place a club is told what the three tiers mean, so
/// the descriptions matter as much as the labels.
void main() {
  setUp(() async {
    await themeService.setDark(false);
    await localeService.setLanguage('en');
  });

  tearDown(() async {
    await localeService.setLanguage('en');
    await themeService.setDark(false);
  });

  Future<ContentAudience?> openSheet(
    WidgetTester tester, {
    ContentAudience current = ContentAudience.everyone,
  }) async {
    ContentAudience? result;
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(localeService.languageCode),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  opened = true;
                  result = await showContentAudienceSheet(
                    context,
                    current: current,
                    surface: Colors.white,
                    border: const Color(0xFFE4E4E7),
                    text: const Color(0xFF18181B),
                    muted: const Color(0xFF71717A),
                    accent: const Color(0xFF800020),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(opened, isTrue);
    return result;
  }

  testWidgets('all three tiers render with their explanations', (tester) async {
    await openSheet(tester);

    expect(
      find.byKey(const ValueKey('content-audience-sheet')),
      findsOneWidget,
    );
    expect(find.text(S.audienceSheetTitle), findsOneWidget);
    for (final audience in ContentAudience.values) {
      expect(
        find.byKey(ValueKey('content-audience-option-${audience.wireValue}')),
        findsOneWidget,
        reason: '${audience.name} row is missing',
      );
      expect(find.text(S.audienceTierLabel(audience)), findsOneWidget);
      expect(find.text(S.audienceTierHint(audience)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the current tier is the selected row', (tester) async {
    await openSheet(tester, current: ContentAudience.followers);

    // Exactly one row carries the filled ring, and it is the current tier.
    expect(
      find.byKey(const ValueKey('content-audience-selected-followers')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('content-audience-selected-everyone')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('content-audience-selected-board')),
      findsNothing,
    );
    // And every row is announced as a button to a screen reader.
    for (final audience in ContentAudience.values) {
      final node = tester.getSemantics(
        find.byKey(ValueKey('content-audience-option-${audience.wireValue}')),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a row pops that tier', (tester) async {
    ContentAudience? picked;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showContentAudienceSheet(
                    context,
                    current: ContentAudience.everyone,
                    surface: Colors.white,
                    border: const Color(0xFFE4E4E7),
                    text: const Color(0xFF18181B),
                    muted: const Color(0xFF71717A),
                    accent: const Color(0xFF800020),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    await tester.tap(
      find.byKey(const ValueKey('content-audience-option-board')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(picked, ContentAudience.board);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the copy switches to Turkish with the app language', (
    tester,
  ) async {
    await localeService.setLanguage('tr');
    await openSheet(tester);

    expect(find.text('Herkes'), findsOneWidget);
    expect(find.text('Yönetim kurulu'), findsOneWidget);
    expect(find.text('Kulübünü takip edenler'), findsOneWidget);
    expect(find.text('Everyone'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpMark(
    WidgetTester tester,
    Widget mark, {
    Alignment alignment = Alignment.center,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(localeService.languageCode),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(alignment: alignment, child: mark),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the mark renders only for restricted tiers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ContentAudienceIcon(
                audience: ContentAudience.everyone,
                color: Color(0xFF800020),
              ),
              ContentAudienceIcon(
                audience: ContentAudience.board,
                color: Color(0xFF800020),
              ),
              ContentAudienceIcon.onMedia(audience: ContentAudience.followers),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // Public content carries no mark at all: two restricted glyphs are on
    // screen and three were built.
    expect(
      find.byIcon(audienceTierIcon(ContentAudience.board)),
      findsOneWidget,
    );
    expect(
      find.byIcon(audienceTierIcon(ContentAudience.followers)),
      findsOneWidget,
    );
    expect(
      find.byIcon(audienceTierIcon(ContentAudience.everyone)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('each restricted tier gets its own glyph', (tester) async {
    // The mark is now read at 12-14px with no label beside it at all, so the
    // glyph carries the whole distinction until someone taps it. A padlock and
    // a pair of people are distinguishable at that size; two copies of the same
    // eye are not.
    expect(
      audienceTierIcon(ContentAudience.board),
      isNot(audienceTierIcon(ContentAudience.followers)),
    );
    expect(audienceTierIcon(ContentAudience.board), Icons.lock_outline);
    expect(audienceTierIcon(ContentAudience.followers), Icons.group_outlined);
  });

  testWidgets('tapping the mark pops a bubble naming the tier', (tester) async {
    await pumpMark(
      tester,
      const ContentAudienceIcon(
        audience: ContentAudience.board,
        color: Color(0xFF800020),
      ),
    );

    expect(
      find.text(S.audienceTierBubble(ContentAudience.board)),
      findsNothing,
    );

    await tester.tap(find.byType(ContentAudienceIcon));
    await tester.pumpAndSettle();

    expect(
      find.text(S.audienceTierBubble(ContentAudience.board)),
      findsOneWidget,
    );
    // It is an overlay, so it escapes the card's clip rather than widening it.
    expect(
      find.byKey(const ValueKey('content-audience-bubble')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the followers bubble names followers, not members', (
    tester,
  ) async {
    // "Followers" is what the picker calls this tier and what a student does
    // to a club here; "members" would be a fourth word for the same thing.
    expect(
      S.audienceTierBubble(ContentAudience.followers),
      'Only followers of this club',
    );
    expect(S.audienceTierBubble(ContentAudience.board), 'Only board members');
    expect(S.audienceTierBubble(ContentAudience.everyone), '');

    await localeService.setLanguage('tr');
    expect(
      S.audienceTierBubble(ContentAudience.followers),
      'Yalnızca kulüp takipçileri',
    );
    expect(
      S.audienceTierBubble(ContentAudience.board),
      'Yalnızca yönetim kurulu',
    );
  });

  testWidgets('the next tap closes the bubble', (tester) async {
    await pumpMark(
      tester,
      const ContentAudienceIcon(
        audience: ContentAudience.followers,
        color: Color(0xFF800020),
      ),
    );
    await tester.tap(find.byType(ContentAudienceIcon));
    await tester.pumpAndSettle();
    expect(
      find.text(S.audienceTierBubble(ContentAudience.followers)),
      findsOneWidget,
    );

    // The barrier is opaque, so this tap dismisses and does not also reach the
    // card the mark is drawn on.
    await tester.tapAt(const Offset(30, 30));
    await tester.pumpAndSettle();

    expect(
      find.text(S.audienceTierBubble(ContentAudience.followers)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bubble fades on its own if it is left alone', (
    tester,
  ) async {
    await pumpMark(
      tester,
      const ContentAudienceIcon(
        audience: ContentAudience.board,
        color: Color(0xFF800020),
      ),
    );
    await tester.tap(find.byType(ContentAudienceIcon));
    await tester.pumpAndSettle();
    expect(
      find.text(S.audienceTierBubble(ContentAudience.board)),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(
      find.text(S.audienceTierBubble(ContentAudience.board)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a mark near the top of the screen hangs its bubble below', (
    tester,
  ) async {
    // The event detail screen puts the mark beside a time badge that can sit
    // right under the status bar; a bubble drawn above it would be off screen.
    await pumpMark(
      tester,
      const ContentAudienceIcon(
        audience: ContentAudience.board,
        color: Color(0xFF800020),
      ),
      alignment: Alignment.topCenter,
    );
    await tester.tap(find.byType(ContentAudienceIcon));
    await tester.pumpAndSettle();

    final mark = tester.getRect(find.byType(ContentAudienceIcon));
    final bubble = tester.getRect(
      find.byKey(const ValueKey('content-audience-bubble')),
    );
    expect(bubble.top, greaterThanOrEqualTo(mark.bottom));
    expect(bubble.top, lessThan(mark.bottom + 24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bubble stays on screen at either edge', (tester) async {
    for (final alignment in [Alignment.centerLeft, Alignment.centerRight]) {
      await pumpMark(
        tester,
        const ContentAudienceIcon(
          audience: ContentAudience.followers,
          color: Color(0xFF800020),
        ),
        alignment: alignment,
      );
      await tester.tap(find.byType(ContentAudienceIcon));
      await tester.pumpAndSettle();

      final bubble = tester.getRect(
        find.byKey(const ValueKey('content-audience-bubble')),
      );
      expect(bubble.left, greaterThanOrEqualTo(0));
      expect(bubble.right, lessThanOrEqualTo(tester.view.physicalSize.width));

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bubble grows out of the glyph, not beside it', (
    tester,
  ) async {
    // The tail is the only thing that says which mark the words belong to, so
    // it has to land on the glyph itself at every side bucket — including the
    // two near-edge ones, which slide the whole bubble over to put it there.
    final tailFinder = find.byWidgetPredicate(
      // The tail is the only 12x6 CustomPaint in the tree.
      (widget) => widget is CustomPaint && widget.size == const Size(12, 6),
    );

    for (final alignment in [
      Alignment.centerLeft,
      Alignment.center,
      Alignment.centerRight,
    ]) {
      await pumpMark(
        tester,
        const ContentAudienceIcon(
          audience: ContentAudience.followers,
          color: Color(0xFF800020),
        ),
        alignment: alignment,
      );
      await tester.tap(find.byType(ContentAudienceIcon));
      await tester.pumpAndSettle();

      final mark = tester.getRect(find.byType(ContentAudienceIcon));
      final tail = tester.getRect(tailFinder);
      final bubble = tester.getRect(
        find.byKey(const ValueKey('content-audience-bubble')),
      );

      expect(
        (tail.center.dx - mark.center.dx).abs(),
        lessThan(1),
        reason: 'the tail should point at the glyph at $alignment',
      );
      // And it reaches it: the tip meets the glyph rather than hanging above.
      expect(
        (tail.bottom - mark.top).abs(),
        lessThan(4),
        reason: 'the tail should touch the glyph at $alignment',
      );
      // Pinning the tail must not push the bubble off the screen edge.
      expect(bubble.left, greaterThanOrEqualTo(0));
      expect(
        bubble.right,
        lessThanOrEqualTo(tester.getSize(find.byType(MaterialApp)).width),
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the media variant brings its own contrast', (tester) async {
    // Over a cover photo the club accent is unusable — a 10% wash of anything
    // disappears, and the accent itself may match the photo. The variant that
    // sits on media therefore ignores the accent entirely and brings a disc.
    await pumpMark(
      tester,
      const ContentAudienceIcon.onMedia(audience: ContentAudience.board),
    );

    final icon = tester.widget<Icon>(
      find.byIcon(audienceTierIcon(ContentAudience.board)),
    );
    expect(icon.color, Colors.white);

    final disc = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(audienceTierIcon(ContentAudience.board)),
            matching: find.byType(Container),
          )
          .first,
    );
    final fill = (disc.decoration as BoxDecoration).color!;
    // A real scrim, not a 10% tint, or a white glyph on a photo is unreadable.
    expect(fill.a, greaterThan(0.4));
    expect(tester.takeException(), isNull);
  });
}
