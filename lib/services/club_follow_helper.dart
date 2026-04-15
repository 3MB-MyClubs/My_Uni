import 'package:flutter/material.dart';
import 'auth_service.dart';
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

  userState.toggleFollow(clubId);
  userPrefsService.save(uid);
  onChanged();
}
