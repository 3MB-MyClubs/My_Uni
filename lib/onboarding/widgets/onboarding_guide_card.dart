import 'package:flutter/material.dart';

import '../../services/app_strings.dart';
import '../../services/theme_service.dart';

/// The bottom-docked conversational card that narrates each tour stop.
class OnboardingGuideCard extends StatelessWidget {
  final String text;
  final IconData icon;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const OnboardingGuideCard({
    super.key,
    required this.text,
    required this.icon,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onNext,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeService.isDark;
    const accent = Color(0xFF9E2045);
    final surface = isDark ? const Color(0xFF191416) : const Color(0xFFFFFBF7);
    final surfaceEnd = isDark
        ? const Color(0xFF100B0D)
        : const Color(0xFFFFF5F1);
    final textColor = isDark ? Colors.white : const Color(0xFF1A0610);
    final muted = isDark ? const Color(0xFFAFA3A9) : const Color(0xFF9A7888);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        liveRegion: true,
        label: '$text ${S.onboardingStepLabel(index + 1, total)}',
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {},
          child: Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  key: ValueKey(
                    'onboarding-guide-card-${isDark ? 'dark' : 'light'}',
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [surface, surfaceEnd],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isDark
                          ? accent.withValues(alpha: 0.72)
                          : accent.withValues(alpha: 0.42),
                      width: 1.35,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.48 : 0.20,
                        ),
                        blurRadius: 38,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.26 : 0.18),
                        blurRadius: 34,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 76,
                        child: ClipPath(
                          clipper: const _PulseHeaderClipper(),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF6A1530),
                                  Color(0xFFC02D58),
                                  Color(0xFF8C1D40),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 22,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white.withValues(alpha: 0.92),
                          size: 20,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 52, 18, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 76),
                              child: _StepBadge(
                                label: S.onboardingStepLabel(index + 1, total),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 116),
                              child: SingleChildScrollView(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 17,
                                    height: 1.36,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.28,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _CardFooter(
                              index: index,
                              total: total,
                              isLast: isLast,
                              isDark: isDark,
                              muted: muted,
                              onBack: onBack,
                              onNext: onNext,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  top: -22,
                  child: _GuideAvatar(icon: icon, isDark: isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final String label;
  final bool isDark;

  const _StepBadge({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF9E2045);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF3A121F).withValues(alpha: 0.96)
            : const Color(0xFFFFE8EF),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isDark
              ? accent.withValues(alpha: 0.78)
              : accent.withValues(alpha: 0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}

class _GuideAvatar extends StatelessWidget {
  final IconData icon;
  final bool isDark;

  const _GuideAvatar({required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF9E2045);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF44101F), Color(0xFF160A0E)]
                  : const [Color(0xFFC73460), Color(0xFF6A1530)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFFFC4D5).withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.90),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.48 : 0.38),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 34),
        ),
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF241F21) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 8),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: accent,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardFooter extends StatelessWidget {
  final int index;
  final int total;
  final bool isLast;
  final bool isDark;
  final Color muted;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const _CardFooter({
    required this.index,
    required this.total,
    required this.isLast,
    required this.isDark,
    required this.muted,
    required this.onNext,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320;
        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onBack != null)
              TextButton(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: muted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 11,
                  ),
                ),
                child: Text(
                  S.onboardingBack,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(width: 3),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9E2045),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFFFF719A).withValues(alpha: 0.38)
                          : Colors.transparent,
                    ),
                  ),
                  elevation: isDark ? 0 : 4,
                  shadowColor: const Color(0xFF9E2045).withValues(alpha: 0.48),
                ),
                iconAlignment: IconAlignment.end,
                icon: Icon(
                  isLast
                      ? Icons.celebration_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                ),
                label: Text(
                  isLast ? S.onboardingFinish : S.onboardingNext,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProgressTrail(index: index, total: total, isDark: isDark),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: controls),
            ],
          );
        }
        return Row(
          children: [
            Flexible(
              child: _ProgressTrail(index: index, total: total, isDark: isDark),
            ),
            const SizedBox(width: 10),
            controls,
          ],
        );
      },
    );
  }
}

class _ProgressTrail extends StatelessWidget {
  final int index;
  final int total;
  final bool isDark;

  const _ProgressTrail({
    required this.index,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF9E2045);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(right: 6),
            width: i == index ? 25 : 10,
            height: 7,
            decoration: BoxDecoration(
              color: i == index
                  ? accent
                  : (isDark
                        ? const Color(0xFF5A474D)
                        : const Color(0xFFE9CDD6)),
              borderRadius: BorderRadius.circular(99),
              boxShadow: i == index
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.34),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}

class _PulseHeaderClipper extends CustomClipper<Path> {
  const _PulseHeaderClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.58)
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.82,
        size.width * 0.42,
        size.height * 0.34,
        0,
        size.height * 0.72,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant _PulseHeaderClipper oldClipper) => false;
}
