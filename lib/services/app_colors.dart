import 'package:flutter/material.dart';
import 'theme_service.dart';

// ─── Raw dark-theme constants (used in ThemeData builder, not widget code) ────
class DarkColors {
  static const Color background = Color(0xFF000000);
  static const Color card = Color(0xFF0A0A0A);
  static const Color surfaceAlt = Color(0xFF141414);
  static const Color primaryRed = Color(0xFF9E2045);
  static const Color darkRed = Color(0xFF6A1530);
  static const Color lightRed = Color(0x1A9E2045);
  static const Color text = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB8B8B8);
  static const Color lightGray = Color(0xFF1F1F1F);
  static const Color darkGray = Color(0xFF121212);
  static const Color divider = Color(0xFF2A2A2A);
  static const Color accentGold = Color(0xFFE8C84A);
  static const Color cardGlow = Color(0x189E2045);
  static const Color glassEdge = Color(0x1AFFFFFF);
}

// ─── Theme-aware dynamic color accessors (use in all widget code) ─────────────
class AppColors {
  // Same in both themes — kept const for Icon/BoxDecoration const usage
  static const Color primaryRed = Color(0xFF9E2045);
  static const Color darkRed = Color(0xFF6A1530);

  // Theme-sensitive: return dark or light value based on current preference
  static Color get background =>
      themeService.isDark ? DarkColors.background : LightColors.background;
  static Color get card =>
      themeService.isDark ? DarkColors.card : LightColors.card;
  static Color get surfaceAlt =>
      themeService.isDark ? DarkColors.surfaceAlt : LightColors.surfaceAlt;
  static Color get text =>
      themeService.isDark ? DarkColors.text : LightColors.text;
  static Color get secondaryText => themeService.isDark
      ? DarkColors.secondaryText
      : LightColors.secondaryText;
  static Color get lightGray =>
      themeService.isDark ? DarkColors.lightGray : LightColors.lightGray;
  static Color get darkGray =>
      themeService.isDark ? DarkColors.darkGray : LightColors.darkGray;
  static Color get divider =>
      themeService.isDark ? DarkColors.divider : LightColors.divider;
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
  static const Color secondaryText = Color(0xFF9A7888);
  static const Color lightGray = Color(0xFFEDE2DE);
  static const Color darkGray = Color(0xFFD4C4BE);
  static const Color divider = Color(0x1F9E2045);
  static const Color accentGold = Color(0xFFB8943A);
  static const Color cardGlow = Color(0x089E2045);
  static const Color glassEdge = Color(0x1F9E2045);
}
