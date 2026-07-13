import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import 'club_admin_auth_screen.dart';

class AuthChoiceScreen extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  final VoidCallback onAdminLogin;

  const AuthChoiceScreen({
    super.key,
    required this.onLogin,
    required this.onSignUp,
    required this.onAdminLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double heroGap = (constraints.maxHeight * 0.42)
                .clamp(170.0, 320.0)
                .toDouble();
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWordmark(),
                      SizedBox(height: heroGap),
                      _buildHeroCopy(),
                      const SizedBox(height: 28),
                      _buildActions(context),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          'By continuing you agree to our Terms\nand acknowledge the Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.55,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            _fadeSlideRoute(
                              ClubAdminAuthScreen(
                                onAdminLogin: () {
                                  Navigator.of(context).pop();
                                  onAdminLogin();
                                },
                              ),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.secondaryText,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: Text(
                            'Club admin sign in',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWordmark() {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primaryRed,
            borderRadius: BorderRadius.all(Radius.circular(9)),
          ),
          alignment: Alignment.center,
          child: const Text(
            'KU',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EST. 1993',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Koç University',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCopy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your campus,',
          style: TextStyle(
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            color: AppColors.text,
          ),
        ),
        Text(
          'in your pocket.',
          style: TextStyle(
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            color: AppColors.primaryRed,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            'Class schedules, dining, events, and the people who make Koç University home.',
            style: TextStyle(
              fontSize: 15.5,
              height: 1.45,
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: onSignUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
            ),
            child: const Text(
              'Create account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: BorderSide(color: AppColors.divider),
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
            ),
            child: Text(
              'I already have one',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Route _fadeSlideRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slide, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
  );
}
