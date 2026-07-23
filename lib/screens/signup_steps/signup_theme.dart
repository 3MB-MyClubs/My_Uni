import 'package:flutter/material.dart';

import '../../services/app_colors.dart';
import '../../services/theme_service.dart';

/// Theme-aware colors and helpers for the signup flow.
///
/// Signup is part of the same authentication experience as Login, so it uses
/// the user's current app palette instead of forcing the old light-only one.
class SC {
  SC._();

  // ── Palette ──────────────────────────────────────────────────
  static Color get bg => AppColors.background;
  static Color get card => AppColors.card;
  static Color get ink => AppColors.text;
  static Color get body => AppColors.text.withValues(alpha: 0.76);
  static Color get muted => AppColors.secondaryText;
  static Color get hair => AppColors.divider;
  static Color get hairStrong =>
      AppColors.text.withValues(alpha: themeService.isDark ? 0.20 : 0.14);
  static Color get burgundy => AppColors.primaryRed;
  static Color get burgundyDeep =>
      themeService.isDark ? const Color(0xFFF0B3C5) : const Color(0xFF4E0F1C);
  static Color get burgundyTint => AppColors.lightRed;

  // ── Shared InputDecoration factory ───────────────────────────
  /// Pass [radiusTop] = true when the bottom radius should be square
  /// (e.g. when a dropdown is open beneath the field).
  static InputDecoration fieldDecoration({
    required String label,
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
    String? errorText,
    bool radiusTop = false,
  }) {
    final radius = radiusTop
        ? const BorderRadius.vertical(top: Radius.circular(12))
        : BorderRadius.all(Radius.circular(12));

    final hairSide = BorderSide(color: SC.hair, width: 1.5);
    final focusSide = BorderSide(color: SC.burgundy, width: 1.5);
    final errorSide = BorderSide(color: SC.burgundy, width: 1.5);

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: SC.muted, fontSize: 14),
      hintText: hint,
      hintStyle: TextStyle(color: SC.muted, fontSize: 15),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      suffixStyle: TextStyle(color: SC.muted, fontSize: 14),
      errorText: errorText,
      errorStyle: TextStyle(color: SC.burgundy, fontSize: 12),
      filled: true,
      fillColor: SC.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: radius, borderSide: hairSide),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: hairSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: focusSide,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: errorSide,
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: focusSide,
      ),
    );
  }

  // ── Shared primary button ─────────────────────────────────────
  static ButtonStyle primaryButtonStyle({Color? bg, Color fg = Colors.white}) =>
      ElevatedButton.styleFrom(
        backgroundColor: bg ?? SC.burgundy,
        foregroundColor: fg,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        elevation: 0,
        textStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      );

  // ── Wrap content in the signup light theme ────────────────────
  static ThemeData theme() => ThemeData(
    brightness: themeService.isDark ? Brightness.dark : Brightness.light,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: SC.burgundy,
          brightness: themeService.isDark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: SC.burgundy,
          onPrimary: Colors.white,
          surface: SC.bg,
          onSurface: SC.ink,
        ),
    scaffoldBackgroundColor: SC.bg,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SC.card,
      labelStyle: TextStyle(color: SC.muted),
      hintStyle: TextStyle(color: SC.muted),
      errorStyle: TextStyle(color: SC.burgundy, fontSize: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: SC.hair, width: 1.5),
      ),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: SC.ink),
      bodyMedium: TextStyle(color: SC.ink),
      bodySmall: TextStyle(color: SC.body),
    ),
    useMaterial3: true,
  );
}
