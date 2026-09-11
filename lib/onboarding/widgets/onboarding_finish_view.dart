import 'package:flutter/material.dart';

import '../../services/app_strings.dart';
import '../../services/theme_service.dart';
import '../../widgets/tutorial_design.dart';

/// `tut-finish-light` 390:1494 / `tut-finish-dark` 390:1676 — step 32.
///
/// The other full-screen step. Unlike the welcome card this one is washed in
/// the accent and hairlined in it, and its footnote — the replay instructions —
/// is accent ink rather than neutral.
///
/// The frame has exactly two controls: replay the tour, or go use the app.
/// The starter-checklist rows an earlier finish screen carried are gone from
/// the design, and so is the checklist they led to.
class OnboardingFinishView extends StatelessWidget {
  /// Restarts the tour from step 01.
  final VoidCallback onReplay;

  /// Closes onboarding and hands the student back to the app.
  final VoidCallback onDone;

  const OnboardingFinishView({
    super.key,
    required this.onReplay,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeService.isDark;
    return Listener(
      key: ValueKey('onboarding-finish-${isDark ? 'dark' : 'light'}'),
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
              accented: true,
              eyebrow: S.tutorialFinishEyebrow,
              title: S.tutorialFinishTitle,
              body: S.tutorialFinishBody,
              footnote: S.tutorialFinishFootnote,
              secondaryLabel: S.tutorialReplayTour,
              onSecondary: onReplay,
              primaryLabel: S.tutorialExploreClubUp,
              onPrimary: onDone,
            ),
          ),
        ),
      ),
    );
  }
}
