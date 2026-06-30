import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/signup_flow_screen.dart';
// import 'screens/feed_screen.dart';
// import 'screens/admin_dashboard.dart';
import 'screens/main_nav_screen.dart';
import 'screens/theme_choice_screen.dart';
import 'screens/language_choice_screen.dart';
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
import 'services/people_service.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'services/calendar_sync_service.dart';
import 'services/supabase_config.dart';
import 'services/tutorial_service.dart';
import 'services/event_cleanup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //örnek yorum
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.clientKey,
    );
  }
  await messageService.initialize();
  await notificationService.initialize();
  await userPrefsService.initialize();
  userPrefsService.loadAllPhotos();
  // Give every demo student a stable mock profile photo so avatars show up in
  // members/board lists etc. Curated seeds and real uploads are not overridden.
  for (final u in users) {
    userState.mockPhotoUrls.putIfAbsent(
      u.id,
      () => 'https://i.pravatar.cc/150?u=${u.id}',
    );
  }
  await contentStore.initialize();
  await viewTracker.initialize();
  await personalizationService.initialize();
  await themeService.initialize();
  await localeService.initialize();
  await calendarSyncService.initialize();
  await tutorialService.initialize();
  contentStore.applyToLists();
  await eventCleanupService.cleanupExpiredEvents();
  contentStore.loadBoardMemberIds();
  contentStore.loadBoardMemberTitles();
  // Restore any dynamic notifications that were generated at runtime.
  final dynNotifs = contentStore.loadDynamicNotifications();
  if (dynNotifs != null) {
    userState.dynamicNotifications
      ..clear()
      ..addAll(dynNotifs);
  }
  userState.replaceReadNotificationIds(contentStore.loadReadNotificationIds());
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _showSignUp = false;
  bool _loggedIn = false;
  String _signupEmail = '';

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
    }
    contentStore.saveAll(userState.dynamicNotifications);
  }

  void _onLogin() {
    final currentUserId =
        authService.currentUser?.id ?? authService.currentAdmin?.id;
    // First-time accounts are always presented in light and asked to pick a
    // theme (handled in build); force light before the picker appears.
    if (currentUserId != null && !themeService.hasChosenTheme(currentUserId)) {
      themeService.setDark(false);
    }
    setState(() {
      _loggedIn = true;
      _showSignUp = false;
    });
    if (currentUserId != null) {
      messageService.setCurrentUserId(currentUserId);
      userPrefsService.load(currentUserId);
      personalizationService.load(currentUserId);
      unawaited(peopleService.hydrateFollowing(currentUserId));
    }
  }

  void _onSignUp(String email) {
    // Sign-up complete → return to the root Login Screen with the email
    // pre-filled so the student can log straight in.
    setState(() {
      _signupEmail = email;
      _showSignUp = false;
    });
  }

  // Custom back navigation from the sign-up flow → root Login Screen.
  void handleBack() {
    setState(() => _showSignUp = false);
  }

  ThemeData _buildTheme(bool isDark) {
    // Use raw DarkColors/LightColors (const) — AppColors getters read from
    // themeService.isDark which may differ from the isDark param here.
    final bg = isDark ? DarkColors.background : LightColors.background;
    final crd = isDark ? DarkColors.card : LightColors.card;
    final txt = isDark ? DarkColors.text : LightColors.text;
    final sub = isDark ? DarkColors.secondaryText : LightColors.secondaryText;
    final div = isDark ? DarkColors.divider : LightColors.divider;
    final ltRed = isDark ? DarkColors.lightRed : LightColors.lightRed;
    final lGray = isDark ? DarkColors.lightGray : LightColors.lightGray;
    final bright = isDark ? Brightness.dark : Brightness.light;
    const red = AppColors.primaryRed;

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
            return TextStyle(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(color: sub);
        }),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: txt),
        bodyMedium: TextStyle(color: txt),
        bodySmall: TextStyle(color: sub),
        titleLarge: TextStyle(color: txt, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: txt),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: red,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
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
      listenable: Listenable.merge([themeService, localeService]),
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
          }
          if (currentUserId != null &&
              !themeService.hasChosenTheme(currentUserId)) {
            homeWidget = ThemeChoiceScreen(
              onChoose: (dark) =>
                  themeService.markThemeChosen(currentUserId, dark),
            );
          } else if (currentUserId != null &&
              !localeService.hasChosenLanguage(currentUserId)) {
            homeWidget = LanguageChoiceScreen(
              onChoose: (code) =>
                  localeService.markLanguageChosen(currentUserId, code),
            );
          } else {
            homeWidget = MainNavScreen(
              isAdmin: isAdmin,
              onLogout: () {
                _savePrefs();
                setState(() {
                  _loggedIn = false;
                  _showSignUp = false;
                });
              },
            );
          }
        } else if (_showSignUp) {
          homeWidget = AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: SignupFlowScreen(onSignUp: _onSignUp, onBack: handleBack),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        } else {
          // Root entry: the Login Screen. "Sign up" hands off to the
          // multi-step sign-up flow; club-admin sign-in is reached from its
          // footer link.
          homeWidget = AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: LoginScreen(
              onLogin: _onLogin,
              onSignUp: () => setState(() => _showSignUp = true),
              onAdminLogin: _onLogin,
              initialEmail: _signupEmail,
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
