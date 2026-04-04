import 'package:flutter/material.dart';
import 'mock_data.dart';
import 'user_state.dart';
import 'app_colors.dart';

/// Shows a confirmation dialog if the user is already in a different club,
/// then joins [clubId]. If already following [clubId], leaves it.
/// Calls [onChanged] after state is updated so the caller can setState.
Future<void> handleFollowTap(
  BuildContext context,
  String clubId,
  VoidCallback onChanged,
) async {
  // Unfollow
  if (userState.isFollowing(clubId)) {
    userState.leaveClub(clubId);
    onChanged();
    return;
  }

  final currentId = userState.activeClubId;

  // No existing club — just join
  if (currentId == null) {
    userState.joinClub(clubId);
    onChanged();
    return;
  }

  // Already in a different club — ask to switch
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
        'You are already a member of $currentName. You can only be active in one club at a time.\n\nLeave $currentName and join $newName?',
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Switch'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    userState.joinClub(clubId);
    onChanged();
  }
}
