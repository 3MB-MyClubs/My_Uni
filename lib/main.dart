import 'package:flutter/material.dart';
import 'screens/auth_choice_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
// import 'screens/feed_screen.dart';
// import 'screens/admin_dashboard.dart';
import 'screens/main_nav_screen.dart';
import 'services/auth_service.dart';
import 'services/mock_data.dart';
import 'services/app_colors.dart';
import 'services/message_service.dart';
import 'services/notification_service.dart';
import 'services/user_prefs_service.dart';
import 'services/content_store.dart';
import 'services/user_state.dart';
import 'services/view_tracker.dart';
import 'services/personalization_service.dart';
import 'services/campus_pulse_service.dart';
import 'services/theme_service.dart';
import 'services/heatmap_repository.dart';
import 'services/location_permission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //örnek yorum
  await messageService.initialize();
  await notificationService.initialize();
  await userPrefsService.initialize();
  userPrefsService.loadAllPhotos();
  await contentStore.initialize();
  await viewTracker.initialize();
  await personalizationService.initialize();
  await themeService.initialize();
  await localHeatmapRepository.initialize();
  await campusPulseService.initialize();
  await locationPermissionService.initialize();
  contentStore.applyToLists();
  contentStore.loadBoardMemberRequests();
  contentStore.loadBoardMemberIds();
  contentStore.loadBoardMemberTitles();
  // Restore any dynamic notifications that were generated at runtime.
  final dynNotifs = contentStore.loadDynamicNotifications();
  if (dynNotifs != null) {
    userState.dynamicNotifications
      ..clear()
      ..addAll(dynNotifs);
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _showLogin = false;
  bool _showSignUp = false;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _savePrefs();
    }
  }

  void _savePrefs() {
    final uid = authService.currentUser?.id ?? authService.currentAdmin?.id;
    if (uid != null) {
      userPrefsService.save(uid);
      personalizationService.save(uid);
      campusPulseService.save(uid);
    }
    contentStore.saveAll(userState.dynamicNotifications);
  }

  void _onLogin() {
    setState(() {
      _loggedIn = true;
      _showLogin = false;
      _showSignUp = false;
    });
    final currentUserId =
        authService.currentUser?.id ?? authService.currentAdmin?.id;
    if (currentUserId != null) {
      messageService.setCurrentUserId(currentUserId);
      userPrefsService.load(currentUserId);
      personalizationService.load(currentUserId);
      campusPulseService.load(currentUserId);
    }
  }

  void _onSignUp() {
    setState(() {
      _showSignUp = false;
      _showLogin = true;
    });
  }

  // Helper for custom back navigation
  void handleBack() {
    setState(() {
      if (_showLogin) {
        _showLogin = false;
      } else if (_showSignUp) {
        _showSignUp = false;
      }
    });
  }

  ThemeData _buildTheme(bool isDark) {
    // Use raw DarkColors/LightColors (const) — AppColors getters read from
    // themeService.isDark which may differ from the isDark param here.
    final bg     = isDark ? DarkColors.background    : LightColors.background;
    final crd    = isDark ? DarkColors.card          : LightColors.card;
    final txt    = isDark ? DarkColors.text          : LightColors.text;
    final sub    = isDark ? DarkColors.secondaryText : LightColors.secondaryText;
    final div    = isDark ? DarkColors.divider       : LightColors.divider;
    final ltRed  = isDark ? DarkColors.lightRed      : LightColors.lightRed;
    final lGray  = isDark ? DarkColors.lightGray     : LightColors.lightGray;
    final bright = isDark ? Brightness.dark          : Brightness.light;
    const red    = AppColors.primaryRed;

    return ThemeData(
      brightness: bright,
      colorScheme: ColorScheme(
        brightness: bright,
        primary: red,
        onPrimary: Colors.white,
        secondary: AppColors.accentGold,
        onSecondary: isDark ? Colors.black : Colors.white,
        error: const Color(0xFFCF6679),
        onError: Colors.black,
        surface: crd,
        onSurface: txt,
      ),
      scaffoldBackgroundColor: bg,
      cardColor: crd,
      canvasColor: crd,
      dividerColor: div,
      appBarTheme: AppBarTheme(
        backgroundColor: crd,
        foregroundColor: txt,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: crd,
        selectedItemColor: red,
        unselectedItemColor: sub,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: crd,
        indicatorColor: ltRed,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryRed);
          }
          return IconThemeData(color: sub);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w600);
          }
          return TextStyle(color: sub);
        }),
      ),
      textTheme: TextTheme(
        bodyLarge:   TextStyle(color: txt),
        bodyMedium:  TextStyle(color: txt),
        bodySmall:   TextStyle(color: sub),
        titleLarge:  TextStyle(color: txt, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: txt),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: red,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          textStyle: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lGray,
        hintStyle: TextStyle(color: sub),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ltRed,
        labelStyle: TextStyle(color: AppColors.primaryRed),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? red : sub,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.darkRed : lGray,
        ),
      ),
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final isDark = themeService.isDark;
        Widget homeWidget;
        if (_loggedIn ||
            authService.currentUser != null ||
            authService.currentAdmin != null) {
          final isSuperAdmin = authService.currentAdmin?.id == appAdmin.id;
          final isAdmin = isSuperAdmin;
          final currentUserId =
              authService.currentUser?.id ?? authService.currentAdmin?.id;
          if (currentUserId != null) {
            messageService.setCurrentUserId(currentUserId);
            userPrefsService.load(currentUserId);
            personalizationService.load(currentUserId);
            campusPulseService.load(currentUserId);
          }
          homeWidget = MainNavScreen(
            isAdmin: isAdmin,
            onLogout: () {
              _savePrefs();
              setState(() {
                _loggedIn = false;
                _showLogin = false;
                _showSignUp = false;
              });
            },
          );
        } else if (_showLogin) {
          homeWidget = AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: LoginScreen(onLogin: _onLogin, onBack: handleBack),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        } else if (_showSignUp) {
          homeWidget = AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: SignUpScreen(onSignUp: _onSignUp, onBack: handleBack),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        } else {
          homeWidget = AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: AuthChoiceScreen(
              onLogin: () => setState(() => _showLogin = true),
              onSignUp: () => setState(() => _showSignUp = true),
              onAdminLogin: _onLogin,
            ),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'University Social App',
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: _buildTheme(false),
          darkTheme: _buildTheme(true),
          home: homeWidget,
        );
      },
    );
  }
}
