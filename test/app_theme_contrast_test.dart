import 'package:flutter/material.dart';
import 'package:flutter_application_1/theme/app_semantic_colors.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/theme/specialized_semantic_palettes.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release semantic contrast contract', () {
    for (final variant in AppThemeVariant.values) {
      test('$variant meets WCAG AA for every declared text pair', () {
        final theme = AppTheme.build(variant);
        final semantic = theme.extension<AppSemanticColors>()!;

        for (final pair in semantic.contrastPairs(theme.colorScheme)) {
          final ratio = _contrast(pair.foreground, pair.background);
          expect(
            ratio,
            greaterThanOrEqualTo(pair.minimumRatio),
            reason:
                '${pair.name} is ${ratio.toStringAsFixed(2)}:1 in $variant; '
                'expected at least ${pair.minimumRatio}:1.',
          );
        }

        final materialPairs = [
          SemanticContrastPair(
            'ColorScheme.onSurface / surface',
            theme.colorScheme.onSurface,
            theme.colorScheme.surface,
          ),
          SemanticContrastPair(
            'ColorScheme.onPrimary / primary',
            theme.colorScheme.onPrimary,
            theme.colorScheme.primary,
          ),
          SemanticContrastPair(
            'ColorScheme.onSecondary / secondary',
            theme.colorScheme.onSecondary,
            theme.colorScheme.secondary,
          ),
          SemanticContrastPair(
            'ColorScheme.onError / error',
            theme.colorScheme.onError,
            theme.colorScheme.error,
          ),
        ];
        for (final pair in materialPairs) {
          final ratio = _contrast(pair.foreground, pair.background);
          expect(
            ratio,
            greaterThanOrEqualTo(pair.minimumRatio),
            reason:
                '${pair.name} is ${ratio.toStringAsFixed(2)}:1 in $variant.',
          );
        }

        final specialized = <String, SpecializedSemanticPalette>{
          'Chats': SpecializedSemanticPalettes.chats(theme),
          'ClubUp': SpecializedSemanticPalettes.clubUp(theme),
          'Profiles': SpecializedSemanticPalettes.profiles(theme),
          'Club Profiles': SpecializedSemanticPalettes.clubProfiles(theme),
          'Campus ID': SpecializedSemanticPalettes.campusId(theme),
        };
        for (final palette in specialized.entries) {
          for (final pair in palette.value.contrastPairs) {
            final ratio = _contrast(pair.foreground, pair.background);
            expect(
              ratio,
              greaterThanOrEqualTo(pair.minimumRatio),
              reason:
                  '${palette.key}: ${pair.name} is '
                  '${ratio.toStringAsFixed(2)}:1 in $variant; expected at '
                  'least ${pair.minimumRatio}:1.',
            );
          }
        }
      });

      test(
        '$variant media scrim passes worst-case bright and dark imagery',
        () {
          final semantic = AppTheme.build(
            variant,
          ).extension<AppSemanticColors>()!;
          for (final image in const [Colors.white, Colors.black]) {
            final composited = Color.alphaBlend(semantic.mediaScrim, image);
            expect(
              _contrast(semantic.onMedia, composited),
              greaterThanOrEqualTo(4.5),
              reason: 'onMedia failed over $image in $variant.',
            );
          }
        },
      );
    }
  });

  test('theme construction is deterministic and preference-service free', () {
    final lightA = AppTheme.build(AppThemeVariant.light);
    final dark = AppTheme.build(AppThemeVariant.dark);
    final lightB = AppTheme.build(AppThemeVariant.light);

    expect(lightA.colorScheme, lightB.colorScheme);
    expect(
      lightA.extension<AppSemanticColors>()!.textPrimary,
      lightB.extension<AppSemanticColors>()!.textPrimary,
    );
    expect(lightA.colorScheme.onSurface, isNot(dark.colorScheme.onSurface));
  });

  test('legacy AppColors palettes remain AA-compatible during migration', () {
    final legacyPairs = [
      const SemanticContrastPair(
        'legacy light primary',
        LightColors.text,
        LightColors.background,
      ),
      const SemanticContrastPair(
        'legacy light body',
        LightColors.bodyText,
        LightColors.background,
      ),
      const SemanticContrastPair(
        'legacy light muted',
        LightColors.mutedText,
        LightColors.background,
      ),
      const SemanticContrastPair(
        'legacy light secondary',
        LightColors.secondaryText,
        LightColors.background,
      ),
      const SemanticContrastPair(
        'legacy dark primary',
        DarkColors.text,
        DarkColors.background,
      ),
      const SemanticContrastPair(
        'legacy dark body',
        DarkColors.bodyText,
        DarkColors.background,
      ),
      const SemanticContrastPair(
        'legacy dark muted',
        DarkColors.mutedText,
        DarkColors.background,
      ),
      const SemanticContrastPair(
        'legacy dark secondary',
        DarkColors.secondaryText,
        DarkColors.background,
      ),
    ];

    for (final pair in legacyPairs) {
      expect(
        _contrast(pair.foreground, pair.background),
        greaterThanOrEqualTo(4.5),
        reason: pair.name,
      );
    }
  });
}

double _contrast(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
