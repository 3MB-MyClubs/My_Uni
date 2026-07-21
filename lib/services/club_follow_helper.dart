import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'auth_service.dart';
import 'club_admin_access.dart';
import 'club_follow_service.dart';
import 'locale_service.dart';
import 'mock_data.dart';
import 'people_service.dart';
import 'user_prefs_service.dart';
import 'user_state.dart';

// No BuildContext is available deep in the follow-tap error path when the
// SnackBar text is resolved, so this fallback is looked up via the current
// locale rather than pushed through the call chain.
AppLocalizations get _l10n =>
    lookupAppLocalizations(Locale(localeService.languageCode));

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
    final myClub = managedClubForAdmin(uid);
    if (myClub?.id == clubId) return;
  }

  final wasFollowing = userState.isFollowing(clubId);
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
    // A request that was already in flight when the user tapped may have
    // completed with the pre-change rows. Invalidate once more after commit.
    peopleService.invalidateClubMembers(clubId);
  } catch (_) {
    userState.toggleFollow(clubId);
    if (previousMemberCount != null) {
      supabaseClubMemberCounts[clubId] = previousMemberCount;
    } else {
      supabaseClubMemberCounts.remove(clubId);
    }
    peopleService.invalidateClubMembers(clubId);
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.couldNotUpdateClubFollow)),
      );
    }
  }
}
