import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'mock_data.dart';
import 'user_state.dart';
import 'app_colors.dart';

/// Returns true when the currently logged-in person is a board member.
/// This covers:
///   • Club-level AppAdmins (e.g. HAKANS_CLUB admin)
///   • Regular users who have been promoted to board member by a club admin.
bool get _isBoardMember {
  // Club-level admin (not super-admin)?
  final admin = authService.currentAdmin;
  if (admin != null && admin.id != appAdmin.id) return true;

  // Regular user promoted to board member of any club?
  final userId = authService.currentUser?.id;
  if (userId == null) return false;
  return clubs.any((c) => c.boardMemberIds.contains(userId));
}

/// Handles a follow/unfollow tap on a club.
///
/// - Regular students can join any number of clubs freely.
/// - Board members (club admins) are limited to exactly one active club;
///   switching requires a confirmation dialog.
Future<void> handleFollowTap(
  BuildContext context,
  String clubId,
  VoidCallback onChanged,
) async {
  // Unfollow always works without restriction.
  if (userState.isFollowing(clubId)) {
    userState.leaveClub(clubId);
    onChanged();
    return;
  }

  // Regular students — join freely, no limit.
  if (!_isBoardMember) {
    userState.joinClub(clubId);
    onChanged();
    return;
  }

  // Board member — check if already in a different club.
  final currentId = userState.activeClubId;

  if (currentId == null) {
    // Not yet in any club — join directly.
    userState.joinClub(clubId, exclusive: true);
    onChanged();
    return;
  }

  // Already in a different club — ask to switch.
  final currentName =
      clubs.firstWhere((c) => c.id == currentId, orElse: () => clubs.first).name;
  final newName =
      clubs.firstWhere((c) => c.id == clubId, orElse: () => clubs.first).name;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Switch Club?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
      content: Text(
        'As a board member you can only be active in one club at a time.\n\nLeave $currentName and join $newName?',
        style: const TextStyle(color: AppColors.secondaryText, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.secondaryText)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Switch'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    userState.joinClub(clubId, exclusive: true);
    onChanged();
  }
}
