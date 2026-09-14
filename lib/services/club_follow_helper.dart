import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_colors.dart';
import 'auth_service.dart';
import 'club_admin_access.dart';
import 'club_follow_service.dart';
import 'locale_service.dart';
import 'mock_clubup_profile.dart';
import 'mock_data.dart';
import 'people_service.dart';
import 'rate_limit_error.dart';
import 'user_prefs_service.dart';
import 'user_state.dart';

// No BuildContext is available deep in the follow-tap error path when the
// SnackBar text is resolved, so this fallback is looked up via the current
// locale rather than pushed through the call chain.
AppLocalizations get _l10n =>
    lookupAppLocalizations(Locale(localeService.languageCode));

/// ClubUp moderates club activity but never participates as a follower.
/// Ordinary students and dedicated club accounts keep their existing access.
bool get canCurrentSessionFollowClubs =>
    !isClubUpAdmin(authService.currentAdmin);

/// Handles a follow/unfollow tap on a club.
/// - Club admins CAN follow other clubs (but not their own).
/// - Regular followers: simple toggle, persisted immediately.
/// - A student who sits on this club's board must confirm before unfollowing.
/// - Board membership is granted exclusively by the club admin from the Board tab.
Future<void> handleFollowTap(
  BuildContext context,
  String clubId,
  VoidCallback onChanged,
) async {
  if (!canCurrentSessionFollowClubs) return;

  // Determine the acting identity (user or club admin).
  final uid = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
  if (uid.isEmpty) return;

  // A club admin cannot follow their own club.
  if (authService.currentAdmin != null) {
    final myClub = managedClubForAdmin(uid);
    if (myClub?.id == clubId) return;
  }

  final wasFollowing = userState.isFollowing(clubId);
  final studentUserId = authService.currentUser?.id;
  final isBoardMemberOfClub =
      authService.isStudentSession &&
      studentUserId != null &&
      studentUserId.isNotEmpty &&
      (clubForId(clubId)?.boardMemberIds.contains(studentUserId) ?? false);
  if (wasFollowing && isBoardMemberOfClub) {
    final club = clubForId(clubId)!;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('board-member-unfollow-confirm'),
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Text(
          l10n.boardMemberUnfollowTitle(club.name),
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.boardMemberUnfollowBody,
          style: TextStyle(color: AppColors.secondaryText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.unfollowClubAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }

  final previousMemberCount = supabaseClubMemberCounts[clubId];
  final effectiveMemberCount = previousMemberCount ?? clubMemberCount(clubId);
  userState.toggleFollow(clubId);
  supabaseClubMemberCounts[clubId] =
      (effectiveMemberCount + (wasFollowing ? -1 : 1)).clamp(0, 1 << 31);
  // The header count and follow state update optimistically. Drop any older
  // member snapshot at the same time so opening the sheet cannot serve it.
  peopleService.invalidateClubMembers(clubId);
  onChanged();

  try {
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
    // A request that was already in flight when the user tapped may have
    // completed with the pre-change rows. Invalidate once more after commit.
    peopleService.invalidateClubMembers(clubId);
  } catch (error) {
    userState.toggleFollow(clubId);
    if (previousMemberCount != null) {
      supabaseClubMemberCounts[clubId] = previousMemberCount;
    } else {
      supabaseClubMemberCounts.remove(clubId);
    }
    peopleService.invalidateClubMembers(clubId);
    onChanged();
    if (context.mounted) {
      final limited = RateLimitInfo.from(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            limited?.displayMessage ?? _l10n.couldNotUpdateClubFollow,
          ),
        ),
      );
    }
  }
}
