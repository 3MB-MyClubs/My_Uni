import 'package:flutter/material.dart';

import '../../services/app_strings.dart';
import '../../services/theme_service.dart';
import '../../widgets/tutorial_design.dart';

/// `coach-card` — the 306-wide card that explains one spotlit element.
///
/// Read order is eyebrow, title, body, then controls, and every block is
/// separated by the same 10pt gap that the frames use. The card hugs its
/// height and is never given a fixed one: Turkish runs roughly 20% longer
/// than English.
///
/// Shared by the tour and by the standalone page tips, which are the same card
/// with no progress dots and no Back.
class OnboardingGuideCard extends StatelessWidget {
  /// "HOME FEED · STEP 1 OF 2", or just the page name on a single-step page.
  final String eyebrow;

  /// Null on the club-admin tour, which the board puts out of scope and which
  /// therefore has only a guide line to draw on.
  final String? title;

  final String body;

  /// Null hides the dots — "Hidden on single-step pages."
  final int? progressIndex;
  final int progressTotal;

  /// Drives the primary pill's label: Next mid-page, Got it on the last step
  /// of a page.
  final bool isPageEnd;

  final VoidCallback onNext;
  final VoidCallback onSkip;

  /// Null hides Back, which "appears from step two" of the page.
  final VoidCallback? onBack;

  const OnboardingGuideCard({
    super.key,
    required this.eyebrow,
    required this.body,
    required this.isPageEnd,
    required this.onNext,
    required this.onSkip,
    this.title,
    this.progressIndex,
    this.progressTotal = 0,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeService.isDark;
    final progress = progressIndex;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        liveRegion: true,
        child: Listener(
          // Swallow strays so a tap on the card never reaches the scrim.
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {},
          child: TutorialCardShell(
            key: ValueKey('onboarding-guide-card-${isDark ? 'dark' : 'light'}'),
            width: TutorialMetrics.cardWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: tutorialEyebrowStyle()),
                if (title != null) ...[
                  const SizedBox(height: TutorialMetrics.blockGap),
                  Text(title!, style: tutorialTitleStyle()),
                ],
                const SizedBox(height: TutorialMetrics.blockGap),
                Text(body, style: tutorialBodyStyle()),
                if (progress != null && progressTotal > 1) ...[
                  const SizedBox(height: TutorialMetrics.blockGap),
                  TutorialProgressDots(
                    index: progress,
                    total: progressTotal,
                  ),
                ],
                const SizedBox(height: TutorialMetrics.blockGap),
                _CardFooter(
                  isPageEnd: isPageEnd,
                  onNext: onNext,
                  onSkip: onSkip,
                  onBack: onBack,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `footer` — Skip tour on the left stays reachable on every step, Back
/// appears from the second step of the page, and the primary pill reads Next
/// mid-page and Got it on the page's last step.
class _CardFooter extends StatelessWidget {
  final bool isPageEnd;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;

  const _CardFooter({
    required this.isPageEnd,
    required this.onNext,
    required this.onSkip,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TutorialMetrics.footerHeight,
      child: Row(
        children: [
          // The pills are laid out at their natural width and Skip absorbs
          // what is left. Making the pills flex children instead would have
          // them share the free space with the gap, which truncates the longer
          // Turkish labels ("Anladım" → "Anla…").
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              // Skip is first in the tree so it is the first focusable control.
              child: TutorialSkipButton(
                buttonKey: const ValueKey('onboarding-skip-button'),
                label: S.onboardingSkipTour,
                onPressed: onSkip,
              ),
            ),
          ),
          if (onBack != null) ...[
            TutorialPillButton(
              label: S.onboardingBack,
              onPressed: onBack!,
              primary: false,
            ),
            const SizedBox(width: 8),
          ],
          TutorialPillButton(
            label: isPageEnd ? S.tutorialGotIt : S.onboardingNext,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
