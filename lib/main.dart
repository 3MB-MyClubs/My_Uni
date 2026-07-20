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
import 'services/app_bootstrap.dart';
import 'services/auth_service.dart';
import 'services/mock_data.dart';
import 'services/app_colors.dart';
import 'services/hive_bootstrap.dart';
import 'services/notification_service.dart';
import 'services/user_prefs_service.dart';
import 'services/chat_store.dart';
import 'services/checkin_store.dart';
import 'services/content_store.dart';
import 'services/user_state.dart';
import 'services/view_tracker.dart';
import 'services/personalization_service.dart';
import 'services/people_service.dart';
import 'services/poll_store.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'services/calendar_sync_service.dart';
import 'services/supabase_config.dart';
import 'onboarding/onboarding_service.dart';
import 'onboarding/starter_checklist_service.dart';
import 'services/event_cleanup_service.dart';
import 'services/app_presence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    if (SupabaseConfig.isConfigured)
      Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.clientKey,
      ),
    hiveBootstrap.initialize(),
  ]);

  // The first screen is always Login, which needs only the theme + locale
  // boxes to build the MaterialApp. The other boxes don't depend on each
  // other and nothing before login reads them, so they open in the
  // background; readers await appBootstrap.ready (the post-frame hydration
  // below and the login/club-admin submit handlers — a login's network
  // round-trip dwarfs that wait).
  await Future.wait([themeService.initialize(), localeService.initialize()]);
  appBootstrap.ready = Future.wait([
    userPrefsService.initialize(),
    contentStore.initialize(),
    chatStore.initialize(),
    checkinStore.initialize(),
    pollStore.initialize(),
    viewTracker.initialize(),
    personalizationService.initialize(),
    calendarSyncService.initialize(),
    onboardingService.initialize(),
    starterChecklistService.initialize(),
  ]).then((_) => userPrefsService.loadAllPhotos());

  runApp(const ProviderScope(child: MyApp()));

  // The app always opens on the login screen (there's no session restore on
  // launch), so none of this needs to finish before first paint: the
  // notification permission prompt, materializing mock_data.dart's seed
  // lists, and the network cleanup call are all deferred to right after.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      appBootstrap.ready.then((_) {
        unawaited(notificationService.initialize());

        // Give every demo student a stable mock profile photo so avatars show
        // up in members/board lists etc. Curated seeds and real uploads are
        // not overridden.
        for (final u in users) {
          userState.mockPhotoUrls.putIfAbsent(
            u.id,
            () => 'https://i.pravatar.cc/150?u=${u.id}',
          );
        }
        contentStore.applyToLists();
        unawaited(eventCleanupService.cleanupExpiredEvents());
        contentStore.loadBoardMemberIds();
        contentStore.loadBoardMemberTitles();
        // Restore any dynamic notifications that were generated at runtime.
        final dynNotifs = contentStore.loadDynamicNotifications();
        final removedAdminDmNotificationIds = <String>{};
        if (dynNotifs != null) {
          final compatibleNotifications = dynNotifs.where((notification) {
            final remove =
                notification.targetType == 'message' &&
                ChatStore.isAdminAccountId(notification.userId);
            if (remove) removedAdminDmNotificationIds.add(notification.id);
            return !remove;
          }).toList();
          userState.dynamicNotifications
            ..clear()
            ..addAll(compatibleNotifications);
          if (removedAdminDmNotificationIds.isNotEmpty) {
            unawaited(
              contentStore.saveDynamicNotifications(compatibleNotifications),
            );
          }
        }
        final compatibleReadNotificationIds = contentStore
            .loadReadNotificationIds()
            .where((id) => !removedAdminDmNotificationIds.contains(id));
        userState.replaceReadNotificationIds(compatibleReadNotificationIds);
        if (removedAdminDmNotificationIds.isNotEmpty) {
          unawaited(
            contentStore.saveReadNotificationIds(userState.readNotificationIds),
          );
        }
      }),
    );
  });
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

  // Prefs/personalization are loaded once per logged-in user (from _onLogin or
  // the first build that sees the session) — not on every theme/locale
  // rebuild: personalizationService.load ends with notifyListeners(), which
  // must not fire during build.
  String? _prefsLoadedForUserId;

  // _buildTheme reads only const palettes (DarkColors/LightColors), so both
  // ThemeData graphs are immutable for the process lifetime.
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(appPresenceService.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appPresenceService.handleLifecycleState(state);
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
    // saveAll rewrites every debounced kind, flushing any pending
    // scheduleSave along the way (pause/detach and logout both land here).
    contentStore.saveAll(userState.dynamicNotifications);
    chatStore.saveAll();
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
      unawaited(appPresenceService.startForAuthenticatedSession());
      _prefsLoadedForUserId = currentUserId;
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
    final red = isDark ? DarkColors.primaryRed : LightColors.primaryRed;
    final elevatedSurface = isDark
        ? DarkColors.surfaceAlt
        : LightColors.surfaceAlt;

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
            return IconThemeData(color: red);
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
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: red, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: elevatedSurface),
      popupMenuTheme: PopupMenuThemeData(color: elevatedSurface),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevatedSurface,
        modalBackgroundColor: elevatedSurface,
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
          if (currentUserId != null && currentUserId != _prefsLoadedForUserId) {
            _prefsLoadedForUserId = currentUserId;
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
                _prefsLoadedForUserId = null;
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
          title: 'ClubUp',
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: _lightTheme ??= _buildTheme(false),
          darkTheme: _darkTheme ??= _buildTheme(true),
          home: homeWidget,
        );
      },
    );
  }
}
