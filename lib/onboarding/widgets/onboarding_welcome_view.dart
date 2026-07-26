import 'package:flutter/material.dart';

import '../../services/app_strings.dart';
import '../../services/theme_service.dart';
import '../../widgets/user_avatar.dart';

/// Act 1: the full-screen welcome moment shown over the app on first login.
///
/// Uses the light/dark choice made immediately before onboarding, while the
/// burgundy campus-pulse motif makes the moment feel like an event.
class OnboardingWelcomeView extends StatelessWidget {
  final String userId;
  final String firstName;
  final VoidCallback onStartTour;
  final VoidCallback onSkip;

  const OnboardingWelcomeView({
    super.key,
    required this.userId,
    required this.firstName,
    required this.onStartTour,
    required this.onSkip,
  });

  static const Color _burgundy = Color(0xFF8C1D40);

  @override
  Widget build(BuildContext context) {
    final isDark = themeService.isDark;
    final background = isDark
        ? const Color(0xFF0C0608)
        : const Color(0xFFFBF7F5);
    final titleColor = isDark ? Colors.white : const Color(0xFF1A0610);
    final bodyColor = isDark
        ? const Color(0xB3FFFFFF)
        : const Color(0xFF785D69);
    return Listener(
      key: ValueKey('onboarding-welcome-${isDark ? 'dark' : 'light'}'),
      // Swallow stray pointers without advertising the whole screen as one
      // enormous tappable control to accessibility services.
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: background)),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -1.0),
                  radius: 1.2,
                  colors: isDark
                      ? const [_burgundy, Colors.transparent]
                      : [
                          const Color(0xFFD8597F).withValues(alpha: 0.30),
                          Colors.transparent,
                        ],
                  stops: const [0.0, 0.68],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.035 : 0.42),
                      Colors.transparent,
                      _burgundy.withValues(alpha: isDark ? 0.18 : 0.07),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 88,
            right: 30,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: isDark
                  ? const Color(0x66FFFFFF)
                  : _burgundy.withValues(alpha: 0.32),
              size: 27,
            ),
          ),
          Positioned(
            top: 146,
            left: 34,
            child: Icon(
              Icons.circle,
              color: isDark
                  ? const Color(0x4DFFFFFF)
                  : _burgundy.withValues(alpha: 0.22),
              size: 8,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSeal(context, isDark),
                    const SizedBox(height: 28),
                    Text(
                      S.onboardingWelcomeEyebrow,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2.0,
                        color: isDark
                            ? const Color(0x99FFFFFF)
                            : _burgundy.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      S.onboardingWelcomeTitle(firstName),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        height: 1.05,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      S.onboardingWelcomeBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: bodyColor,
                        height: 1.5,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onStartTour,
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : _burgundy,
                          foregroundColor: isDark ? _burgundy : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: isDark ? 0 : 5,
                          shadowColor: _burgundy.withValues(alpha: 0.34),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                        label: Text(
                          S.onboardingShowMeAround,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xB3FFFFFF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        S.onboardingExploreOnMyOwn,
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeal(BuildContext context, bool isDark) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 98,
          height: 98,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? const Color(0x33FFFFFF)
                  : _burgundy.withValues(alpha: 0.20),
              width: 1.5,
            ),
          ),
        ),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.white : const Color(0xFFFFFBF7),
            boxShadow: [
              BoxShadow(
                color: _burgundy.withValues(alpha: 0.58),
                blurRadius: 42,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: UserAvatar(
              userId: userId,
              name: firstName,
              size: 74,
              fontSize: 26,
              backgroundColor: isDark ? Colors.white : const Color(0xFFFFFBF7),
              textColor: _burgundy,
            ),
          ),
        ),
        const Positioned(
          right: 2,
          bottom: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(color: _burgundy, shape: BoxShape.circle),
            child: Padding(
              padding: EdgeInsets.all(7),
              child: Icon(
                Icons.waving_hand_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
