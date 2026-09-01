import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';

/// Semantic foreground/background pairings for areas that intentionally keep
/// their own surface ramps. These preserve the distinct Chats, ClubUp,
/// Profiles, and Campus ID designs without reintroducing fixed text colors.
@immutable
class SpecializedSemanticPalette {
  const SpecializedSemanticPalette({
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.subtleSurface,
    required this.onSubtleSurface,
    required this.supporting,
    required this.brand,
    required this.onBrand,
    required this.brandForeground,
    required this.positive,
    required this.onPositive,
    required this.destructive,
    required this.onDestructive,
  });

  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;
  final Color subtleSurface;
  final Color onSubtleSurface;
  final Color supporting;
  final Color brand;
  final Color onBrand;
  final Color brandForeground;
  final Color positive;
  final Color onPositive;
  final Color destructive;
  final Color onDestructive;

  List<SemanticContrastPair> get contrastPairs => [
    SemanticContrastPair('primary / background', onBackground, background),
    SemanticContrastPair('primary / surface', onSurface, surface),
    SemanticContrastPair(
      'primary / subtle surface',
      onSubtleSurface,
      subtleSurface,
    ),
    SemanticContrastPair('supporting / surface', supporting, surface),
    SemanticContrastPair('text / brand', onBrand, brand),
    SemanticContrastPair('brand text / surface', brandForeground, surface),
    SemanticContrastPair('text / positive', onPositive, positive),
    SemanticContrastPair('text / destructive', onDestructive, destructive),
  ];
}

abstract final class SpecializedSemanticPalettes {
  static SpecializedSemanticPalette chats(ThemeData theme) => _neutral(
    theme,
    lightBackground: const Color(0xFFFAF9F6),
    darkBackground: const Color(0xFF121212),
    lightSurface: const Color(0xFFFFFFFF),
    darkSurface: const Color(0xFF1A1A1A),
    lightSubtleSurface: const Color(0xFFEFEEEF),
    darkSubtleSurface: const Color(0xFF2D2D2D),
  );

  static SpecializedSemanticPalette clubUp(ThemeData theme) => _neutral(
    theme,
    lightBackground: const Color(0xFFFAF9F6),
    darkBackground: const Color(0xFF121212),
    lightSurface: const Color(0xFFFFFFFF),
    darkSurface: const Color(0xFF1E1E1E),
    lightSubtleSurface: const Color(0xFFF4F4F5),
    darkSubtleSurface: const Color(0xFF2D2D2D),
  );

  static SpecializedSemanticPalette profiles(ThemeData theme) => _neutral(
    theme,
    lightBackground: const Color(0xFFFAF9F6),
    darkBackground: const Color(0xFF09090B),
    lightSurface: const Color(0xFFFFFFFF),
    darkSurface: const Color(0xFF18181B),
    lightSubtleSurface: const Color(0xFFF4F4F5),
    darkSubtleSurface: const Color(0xFF27272A),
  );

  static SpecializedSemanticPalette clubProfiles(ThemeData theme) => _neutral(
    theme,
    lightBackground: const Color(0xFFFAF9F6),
    darkBackground: const Color(0xFF0A0A0A),
    lightSurface: const Color(0xFFFFFFFF),
    darkSurface: const Color(0xFF121212),
    lightSubtleSurface: const Color(0xFFF4F4F5),
    darkSubtleSurface: const Color(0xFF1E1E1E),
    darkBrandForeground: const Color(0xFFFA526B),
  );

  static SpecializedSemanticPalette campusId(ThemeData theme) {
    final semantic =
        theme.extension<AppSemanticColors>() ??
        AppSemanticColors.fallbackFor(theme);
    final isDark = theme.brightness == Brightness.dark;
    return SpecializedSemanticPalette(
      background: theme.scaffoldBackgroundColor,
      onBackground: semantic.textPrimary,
      surface: isDark ? const Color(0xFF191416) : const Color(0xFFFFFFFF),
      onSurface: semantic.textPrimary,
      subtleSurface: isDark ? const Color(0xFF241F21) : const Color(0xFFF5EDEA),
      onSubtleSurface: semantic.textPrimary,
      supporting: semantic.highContrast
          ? semantic.textMuted
          : isDark
          ? const Color(0xFFB8ACB2)
          : const Color(0xFF715361),
      // The physical ID remains fixed KU burgundy in every appearance mode.
      brand: const Color(0xFF8C1D40),
      onBrand: const Color(0xFFFFFFFF),
      brandForeground: semantic.highContrast
          ? semantic.onBrandSurface
          : isDark
          ? const Color(0xFFFFB1C4)
          : const Color(0xFF8C1D40),
      positive: semantic.positive,
      onPositive: semantic.onPositive,
      destructive: semantic.destructive,
      onDestructive: semantic.onDestructive,
    );
  }

  static SpecializedSemanticPalette _neutral(
    ThemeData theme, {
    required Color lightBackground,
    required Color darkBackground,
    required Color lightSurface,
    required Color darkSurface,
    required Color lightSubtleSurface,
    required Color darkSubtleSurface,
    Color darkBrandForeground = const Color(0xFFE8A1A6),
  }) {
    final semantic =
        theme.extension<AppSemanticColors>() ??
        AppSemanticColors.fallbackFor(theme);
    final isDark = theme.brightness == Brightness.dark;
    final primary = semantic.highContrast
        ? semantic.textPrimary
        : isDark
        ? const Color(0xFFFAFAFA)
        : const Color(0xFF18181B);
    final supporting = semantic.highContrast
        ? semantic.textMuted
        : isDark
        ? const Color(0xFFA1A1AA)
        : const Color(0xFF6F6F78);
    final brand = semantic.highContrast
        ? semantic.brand
        : const Color(0xFF800020);

    return SpecializedSemanticPalette(
      background: isDark ? darkBackground : lightBackground,
      onBackground: primary,
      surface: isDark ? darkSurface : lightSurface,
      onSurface: primary,
      subtleSurface: isDark ? darkSubtleSurface : lightSubtleSurface,
      onSubtleSurface: primary,
      supporting: supporting,
      brand: brand,
      onBrand: semantic.onBrand,
      brandForeground: semantic.highContrast
          ? semantic.onBrandSurface
          : isDark
          ? darkBrandForeground
          : const Color(0xFF800020),
      positive: semantic.positive,
      onPositive: semantic.onPositive,
      destructive: semantic.destructive,
      onDestructive: semantic.onDestructive,
    );
  }
}
