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

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //örnek yorum
  await messageService.initialize();
  await notificationService.initialize();
  await userPrefsService.initialize();
  await contentStore.initialize();
  await viewTracker.initialize();
  contentStore.applyToLists();
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
    if (uid != null) userPrefsService.save(uid);
  }

  void _onLogin() {
    setState(() {
      _loggedIn = true;
      _showLogin = false;
      _showSignUp = false;
    });
    final currentUserId = authService.currentUser?.id ?? authService.currentAdmin?.id;
    if (currentUserId != null) {
      messageService.setCurrentUserId(currentUserId);
      userPrefsService.load(currentUserId);
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

  @override
  Widget build(BuildContext context) {
    Widget homeWidget;
    if (_loggedIn || authService.currentUser != null || authService.currentAdmin != null) {
      final isSuperAdmin = authService.currentAdmin?.id == appAdmin.id;
      final isAdmin = isSuperAdmin;
      final currentUserId = authService.currentUser?.id ?? authService.currentAdmin?.id;
      if (currentUserId != null) {
        messageService.setCurrentUserId(currentUserId);
        // Load persisted prefs for this session (no-op if already loaded).
        userPrefsService.load(currentUserId);
      }
      homeWidget = MainNavScreen(
        isAdmin: isAdmin,
        onLogout: () {
          _savePrefs(); // persist before clearing session
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
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'University Social App',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.primaryRed,
          onPrimary: Colors.white,
          secondary: AppColors.accentGold,
          onSecondary: Colors.black,
          error: Color(0xFFCF6679),
          onError: Colors.black,
          surface: AppColors.card,
          onSurface: AppColors.text,
        ),
        scaffoldBackgroundColor: AppColors.background,
        cardColor: AppColors.card,
        canvasColor: AppColors.card,
        dividerColor: AppColors.divider,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.card,
          foregroundColor: AppColors.text,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.card,
          selectedItemColor: AppColors.primaryRed,
          unselectedItemColor: AppColors.secondaryText,
          type: BottomNavigationBarType.fixed,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.card,
          indicatorColor: AppColors.lightRed,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primaryRed);
            }
            return const IconThemeData(color: AppColors.secondaryText);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  color: AppColors.primaryRed, fontWeight: FontWeight.w600);
            }
            return const TextStyle(color: AppColors.secondaryText);
          }),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.text),
          bodyMedium: TextStyle(color: AppColors.text),
          bodySmall: TextStyle(color: AppColors.secondaryText),
          titleLarge: TextStyle(
              color: AppColors.text, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: AppColors.text),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightGray,
          hintStyle: const TextStyle(color: AppColors.secondaryText),
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.primaryRed, width: 1.5),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: AppColors.lightRed,
          labelStyle: TextStyle(color: AppColors.primaryRed),
        ),
        switchTheme: SwitchThemeData(
          thumbColor:
              WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
                  ? AppColors.primaryRed
                  : AppColors.secondaryText),
          trackColor:
              WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
                  ? AppColors.darkRed
                  : AppColors.lightGray),
        ),
        useMaterial3: true,
      ),
      home: homeWidget,
    );
  }
}
