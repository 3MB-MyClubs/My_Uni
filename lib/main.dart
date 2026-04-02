import 'package:flutter/material.dart';
import 'screens/auth_choice_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
// import 'screens/feed_screen.dart';
// import 'screens/admin_dashboard.dart';
import 'screens/main_nav_screen.dart';
import 'services/auth_service.dart';
import 'services/app_colors.dart';
import 'services/message_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //örnek yorum
  await messageService.initialize();
  await notificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showLogin = false;
  bool _showSignUp = false;
  bool _loggedIn = false;

  void _onLogin() {
    setState(() {
      _loggedIn = true;
      _showLogin = false;
      _showSignUp = false;
    });
    // Set current user ID for notifications
    final currentUserId = authService.currentUser?.id ?? authService.currentAdmin?.id;
    if (currentUserId != null) {
      messageService.setCurrentUserId(currentUserId);
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
      final isAdmin = authService.currentAdmin != null;
      // Set current user ID for notifications
      final currentUserId = authService.currentUser?.id ?? authService.currentAdmin?.id;
      if (currentUserId != null) {
        messageService.setCurrentUserId(currentUserId);
      }
      homeWidget = MainNavScreen(
        isAdmin: isAdmin,
        onLogout: () {
          setState(() {
            _loggedIn = false;
            _showLogin = true;
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
