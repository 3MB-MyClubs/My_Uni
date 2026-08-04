import 'package:flutter/material.dart';
import 'theme_service.dart';

// ─── Raw dark-theme constants (used in ThemeData builder, not widget code) ────
// Warm near-black palette from the "Login Screen v2" design handoff: the base
// is a red-tinted black (#0C0608) and every surface is white layered over it,
// replacing the old neutral #121212 grays.
class DarkColors {
  static const Color background = Color(0xFF0C0608);
  static const Color card = Color(0xFF191416);
  static const Color surfaceAlt = Color(0xFF241F21);
  static const Color primaryRed = Color(0xFF9E2045);
  static const Color darkRed = Color(0xFF6A1530);
  static const Color lightRed = Color(0x1A9E2045);
  static const Color text = Color(0xFFFFFFFF);
  static const Color bodyText = Color(0xFFEFEDEE);
  static const Color mutedText = Color(0xFFC5BCC0);
  static const Color secondaryText = Color(0xFFAFA3A9);
  static const Color lightGray = Color(0xFF241F21);
  static const Color darkGray = Color(0xFF191416);
  static const Color divider = Color(0xFF332E30);
  static const Color borderStrong = Color(0xFF4A4245);
  static const Color accentGold = Color(0xFF9E2045);
  static const Color cardGlow = Color(0x189E2045);
  static const Color glassEdge = Color(0xFF332E30);
}

// ─── Theme-aware dynamic color accessors (use in all widget code) ─────────────
class AppColors {
  // Theme-sensitive: return dark or light value based on current preference
  static Color get primaryRed =>
      themeService.isDark ? DarkColors.primaryRed : LightColors.primaryRed;
  static Color get darkRed =>
      themeService.isDark ? DarkColors.darkRed : LightColors.darkRed;
  static Color get background =>
      themeService.isDark ? DarkColors.background : LightColors.background;
  static Color get card =>
      themeService.isDark ? DarkColors.card : LightColors.card;
  static Color get surfaceAlt =>
      themeService.isDark ? DarkColors.surfaceAlt : LightColors.surfaceAlt;
  static Color get text =>
      themeService.isDark ? DarkColors.text : LightColors.text;

  /// Running text — one step down from [text], for the body of a sentence whose
  /// subject is emphasised (a notification row's predicate after the actor's
  /// name). The design system's `textSoft`.
  static Color get bodyText =>
      themeService.isDark ? DarkColors.bodyText : LightColors.bodyText;

  /// Supporting text — quoted snippets, metadata lines. Between [bodyText] and
  /// [secondaryText]; the design system's `textMuted`.
  static Color get mutedText =>
      themeService.isDark ? DarkColors.mutedText : LightColors.mutedText;
  static Color get secondaryText => themeService.isDark
      ? DarkColors.secondaryText
      : LightColors.secondaryText;
  static Color get lightGray =>
      themeService.isDark ? DarkColors.lightGray : LightColors.lightGray;
  static Color get darkGray =>
      themeService.isDark ? DarkColors.darkGray : LightColors.darkGray;
  static Color get divider =>
      themeService.isDark ? DarkColors.divider : LightColors.divider;

  /// The heavier hairline the design system uses for outlined controls
  /// (secondary buttons) — roughly twice the weight of [divider].
  static Color get borderStrong => themeService.isDark
      ? DarkColors.borderStrong
      : LightColors.borderStrong;
  static Color get lightRed =>
      themeService.isDark ? DarkColors.lightRed : LightColors.lightRed;
  static Color get accentGold =>
      themeService.isDark ? DarkColors.accentGold : LightColors.accentGold;
  static Color get cardGlow =>
      themeService.isDark ? DarkColors.cardGlow : LightColors.cardGlow;
  static Color get glassEdge =>
      themeService.isDark ? DarkColors.glassEdge : LightColors.glassEdge;
}

// ─── Light theme — warm KU burgundy tones on off-white ───────────────────────
class LightColors {
  static const Color background = Color(0xFFFBF7F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF5EDEA);
  static const Color primaryRed = Color(0xFF9E2045);
  static const Color darkRed = Color(0xFF6A1530);
  static const Color lightRed = Color(0x179E2045);
  static const Color text = Color(0xFF1A0610);
  static const Color bodyText = Color(0xFF3A1828);
  static const Color mutedText = Color(0xFF7A5868);
  static const Color secondaryText = Color(0xFF9A7888);
  static const Color lightGray = Color(0xFFEDE2DE);
  static const Color darkGray = Color(0xFFD4C4BE);
  static const Color divider = Color(0x1F9E2045);
  static const Color borderStrong = Color(0x389E2045);
  static const Color accentGold = Color(0xFFB8943A);
  static const Color cardGlow = Color(0x089E2045);
  static const Color glassEdge = Color(0x1F9E2045);
}
