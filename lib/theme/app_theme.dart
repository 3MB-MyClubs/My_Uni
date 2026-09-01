import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_colors.dart';
import 'app_semantic_colors.dart';

enum AppThemeVariant {
  light(Brightness.light, false),
  dark(Brightness.dark, false),
  highContrastLight(Brightness.light, true),
  highContrastDark(Brightness.dark, true);

  const AppThemeVariant(this.brightness, this.highContrast);

  final Brightness brightness;
  final bool highContrast;
}

/// Builds a complete theme from explicit inputs only. In particular this file
/// never reads ThemeService, so constructing an inactive theme cannot leak the
/// currently selected theme's colors into it.
abstract final class AppTheme {
  static ThemeData build(AppThemeVariant variant) {
    final isDark = variant.brightness == Brightness.dark;
    final highContrast = variant.highContrast;
    final semantic = _semanticColors(variant);

    final background = switch (variant) {
      AppThemeVariant.light => LightColors.background,
      AppThemeVariant.dark => DarkColors.background,
      AppThemeVariant.highContrastLight => const Color(0xFFFFFFFF),
      AppThemeVariant.highContrastDark => const Color(0xFF000000),
    };
    final card = switch (variant) {
      AppThemeVariant.light => LightColors.card,
      AppThemeVariant.dark => DarkColors.card,
      AppThemeVariant.highContrastLight => const Color(0xFFFFFFFF),
      AppThemeVariant.highContrastDark => const Color(0xFF080808),
    };
    final elevatedSurface = switch (variant) {
      AppThemeVariant.light => LightColors.surfaceAlt,
      AppThemeVariant.dark => DarkColors.surfaceAlt,
      AppThemeVariant.highContrastLight => const Color(0xFFF4F0F2),
      AppThemeVariant.highContrastDark => const Color(0xFF151515),
    };
    final divider = switch (variant) {
      AppThemeVariant.light => LightColors.divider,
      AppThemeVariant.dark => DarkColors.divider,
      AppThemeVariant.highContrastLight => const Color(0xFF5A4650),
      AppThemeVariant.highContrastDark => const Color(0xFFBFBFBF),
    };
    final field = switch (variant) {
      AppThemeVariant.light => LightColors.lightGray,
      AppThemeVariant.dark => DarkColors.lightGray,
      AppThemeVariant.highContrastLight => const Color(0xFFE8E1E4),
      AppThemeVariant.highContrastDark => const Color(0xFF202020),
    };

    final scheme =
        ColorScheme.fromSeed(
          seedColor: semantic.brand,
          brightness: variant.brightness,
        ).copyWith(
          primary: semantic.brand,
          onPrimary: semantic.onBrand,
          primaryContainer: semantic.brandSurface,
          onPrimaryContainer: semantic.onBrandSurface,
          secondary: isDark ? const Color(0xFFD7B65B) : LightColors.accentGold,
          onSecondary: const Color(0xFF1D1600),
          error: semantic.destructive,
          onError: semantic.onDestructive,
          errorContainer: semantic.destructiveSurface,
          onErrorContainer: semantic.onDestructiveSurface,
          surface: card,
          onSurface: semantic.textPrimary,
          surfaceContainerHighest: elevatedSurface,
          outline: divider,
          outlineVariant: divider,
        );

    const buttonMotion = Duration(milliseconds: 160);
    final buttonOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return semantic.onBrand.withValues(alpha: 0.18);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return semantic.onBrand.withValues(alpha: 0.10);
      }
      return null;
    });
    final sharedButtonMotion = ButtonStyle(
      animationDuration: buttonMotion,
      overlayColor: buttonOverlay,
      splashFactory: InkRipple.splashFactory,
      enableFeedback: true,
    );

    final base = ThemeData(
      brightness: variant.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      cardColor: card,
      canvasColor: card,
      dividerColor: divider,
      extensions: [semantic],
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: _systemUiStyle(variant.brightness, background),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: scheme.primary,
        unselectedItemColor: semantic.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: semantic.brandSurface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? semantic.onBrandSurface
                : semantic.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? semantic.onBrandSurface
                : semantic.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : null,
          );
        }),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: semantic.textPrimary),
        displayMedium: TextStyle(color: semantic.textPrimary),
        displaySmall: TextStyle(color: semantic.textPrimary),
        headlineLarge: TextStyle(color: semantic.textPrimary),
        headlineMedium: TextStyle(color: semantic.textPrimary),
        headlineSmall: TextStyle(color: semantic.textPrimary),
        titleLarge: TextStyle(
          color: semantic.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(color: semantic.textPrimary),
        titleSmall: TextStyle(color: semantic.textPrimary),
        bodyLarge: TextStyle(color: semantic.textPrimary),
        bodyMedium: TextStyle(color: semantic.textPrimary),
        bodySmall: TextStyle(color: semantic.textSecondary),
        labelLarge: TextStyle(color: semantic.textPrimary),
        labelMedium: TextStyle(color: semantic.textSecondary),
        labelSmall: TextStyle(color: semantic.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ).merge(sharedButtonMotion),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ).merge(sharedButtonMotion),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(
            color: highContrast ? scheme.onSurface : divider,
            width: highContrast ? 2 : 1,
          ),
        ).merge(sharedButtonMotion),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: semantic.onBrandSurface,
        ).merge(sharedButtonMotion),
      ),
      iconButtonTheme: IconButtonThemeData(style: sharedButtonMotion),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        hintStyle: TextStyle(color: semantic.textMuted),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: highContrast
              ? BorderSide(color: scheme.onSurface, width: 1.5)
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: highContrast
              ? BorderSide(color: scheme.onSurface, width: 1.5)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: semantic.brand, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: elevatedSurface),
      popupMenuTheme: PopupMenuThemeData(color: elevatedSurface),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevatedSurface,
        modalBackgroundColor: elevatedSurface,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: semantic.brandSurface,
        selectedColor: semantic.brand,
        labelStyle: TextStyle(color: semantic.onBrandSurface),
        secondaryLabelStyle: TextStyle(color: semantic.onBrand),
        side: highContrast ? BorderSide(color: scheme.onSurface) : null,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? semantic.onBrand
              : semantic.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? semantic.brand : field,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _AppPageTransitionsBuilder(),
          TargetPlatform.iOS: _AppPageTransitionsBuilder(),
          TargetPlatform.macOS: _AppPageTransitionsBuilder(),
          TargetPlatform.windows: _AppPageTransitionsBuilder(),
          TargetPlatform.linux: _AppPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkRipple.splashFactory,
      useMaterial3: true,
    );

    return base;
  }

  static AppSemanticColors _semanticColors(AppThemeVariant variant) {
    return switch (variant) {
      AppThemeVariant.light => const AppSemanticColors(
        highContrast: false,
        textPrimary: Color(0xFF1A0610),
        textSecondary: Color(0xFF5D3F4D),
        textMuted: Color(0xFF715361),
        brand: Color(0xFF9E2045),
        onBrand: Color(0xFFFFFFFF),
        brandSurface: Color(0xFFF5E3E9),
        onBrandSurface: Color(0xFF74132F),
        positive: Color(0xFF147A43),
        onPositive: Color(0xFFFFFFFF),
        positiveSurface: Color(0xFFE0F3E8),
        onPositiveSurface: Color(0xFF07592D),
        destructive: Color(0xFFB42318),
        onDestructive: Color(0xFFFFFFFF),
        destructiveSurface: Color(0xFFFDE8E7),
        onDestructiveSurface: Color(0xFF8C1710),
        onMedia: Color(0xFFFFFFFF),
        mediaScrim: Color(0xCC000000),
        mediaScrimSoft: Color(0x00000000),
      ),
      AppThemeVariant.dark => const AppSemanticColors(
        highContrast: false,
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFD5CAD0),
        textMuted: Color(0xFFB8ACB2),
        brand: Color(0xFF9E2045),
        onBrand: Color(0xFFFFFFFF),
        brandSurface: Color(0xFF39131F),
        onBrandSurface: Color(0xFFFFB1C4),
        positive: Color(0xFF6DDA9B),
        onPositive: Color(0xFF07180E),
        positiveSurface: Color(0xFF173C29),
        onPositiveSurface: Color(0xFF9FF1BD),
        destructive: Color(0xFFFFB4AB),
        onDestructive: Color(0xFF370001),
        destructiveSurface: Color(0xFF5C1713),
        onDestructiveSurface: Color(0xFFFFDAD6),
        onMedia: Color(0xFFFFFFFF),
        mediaScrim: Color(0xCC000000),
        mediaScrimSoft: Color(0x00000000),
      ),
      AppThemeVariant.highContrastLight => const AppSemanticColors(
        highContrast: true,
        textPrimary: Color(0xFF000000),
        textSecondary: Color(0xFF26151D),
        textMuted: Color(0xFF49333D),
        brand: Color(0xFF76002B),
        onBrand: Color(0xFFFFFFFF),
        brandSurface: Color(0xFFFFD9E3),
        onBrandSurface: Color(0xFF57001E),
        positive: Color(0xFF006B39),
        onPositive: Color(0xFFFFFFFF),
        positiveSurface: Color(0xFFD2F8DF),
        onPositiveSurface: Color(0xFF004D27),
        destructive: Color(0xFF8C0D0D),
        onDestructive: Color(0xFFFFFFFF),
        destructiveSurface: Color(0xFFFFDAD6),
        onDestructiveSurface: Color(0xFF690005),
        onMedia: Color(0xFFFFFFFF),
        mediaScrim: Color(0xD9000000),
        mediaScrimSoft: Color(0x00000000),
      ),
      AppThemeVariant.highContrastDark => const AppSemanticColors(
        highContrast: true,
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFF5EEF1),
        textMuted: Color(0xFFD9CED3),
        brand: Color(0xFFFFB1C4),
        onBrand: Color(0xFF33000E),
        brandSurface: Color(0xFF4F001B),
        onBrandSurface: Color(0xFFFFD9E3),
        positive: Color(0xFF7FF0AE),
        onPositive: Color(0xFF001C0C),
        positiveSurface: Color(0xFF00391D),
        onPositiveSurface: Color(0xFFA1F5C0),
        destructive: Color(0xFFFFB4AB),
        onDestructive: Color(0xFF370001),
        destructiveSurface: Color(0xFF690005),
        onDestructiveSurface: Color(0xFFFFDAD6),
        onMedia: Color(0xFFFFFFFF),
        mediaScrim: Color(0xD9000000),
        mediaScrimSoft: Color(0x00000000),
      ),
    };
  }

  static SystemUiOverlayStyle _systemUiStyle(
    Brightness brightness,
    Color background,
  ) {
    final base = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: background,
      systemNavigationBarIconBrightness: brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }
}

/// Keeps status/navigation icons legible on screens that draw their own
/// edge-to-edge chrome instead of using an [AppBar].
class AppSystemUiOverlay extends StatelessWidget {
  const AppSystemUiOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme._systemUiStyle(
        theme.brightness,
        theme.scaffoldBackgroundColor,
      ),
      child: child,
    );
  }
}

class _AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (route.isFirst || reduceMotion) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.045, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
