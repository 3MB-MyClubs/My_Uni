import 'package:flutter/material.dart';

import '../../services/app_strings.dart';
import '../../services/theme_service.dart';

/// Act 3: "That's the tour!" — for students it introduces the starter
/// checklist with deep links into the right tabs; club admins get a short
/// send-off instead.
class OnboardingFinishView extends StatelessWidget {
  final bool showChecklist;
  final VoidCallback onDone;

  /// Called with the bottom-nav tab index a checklist row points at.
  /// The caller is expected to close onboarding first, then jump.
  final ValueChanged<int>? onDeepLink;

  const OnboardingFinishView({
    super.key,
    required this.showChecklist,
    required this.onDone,
    this.onDeepLink,
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
      key: ValueKey('onboarding-finish-${isDark ? 'dark' : 'light'}'),
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
                          const Color(0xFFD8597F).withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                  stops: const [0.0, 0.68],
                ),
              ),
            ),
          ),
          Positioned(
            top: 78,
            left: 32,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: isDark
                  ? const Color(0x66FFFFFF)
                  : _burgundy.withValues(alpha: 0.30),
              size: 23,
            ),
          ),
          Positioned(
            top: 130,
            right: 30,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: isDark
                  ? const Color(0x4DFFFFFF)
                  : _burgundy.withValues(alpha: 0.22),
              size: 17,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? const [Colors.white, Color(0xFFFFE7EF)]
                              : const [Color(0xFFC73460), Color(0xFF6A1530)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _burgundy.withValues(alpha: 0.55),
                            blurRadius: 34,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.celebration_rounded,
                        color: isDark ? _burgundy : Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      S.onboardingFinishTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        height: 1.1,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      showChecklist
                          ? S.onboardingFinishBody
                          : S.onboardingFinishBodyClub,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: bodyColor,
                        height: 1.5,
                      ),
                    ),
                    if (showChecklist) ...[
                      const SizedBox(height: 28),
                      _ChecklistRow(
                        icon: Icons.groups_rounded,
                        label: S.checklistFollowClub,
                        action: S.checklistFollowClubAction,
                        isDark: isDark,
                        onTap: onDeepLink == null ? null : () => onDeepLink!(2),
                      ),
                      const SizedBox(height: 10),
                      _ChecklistRow(
                        icon: Icons.event_available_rounded,
                        label: S.checklistRsvpEvent,
                        action: S.checklistRsvpEventAction,
                        isDark: isDark,
                        onTap: onDeepLink == null ? null : () => onDeepLink!(1),
                      ),
                      const SizedBox(height: 10),
                      _ChecklistRow(
                        icon: Icons.waving_hand_rounded,
                        label: S.checklistSayHi,
                        action: S.checklistSayHiAction,
                        isDark: isDark,
                        onTap: onDeepLink == null ? null : () => onDeepLink!(3),
                      ),
                    ],
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onDone,
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
                        icon: const Icon(Icons.rocket_launch_rounded, size: 19),
                        label: Text(
                          S.onboardingLetsGo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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
}

class _ChecklistRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String action;
  final bool isDark;
  final VoidCallback? onTap;

  const _ChecklistRow({
    required this.icon,
    required this.label,
    required this.action,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8C1D40);
    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: isDark ? 0.18 : 0.12)),
      ),
      elevation: isDark ? 0 : 2,
      shadowColor: accent.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFFFE8EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDark ? Colors.white : accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A0610),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0x99FFFFFF)
                            : const Color(0xFF9A7888),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? const Color(0x99FFFFFF)
                    : accent.withValues(alpha: 0.62),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
