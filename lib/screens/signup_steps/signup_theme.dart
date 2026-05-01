import 'package:flutter/material.dart';

/// Colors and helpers for the signup flow (light cream theme).
/// These are intentionally separate from AppColors so the dark main app
/// is not affected.
class SC {
  SC._();

  // ── Palette ──────────────────────────────────────────────────
  static const Color bg           = Color(0xFFFBF8F6); // warm cream
  static const Color card         = Color(0xFFFFFFFF); // white
  static const Color ink          = Color(0xFF1A1A1C); // near-black
  static const Color body         = Color(0xFF3A3A3D); // body text
  static const Color muted        = Color(0xFF8A8A8E); // muted/placeholder
  static const Color hair         = Color(0x140B0B0C); // rgba(11,11,12,0.08) — field border
  static const Color hairStrong   = Color(0x240B0B0C); // rgba(11,11,12,0.14)
  static const Color burgundy     = Color(0xFF8C1D40); // KU brand
  static const Color burgundyDeep = Color(0xFF4E0F1C); // for info text
  static const Color burgundyTint = Color(0x148C1D40); // 8% burgundy — field focus ring / info bg

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
        : BorderRadius.circular(12);

    const hairSide   = BorderSide(color: SC.hair,     width: 1.5);
    const focusSide  = BorderSide(color: SC.burgundy, width: 1.5);
    const errorSide  = BorderSide(color: SC.burgundy, width: 1.5);

    return InputDecoration(
      labelText:  label,
      labelStyle: const TextStyle(color: SC.muted, fontSize: 14),
      hintText:   hint,
      hintStyle:  const TextStyle(color: SC.muted, fontSize: 15),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: SC.muted, fontSize: 14),
      errorText:  errorText,
      errorStyle: const TextStyle(color: SC.burgundy, fontSize: 12),
      filled:     true,
      fillColor:  SC.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border:             OutlineInputBorder(borderRadius: radius, borderSide: hairSide),
      enabledBorder:      OutlineInputBorder(borderRadius: radius, borderSide: hairSide),
      focusedBorder:      OutlineInputBorder(borderRadius: radius, borderSide: focusSide),
      errorBorder:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: errorSide),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: focusSide),
    );
  }

  // ── Shared primary button ─────────────────────────────────────
  static ButtonStyle primaryButtonStyle({Color bg = SC.burgundy, Color fg = Colors.white}) =>
      ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.1),
      );

  // ── Wrap content in the signup light theme ────────────────────
  static ThemeData lightTheme() => ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: SC.burgundy,
          onPrimary: Colors.white,
          surface: SC.bg,
          onSurface: SC.ink,
        ),
        scaffoldBackgroundColor: SC.bg,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: SC.card,
          labelStyle: const TextStyle(color: SC.muted),
          hintStyle: const TextStyle(color: SC.muted),
          errorStyle: const TextStyle(color: SC.burgundy, fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SC.hair, width: 1.5),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge:  TextStyle(color: SC.ink),
          bodyMedium: TextStyle(color: SC.ink),
          bodySmall:  TextStyle(color: SC.body),
        ),
        useMaterial3: true,
      );
}
