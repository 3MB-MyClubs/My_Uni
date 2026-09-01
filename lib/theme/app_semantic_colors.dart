import 'package:flutter/material.dart';

/// Semantic colors whose meaning stays stable while their values change with
/// the active [ThemeData]. Prefer these roles to fixed black/white values.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.highContrast,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brand,
    required this.onBrand,
    required this.brandSurface,
    required this.onBrandSurface,
    required this.positive,
    required this.onPositive,
    required this.positiveSurface,
    required this.onPositiveSurface,
    required this.destructive,
    required this.onDestructive,
    required this.destructiveSurface,
    required this.onDestructiveSurface,
    required this.onMedia,
    required this.mediaScrim,
    required this.mediaScrimSoft,
  });

  final bool highContrast;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color brand;
  final Color onBrand;
  final Color brandSurface;
  final Color onBrandSurface;

  final Color positive;
  final Color onPositive;
  final Color positiveSurface;
  final Color onPositiveSurface;

  final Color destructive;
  final Color onDestructive;
  final Color destructiveSurface;
  final Color onDestructiveSurface;

  /// A fixed light foreground for text and essential icons over media.
  final Color onMedia;

  /// The darkest scrim stop. At this opacity white text remains above 4.5:1
  /// even when the underlying image is pure white.
  final Color mediaScrim;
  final Color mediaScrimSoft;

  static AppSemanticColors of(BuildContext context) {
    final colors = Theme.of(context).extension<AppSemanticColors>();
    if (colors != null) return colors;

    // Keeps independently embedded widgets and older test harnesses source
    // compatible. The real app installs the full extension in every variant.
    final theme = Theme.of(context);
    return fallbackFor(
      theme,
      highContrast: MediaQuery.maybeOf(context)?.highContrast ?? false,
    );
  }

  static AppSemanticColors fallbackFor(
    ThemeData theme, {
    bool highContrast = false,
  }) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return AppSemanticColors(
      highContrast: highContrast,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurface,
      textMuted: scheme.onSurface,
      brand: scheme.primary,
      onBrand: scheme.onPrimary,
      brandSurface: scheme.primaryContainer,
      onBrandSurface: scheme.onPrimaryContainer,
      positive: isDark ? const Color(0xFF6DDA9B) : const Color(0xFF147A43),
      onPositive: isDark ? const Color(0xFF07180E) : const Color(0xFFFFFFFF),
      positiveSurface: isDark
          ? const Color(0xFF173C29)
          : const Color(0xFFE0F3E8),
      onPositiveSurface: isDark
          ? const Color(0xFF9FF1BD)
          : const Color(0xFF07592D),
      destructive: scheme.error,
      onDestructive: scheme.onError,
      destructiveSurface: scheme.errorContainer,
      onDestructiveSurface: scheme.onErrorContainer,
      onMedia: const Color(0xFFFFFFFF),
      mediaScrim: const Color(0xCC000000),
      mediaScrimSoft: const Color(0x00000000),
    );
  }

  /// Named normal-text contracts used by the release contrast test.
  List<SemanticContrastPair> contrastPairs(ColorScheme scheme) => [
    SemanticContrastPair('primary text / surface', textPrimary, scheme.surface),
    SemanticContrastPair(
      'secondary text / surface',
      textSecondary,
      scheme.surface,
    ),
    SemanticContrastPair('muted text / surface', textMuted, scheme.surface),
    SemanticContrastPair('text / brand', onBrand, brand),
    SemanticContrastPair('text / brand surface', onBrandSurface, brandSurface),
    SemanticContrastPair('text / positive', onPositive, positive),
    SemanticContrastPair(
      'text / positive surface',
      onPositiveSurface,
      positiveSurface,
    ),
    SemanticContrastPair('text / destructive', onDestructive, destructive),
    SemanticContrastPair(
      'text / destructive surface',
      onDestructiveSurface,
      destructiveSurface,
    ),
  ];

  @override
  AppSemanticColors copyWith({
    bool? highContrast,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? brand,
    Color? onBrand,
    Color? brandSurface,
    Color? onBrandSurface,
    Color? positive,
    Color? onPositive,
    Color? positiveSurface,
    Color? onPositiveSurface,
    Color? destructive,
    Color? onDestructive,
    Color? destructiveSurface,
    Color? onDestructiveSurface,
    Color? onMedia,
    Color? mediaScrim,
    Color? mediaScrimSoft,
  }) {
    return AppSemanticColors(
      highContrast: highContrast ?? this.highContrast,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      brandSurface: brandSurface ?? this.brandSurface,
      onBrandSurface: onBrandSurface ?? this.onBrandSurface,
      positive: positive ?? this.positive,
      onPositive: onPositive ?? this.onPositive,
      positiveSurface: positiveSurface ?? this.positiveSurface,
      onPositiveSurface: onPositiveSurface ?? this.onPositiveSurface,
      destructive: destructive ?? this.destructive,
      onDestructive: onDestructive ?? this.onDestructive,
      destructiveSurface: destructiveSurface ?? this.destructiveSurface,
      onDestructiveSurface: onDestructiveSurface ?? this.onDestructiveSurface,
      onMedia: onMedia ?? this.onMedia,
      mediaScrim: mediaScrim ?? this.mediaScrim,
      mediaScrimSoft: mediaScrimSoft ?? this.mediaScrimSoft,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      highContrast: t < 0.5 ? highContrast : other.highContrast,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandSurface: Color.lerp(brandSurface, other.brandSurface, t)!,
      onBrandSurface: Color.lerp(onBrandSurface, other.onBrandSurface, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      onPositive: Color.lerp(onPositive, other.onPositive, t)!,
      positiveSurface: Color.lerp(positiveSurface, other.positiveSurface, t)!,
      onPositiveSurface: Color.lerp(
        onPositiveSurface,
        other.onPositiveSurface,
        t,
      )!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      onDestructive: Color.lerp(onDestructive, other.onDestructive, t)!,
      destructiveSurface: Color.lerp(
        destructiveSurface,
        other.destructiveSurface,
        t,
      )!,
      onDestructiveSurface: Color.lerp(
        onDestructiveSurface,
        other.onDestructiveSurface,
        t,
      )!,
      onMedia: Color.lerp(onMedia, other.onMedia, t)!,
      mediaScrim: Color.lerp(mediaScrim, other.mediaScrim, t)!,
      mediaScrimSoft: Color.lerp(mediaScrimSoft, other.mediaScrimSoft, t)!,
    );
  }
}

@immutable
class SemanticContrastPair {
  const SemanticContrastPair(
    this.name,
    this.foreground,
    this.background, {
    this.minimumRatio = 4.5,
  });

  final String name;
  final Color foreground;
  final Color background;
  final double minimumRatio;
}

extension AppSemanticColorsBuildContext on BuildContext {
  AppSemanticColors get semanticColors => AppSemanticColors.of(this);
}
