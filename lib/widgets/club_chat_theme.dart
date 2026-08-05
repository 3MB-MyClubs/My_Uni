import 'package:flutter/material.dart';

import '../services/app_colors.dart';
import '../services/theme_service.dart';

/// Palette for one club community, derived from that club's accent colour.
///
/// Mirrors `makeClubTheme(accent, dark)` from the Club Community design: every
/// hairline, tint, and bubble gradient is the club's own colour at a known
/// opacity, layered over the app's light/dark surfaces.
class ClubChatTheme {
  final bool isDark;
  final Color accent;

  /// Accent adjusted for legibility on the current surface.
  final Color red;
  final Color redDeep;

  /// Accent at low opacity — chip and card fills.
  final Color ltRed;
  final Color border;
  final Color borderB;
  final Color hair;
  final Color glow;

  final Color body;
  final Color card;
  final Color sheet;
  final Color solid;
  final Color input;

  final Color text;
  final Color textSoft;
  final Color textMuted;
  final Color sub;

  const ClubChatTheme._({
    required this.isDark,
    required this.accent,
    required this.red,
    required this.redDeep,
    required this.ltRed,
    required this.border,
    required this.borderB,
    required this.hair,
    required this.glow,
    required this.body,
    required this.card,
    required this.sheet,
    required this.solid,
    required this.input,
    required this.text,
    required this.textSoft,
    required this.textMuted,
    required this.sub,
  });

  factory ClubChatTheme.of(Color accent) {
    final dark = themeService.isDark;
    return ClubChatTheme._(
      isDark: dark,
      accent: accent,
      red: dark ? shade(accent, 30) : accent,
      redDeep: shade(accent, -22),
      ltRed: accent.withValues(alpha: dark ? 0.20 : 0.085),
      border: dark ? AppColors.divider : accent.withValues(alpha: 0.13),
      borderB: dark ? AppColors.glassEdge : accent.withValues(alpha: 0.24),
      hair: dark
          ? Colors.white.withValues(alpha: 0.06)
          : accent.withValues(alpha: 0.075),
      glow: accent.withValues(alpha: dark ? 0.18 : 0.07),
      body: AppColors.background,
      card: AppColors.card,
      sheet: AppColors.card,
      solid: AppColors.surfaceAlt,
      // The club composer sits on the light card surface, so its input should
      // stay white there. Keep the existing raised surface in dark mode.
      input: dark ? AppColors.surfaceAlt : AppColors.card,
      text: AppColors.text,
      textSoft: dark
          ? Colors.white.withValues(alpha: 0.86)
          : const Color(0xFF3A1828),
      textMuted: AppColors.secondaryText,
      sub: AppColors.secondaryText.withValues(alpha: dark ? 0.75 : 0.9),
    );
  }

  /// Gradient used for own bubbles, the club monogram, and primary pills.
  LinearGradient get meGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [shade(accent, 16), accent, shade(accent, -18)],
    stops: const [0, 0.55, 1],
  );

  /// Same ramp, angled for the bold announcement card.
  LinearGradient get announceGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [shade(accent, 10), accent, shade(accent, -16)],
    stops: const [0, 0.6, 1],
  );

  static Color shade(Color color, int amount) => Color.fromARGB(
    (color.a * 255).round(),
    ((color.r * 255).round() + amount).clamp(0, 255),
    ((color.g * 255).round() + amount).clamp(0, 255),
    ((color.b * 255).round() + amount).clamp(0, 255),
  );
}
