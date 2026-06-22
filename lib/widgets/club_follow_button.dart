import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/club_admin_access.dart';
import '../services/user_state.dart';
import '../services/club_follow_helper.dart';

/// A self-contained follow/unfollow button for a club.
///
/// Wraps itself in a [ListenableBuilder] on [userState] so it always reflects
/// the correct followed state — even when another screen changed the state.
///
/// Admins can follow other clubs (but not their own).
///
/// [fullWidth] — stretch button to fill available width (Explore grid style).
/// [size]      — 'large' (club profile), 'medium' (default), 'small' (feed pill).
class ClubFollowButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Club admins cannot follow their own club — hide button for own club.
    final adminId = authService.currentAdmin?.id ?? '';
    if (adminId.isNotEmpty) {
      final myClub = managedClubForAdmin(adminId);
      if (myClub?.id == clubId) return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: userState,
      builder: (context, _) {
        final isFollowing = userState.isFollowing(clubId);

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
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isFollowing
                  ? AppColors.secondaryText.withValues(alpha: 0.4)
                  : AppColors.primaryRed,
            ),
          ),
          child: Center(
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: isFollowing ? AppColors.secondaryText : Colors.white,
              ),
            ),
          ),
        );

        if (fullWidth) {
          button = SizedBox(width: double.infinity, child: button);
        }

        return GestureDetector(
          onTap: () => handleFollowTap(context, clubId, () {}),
          child: button,
        );
      },
    );
  }
}
