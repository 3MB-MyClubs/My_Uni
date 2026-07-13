import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/user_state.dart';

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
        ? 'Requested'
        : isFollowing
        ? 'Following'
        : (followLabel ?? 'Follow');

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

    return GestureDetector(
      onTap: onTap,
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}
