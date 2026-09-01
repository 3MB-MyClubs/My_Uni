import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import '../theme/specialized_semantic_palettes.dart';

/// Design tokens for the ClubUp-Desings Figma handoff.
///
/// Shared by every area redesigned from that file so far — STUDENT SEARCH
/// (`clubup-search`, `search-filter`, `clubup-filter`, `clubup-major`) and
/// STUDENT EVENTS POV (`clubup-events`, `event-detail`,
/// `event-detail-invite`) — which all use one neutral-zinc palette on a
/// single `#800020` burgundy accent.
///
/// These are deliberately kept *beside* [AppColors] rather than replacing it.
/// The rest of the app still runs on the warm `#9E2045` palette, and adopting
/// these globally would restyle every screen before its own design has been
/// reviewed. As each remaining area is redesigned, it moves onto these.
class ClubUpColors {
  const ClubUpColors._();

  /// Active-theme semantic pairings while the legacy getters remain source
  /// compatible with existing handoff widgets.
  static SpecializedSemanticPalette of(BuildContext context) =>
      SpecializedSemanticPalettes.clubUp(Theme.of(context));

  static bool get _dark => themeService.isDark;

  /// Page background — `#FAF9F6` / `#121212`.
  static Color get background =>
      _dark ? const Color(0xFF121212) : const Color(0xFFFAF9F6);

  /// Card and sheet surface — `#FFFFFF` / `#1E1E1E`.
  static Color get card => _dark ? const Color(0xFF1E1E1E) : Colors.white;

  /// Hairline around cards and chips — `#E4E4E7` / `#2D2D2D`.
  static Color get border =>
      _dark ? const Color(0xFF2D2D2D) : const Color(0xFFE4E4E7);

  /// Primary text — `#18181B` / `#FAFAFA`.
  static Color get text =>
      _dark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B);

  /// Secondary text — `#71717A` / `#A1A1AA`.
  static Color get muted =>
      _dark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

  /// Search-field fill — `rgba(228,228,231,0.5)` / `#2D2D2D`.
  static Color get field =>
      _dark ? const Color(0xFF2D2D2D) : const Color(0x80E4E4E7);

  /// Flat chip / section-header fill — `#F4F4F5` / `#2D2D2D`.
  static Color get chip =>
      _dark ? const Color(0xFF2D2D2D) : const Color(0xFFF4F4F5);

  /// The one accent in the whole handoff. Identical in both themes.
  static const Color accent = Color(0xFF800020);

  /// Accent *text*. `#800020` fails contrast on a `#1E1E1E` card, so the dark
  /// theme lifts it to `#E8A1A6` exactly as the Figma dark frames do.
  static Color get accentText => _dark ? const Color(0xFFE8A1A6) : accent;

  /// Tinted surface behind a selected card — `#FDF2F4` in light. The dark
  /// frames have no equivalent, so this is the same hue carried onto `card`.
  static Color get accentSurface =>
      _dark ? const Color(0xFF2A1319) : const Color(0xFFFDF2F4);

  /// Scrim behind a bottom sheet — `rgba(24,24,27,0.4)`.
  static Color get scrim =>
      _dark ? const Color(0x8C000000) : const Color(0x6618181B);

  /// Card lift — `0 4px 5px rgba(128,0,32,0.07)` / `rgba(0,0,0,0.4)`.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: _dark ? const Color(0x66000000) : const Color(0x12800020),
      offset: const Offset(0, 4),
      blurRadius: 5,
    ),
  ];
}

/// The handoff's typeface. Bundled under `assets/fonts/` — see `pubspec.yaml`.
const String kClubUpFontFamily = 'Figtree';

/// A [TextStyle] in Figtree. The design uses five weights: Regular (400),
/// Medium (500), SemiBold (600), Bold (700) and ExtraBold (800).
TextStyle figtree({
  required double size,
  required FontWeight weight,
  required Color color,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: kClubUpFontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}
