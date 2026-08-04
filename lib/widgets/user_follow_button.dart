import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/user_state.dart';
import 'app_pressable.dart';

/// A self-contained follow/unfollow button for a user.
///
/// Watches only this user's followed/pending state via Riverpod's `.select()`
/// so it always reflects the correct state — even when another screen
/// mutated it — without rebuilding on unrelated UserState changes.
///
/// [onTap] is called when the button is pressed. All actual follow logic
/// (privacy check, request sending, etc.) stays in the calling screen.
///
/// [size] — 'large' (profile page), 'medium' (default), 'small' (suggestion card).
class UserFollowButton extends ConsumerWidget {
  final String userId;
  final VoidCallback onTap;
  final String size; // 'large' | 'medium' | 'small'
  final String? followLabel; // overrides the "not following" label

  const UserFollowButton({
    super.key,
    required this.userId,
    required this.onTap,
    this.size = 'medium',
    this.followLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authService.isStudentSession) {
      return const SizedBox.shrink();
    }

    final (isFollowing, isPending) = ref.watch(
      userStateProvider.select(
        (s) => (s.isFollowingUser(userId), s.hasPendingRequest(userId)),
      ),
    );

    final String label = isPending
        ? AppLocalizations.of(context)!.requested
        : isFollowing
        ? AppLocalizations.of(context)!.following
        : (followLabel ?? AppLocalizations.of(context)!.follow);

    final bool filled = !isFollowing && !isPending;

    final EdgeInsets padding = switch (size) {
      'large' => const EdgeInsets.symmetric(vertical: 10),
      'small' => const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      _ => const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    };
    final double fontSize = switch (size) {
      'large' => 14.0,
      'small' => 11.0,
      _ => 12.0,
    };
    final double borderRadius = switch (size) {
      'large' => 10.0,
      'small' => 8.0,
      _ => 8.0,
    };

    return AppPressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      pressedScale: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.primaryRed : Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          border: Border.all(
            color: filled
                ? AppColors.primaryRed
                : AppColors.secondaryText.withValues(alpha: 0.4),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            label,
            key: ValueKey(label),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}
