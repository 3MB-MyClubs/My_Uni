import 'package:flutter/material.dart';

import '../../services/app_strings.dart';
import '../../services/theme_service.dart';
import '../../widgets/tutorial_design.dart';

/// `tut-welcome-light` 386:3 / `tut-welcome-dark` 386:185 — step 01.
///
/// A full-screen step: no cut-out, the whole screen dimmed, and a 330pt card
/// centred on it. The app underneath stays readable through the scrim, which
/// is the point — the tour opens by showing the student the feed it is about
/// to explain rather than covering it with a splash.
class OnboardingWelcomeView extends StatelessWidget {
  final VoidCallback onStartTour;
  final VoidCallback onSkip;

  const OnboardingWelcomeView({
    super.key,
    required this.onStartTour,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeService.isDark;
    return Listener(
      key: ValueKey('onboarding-welcome-${isDark ? 'dark' : 'light'}'),
      // Swallow stray pointers without advertising the whole screen as one
      // enormous tappable control to accessibility services.
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      child: ColoredBox(
        color: TutorialColors.scrim,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: TutorialMetrics.screenEdge,
              vertical: 24,
            ),
            child: TutorialMomentCard(
              eyebrow: S.tutorialWelcomeEyebrow,
              title: S.tutorialWelcomeTitle,
              body: S.tutorialWelcomeBody,
              footnote: S.tutorialWelcomeFootnote,
              secondaryLabel: S.tutorialSkipForNow,
              onSecondary: onSkip,
              primaryLabel: S.tutorialStartTour,
              onPrimary: onStartTour,
            ),
          ),
        ),
      ),
    );
  }
}
