import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'club_follow_service.dart';
import 'mock_data.dart';
import 'user_prefs_service.dart';
import 'user_state.dart';

/// Handles a follow/unfollow tap on a club.
/// - Club admins CAN follow other clubs (but not their own).
/// - Regular users: simple toggle, persisted immediately.
/// - Board membership is granted exclusively by the club admin from the Board tab.
Future<void> handleFollowTap(
  BuildContext context,
  String clubId,
  VoidCallback onChanged,
) async {
  // Determine the acting identity (user or club admin).
  final uid = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
  if (uid.isEmpty) return;

  // A club admin cannot follow their own club.
  if (authService.currentAdmin != null) {
    final myClub = clubs.firstWhere(
      (c) => c.adminUserIds.contains(uid),
      orElse: () => clubs.first,
    );
    if (myClub.id == clubId) return;
  }

  final wasFollowing = userState.isFollowing(clubId);
  final previousMemberCount = supabaseClubMemberCounts[clubId];
  final effectiveMemberCount = previousMemberCount ?? clubMemberCount(clubId);
  userState.toggleFollow(clubId);
  supabaseClubMemberCounts[clubId] =
      (effectiveMemberCount + (wasFollowing ? -1 : 1)).clamp(0, 1 << 31);
  onChanged();

  try {
    final studentUserId = authService.currentUser?.id;
    if (studentUserId != null && studentUserId.isNotEmpty) {
      if (wasFollowing) {
        await clubFollowService.unfollowClub(
          userId: studentUserId,
          clubId: clubId,
        );
      } else {
        await clubFollowService.followClub(
          userId: studentUserId,
          clubId: clubId,
        );
      }
    }
    await userPrefsService.save(uid);
  } catch (_) {
    userState.toggleFollow(clubId);
    if (previousMemberCount != null) {
      supabaseClubMemberCounts[clubId] = previousMemberCount;
    } else {
      supabaseClubMemberCounts.remove(clubId);
    }
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update club follow.')),
      );
    }
  }
}
