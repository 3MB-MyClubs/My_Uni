import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/theme/app_semantic_colors.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/media_scrim.dart';
import 'package:flutter_application_1/widgets/chats_design.dart';
import 'package:flutter_application_1/widgets/club_profile_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('runtime theme switching updates inherited semantic colors', (
    tester,
  ) async {
    final mode = ValueNotifier(ThemeMode.light);
    addTearDown(mode.dispose);

    await tester.pumpWidget(_ThemeHarness(mode: mode));
    final light = _probeColors(tester);

    mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    final dark = _probeColors(tester);

    expect(light.$1, isNot(dark.$1));
    expect(light.$2, isNot(dark.$2));
  });

  testWidgets('iOS Increase Contrast selects the high contrast theme', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(
          AppThemeVariant.light,
        ).copyWith(platform: TargetPlatform.iOS),
        darkTheme: AppTheme.build(AppThemeVariant.dark),
        highContrastTheme: AppTheme.build(
          AppThemeVariant.highContrastLight,
        ).copyWith(platform: TargetPlatform.iOS),
        highContrastDarkTheme: AppTheme.build(AppThemeVariant.highContrastDark),
        home: const _SemanticProbe(),
      ),
    );

    final context = tester.element(find.byType(_SemanticProbe));
    final theme = Theme.of(context);
    expect(theme.platform, TargetPlatform.iOS);
    expect(theme.colorScheme.onSurface, Colors.black);
    expect(
      theme.extension<AppSemanticColors>()!.brand,
      const Color(0xFF76002B),
    );
  });

  testWidgets('buttons and chips use matching semantic foregrounds', (
    tester,
  ) async {
    final theme = AppTheme.build(AppThemeVariant.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('Button')),
              const Chip(label: Text('Chip')),
            ],
          ),
        ),
      ),
    );

    expect(
      theme.elevatedButtonTheme.style!.foregroundColor!.resolve({}),
      theme.colorScheme.onPrimary,
    );
    expect(
      theme.chipTheme.labelStyle!.color,
      theme.extension<AppSemanticColors>()!.onBrandSurface,
    );
  });

  testWidgets('system chrome icons track light and dark surfaces', (
    tester,
  ) async {
    for (final variant in [AppThemeVariant.light, AppThemeVariant.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(variant),
          theme: AppTheme.build(variant),
          themeMode: ThemeMode.light,
          home: const AppSystemUiOverlay(child: SizedBox.expand()),
        ),
      );
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      final expected = variant == AppThemeVariant.light
          ? Brightness.dark
          : Brightness.light;
      expect(overlay.value.statusBarIconBrightness, expected);
      expect(overlay.value.systemNavigationBarIconBrightness, expected);
    }
  });

  testWidgets('chat bubbles and custom cards inherit paired foregrounds', (
    tester,
  ) async {
    final theme = AppTheme.build(AppThemeVariant.dark);
    final chats = ChatsColors.of;
    Color? bubbleForeground;
    Color? cardForeground;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            children: [
              ChatBubbleShell(
                mine: true,
                maxWidth: 240,
                child: Builder(
                  builder: (context) {
                    bubbleForeground = DefaultTextStyle.of(context).style.color;
                    return const Text('Bubble');
                  },
                ),
              ),
              ClubProfileCard(
                padding: const EdgeInsets.all(8),
                child: Builder(
                  builder: (context) {
                    cardForeground = DefaultTextStyle.of(context).style.color;
                    return const Text('Card');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(ChatBubbleShell));
    expect(bubbleForeground, chats(context).onBrand);
    expect(cardForeground, ClubProfileColors.of(context).onSurface);
  });

  testWidgets('media scrim is non-interactive and uses fixed onMedia text', (
    tester,
  ) async {
    var taps = 0;
    final theme = AppTheme.build(AppThemeVariant.light);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: GestureDetector(
            onTap: () => taps++,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.white),
                const MediaScrim(position: MediaScrimPosition.full),
                Align(
                  child: Builder(
                    builder: (context) => Text(
                      'Media',
                      style: TextStyle(color: context.semanticColors.onMedia),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Media'));
    expect(taps, 1);
    expect(
      find.descendant(
        of: find.byType(MediaScrim),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.text('Media')).style!.color,
      theme.extension<AppSemanticColors>()!.onMedia,
    );
  });

  testWidgets('media scrim exposes top, bottom, and full gradient options', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppThemeVariant.light),
        home: const Row(
          children: [
            Expanded(child: MediaScrim(position: MediaScrimPosition.top)),
            Expanded(child: MediaScrim(position: MediaScrimPosition.bottom)),
            Expanded(child: MediaScrim(position: MediaScrimPosition.full)),
          ],
        ),
      ),
    );

    final paints = tester
        .widgetList<DecoratedBox>(
          find.byKey(const ValueKey('media-scrim-paint')),
        )
        .map((box) => box.decoration as BoxDecoration)
        .map((decoration) => decoration.gradient! as LinearGradient)
        .toList();
    expect(paints, hasLength(3));
    expect(paints[0].begin, Alignment.topCenter);
    expect(paints[1].begin, Alignment.bottomCenter);
    expect(paints[2].colors.toSet(), hasLength(1));
  });
}

class _ThemeHarness extends StatelessWidget {
  const _ThemeHarness({required this.mode});

  final ValueNotifier<ThemeMode> mode;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: mode,
      builder: (context, value, _) => MaterialApp(
        themeMode: value,
        theme: AppTheme.build(AppThemeVariant.light),
        darkTheme: AppTheme.build(AppThemeVariant.dark),
        highContrastTheme: AppTheme.build(AppThemeVariant.highContrastLight),
        highContrastDarkTheme: AppTheme.build(AppThemeVariant.highContrastDark),
        home: const _SemanticProbe(),
      ),
    );
  }
}

class _SemanticProbe extends StatelessWidget {
  const _SemanticProbe();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('semantic-probe'),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Text(
        'Probe',
        style: TextStyle(color: context.semanticColors.textSecondary),
      ),
    );
  }
}

(Color, Color) _probeColors(WidgetTester tester) {
  final context = tester.element(find.byType(_SemanticProbe));
  return (
    Theme.of(context).scaffoldBackgroundColor,
    context.semanticColors.textSecondary,
  );
}
