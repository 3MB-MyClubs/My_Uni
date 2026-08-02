import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/club_admin_access.dart';
import '../services/user_state.dart';
import '../services/club_follow_helper.dart';
import 'app_pressable.dart';

/// A self-contained follow/unfollow button for a club.
///
/// Watches only this club's followed state via Riverpod's `.select()` so it
/// always reflects the correct state — even when another screen changed it —
/// without rebuilding on unrelated UserState changes.
///
/// Admins can follow other clubs (but not their own).
///
/// [fullWidth] — stretch button to fill available width (Explore grid style).
/// [size]      — 'large' (club profile), 'medium' (default), 'small' (feed pill).
class ClubFollowButton extends ConsumerWidget {
  final String clubId;
  final bool fullWidth;
  final String size; // 'large' | 'medium' | 'small'

  const ClubFollowButton({
    super.key,
    required this.clubId,
    this.fullWidth = false,
    this.size = 'medium',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Club admins cannot follow their own club — hide button for own club.
    final adminId = authService.currentAdmin?.id ?? '';
    if (adminId.isNotEmpty) {
      final myClub = managedClubForAdmin(adminId);
      if (myClub?.id == clubId) return const SizedBox.shrink();
    }

    final isFollowing = ref.watch(
      userStateProvider.select((s) => s.isFollowing(clubId)),
    );

    final EdgeInsets padding = switch (size) {
      'large' => const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      'small' => const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      _ => const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    };
    final double fontSize = switch (size) {
      'large' => 14.0,
      'small' => 12.0,
      _ => 13.0,
    };
    final double borderRadius = switch (size) {
      'large' => 10.0,
      'small' => 20.0,
      _ => 8.0,
    };

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding,
      decoration: BoxDecoration(
        color: isFollowing ? Colors.transparent : AppColors.primaryRed,
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        border: Border.all(
          color: isFollowing
              ? AppColors.secondaryText.withValues(alpha: 0.4)
              : AppColors.primaryRed,
        ),
      ),
      child: Center(
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
            isFollowing
                ? AppLocalizations.of(context)!.following
                : AppLocalizations.of(context)!.follow,
            key: ValueKey(isFollowing),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: isFollowing ? AppColors.secondaryText : Colors.white,
            ),
          ),
        ),
      ),
    );

    if (fullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return AppPressable(
      onTap: () => handleFollowTap(context, clubId, () {}),
      pressedScale: 0.96,
      child: button,
    );
  }
}
