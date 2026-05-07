import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import 'club_admin_auth_screen.dart';

class AuthChoiceScreen extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  final VoidCallback onAdminLogin;
  const AuthChoiceScreen({super.key, required this.onLogin, required this.onSignUp, required this.onAdminLogin});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── KU branded header ─────────────────────────────────────────
          Container(
            height: size.height * 0.48,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A1530), AppColors.primaryRed, AppColors.darkRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(44),
                bottomRight: Radius.circular(44),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // KU seal
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'KU',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryRed,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'UniHub',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Koç University  ·  Istanbul',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Gold accent line
                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Action area ───────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Connect with your campus',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join clubs, attend events, and stay connected with the Koç University community.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Log In button
                  ElevatedButton(
                    onPressed: onLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                      shadowColor: AppColors.primaryRed.withValues(alpha: 0.4),
                    ),
                    child: Text('Log In',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),

                  // Sign Up button
                  OutlinedButton(
                    onPressed: onSignUp,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      side: BorderSide(
                          color: AppColors.primaryRed, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Create Account',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),

                  const Spacer(),

                  // Admin link
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        _fadeSlideRoute(ClubAdminAuthScreen(
                          onAdminLogin: () {
                            Navigator.of(context).pop();
                            onAdminLogin();
                          },
                        )),
                      ),
                      child: Text(
                        'Club Admin? Sign in here',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Route _fadeSlideRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slide = Tween<Offset>(
                  begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      );
}
