import 'package:flutter/material.dart';
import '../models/notification.dart';
import 'app_colors.dart';
import 'auth_service.dart';
import 'mock_data.dart';
import 'user_state.dart';
import 'user_prefs_service.dart';

/// Returns true when the currently logged-in person is a board member.
bool get _isBoardMember {
  final admin = authService.currentAdmin;
  if (admin != null && admin.id != appAdmin.id) return true;
  final userId = authService.currentUser?.id;
  if (userId == null) return false;
  return clubs.any((c) => c.boardMemberIds.contains(userId));
}

/// Entry point: handles a follow/unfollow tap on a club.
///
/// - Unfollow always works immediately.
/// - Follow shows a choice: "Individual Follower" or "Board Member".
Future<void> handleFollowTap(
  BuildContext context,
  String clubId,
  VoidCallback onChanged,
) async {
  // ── Unfollow ────────────────────────────────────────────────────────────────
  if (userState.isFollowing(clubId)) {
    userState.leaveClub(clubId);
    onChanged();
    return;
  }

  // ── Show role-choice dialog ──────────────────────────────────────────────────
  if (!context.mounted) return;
  final choice = await showModalBottomSheet<_FollowChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FollowChoiceSheet(clubId: clubId),
  );
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case _FollowChoice.individual:
      await _joinAsIndividual(context, clubId, onChanged);
    case _FollowChoice.boardMember:
      await _requestBoardMembership(context, clubId, onChanged);
  }
}

// ── Individual follower ──────────────────────────────────────────────────────

Future<void> _joinAsIndividual(
  BuildContext context,
  String clubId,
  VoidCallback onChanged,
) async {
  // Board members are limited to one club — ask to switch.
  if (_isBoardMember) {
    final currentId = userState.activeClubId;
    if (currentId != null && currentId != clubId) {
      final currentName =
          clubs.firstWhere((c) => c.id == currentId, orElse: () => clubs.first).name;
      final newName =
          clubs.firstWhere((c) => c.id == clubId, orElse: () => clubs.first).name;

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Switch Club?',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
          content: Text(
            'As a board member you can only be active in one club.\n\nLeave $currentName and join $newName?',
            style: const TextStyle(color: AppColors.secondaryText, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
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
      if (confirmed != true) return;
      userState.joinClub(clubId, exclusive: true);
      onChanged();
      return;
    }
    userState.joinClub(clubId, exclusive: true);
    onChanged();
    return;
  }

  // Regular student — join freely.
  userState.joinClub(clubId);
  onChanged();
}

// ── Board member request ─────────────────────────────────────────────────────

Future<void> _requestBoardMembership(
  BuildContext context,
  String clubId,
  VoidCallback onChanged,
) async {
  final userId = authService.currentUser?.id ?? '';
  if (userId.isEmpty) return;

  // Already pending?
  if (userState.hasPendingBoardRequest(userId, clubId)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your board member request is already pending.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  // Cooldown active?
  if (userState.isBoardCooldownActive(userId, clubId)) {
    final endsAt = userState.boardCooldownEnds(userId, clubId)!;
    final dateStr = '${endsAt.day}/${endsAt.month}/${endsAt.year}';
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can reapply for board membership on $dateStr.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  final userName = authService.currentUser?.name ?? 'Someone';
  final club = clubs.firstWhere((c) => c.id == clubId, orElse: () => clubs.first);

  // Find the club admin(s) — send a notification to the first admin found.
  final adminId = club.adminUserIds.isNotEmpty ? club.adminUserIds.first : null;
  if (adminId == null) {
    // No admin registered — fall back to immediate follow as individual.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${club.name} has no admin yet. Joined as individual follower.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    userState.joinClub(clubId);
    onChanged();
    return;
  }

  // Record the pending request.
  userState.sendBoardRequest(userId, clubId);

  // Create a notification for the club admin.
  final notifId = 'board_req_${userId}_${clubId}_${DateTime.now().millisecondsSinceEpoch}';
  final notif = AppNotification(
    id: notifId,
    userId: adminId,           // shown in the admin's alerts
    message: '$userName wants to join ${club.name} as a board member.',
    createdAt: DateTime.now(),
    targetType: 'board_member_request',
    targetId: clubId,          // which club
    fromId: userId,            // who requested
  );
  userState.addFollowRequestNotification(notif);

  final myId = authService.currentUser?.id ?? '';
  if (myId.isNotEmpty) userPrefsService.save(myId);

  onChanged(); // update button to "Pending"

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Board member request sent to ${club.name}.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }
}

// ── Choice enum + bottom sheet ────────────────────────────────────────────────

enum _FollowChoice { individual, boardMember }

class _FollowChoiceSheet extends StatelessWidget {
  final String clubId;
  const _FollowChoiceSheet({required this.clubId});

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == clubId, orElse: () => clubs.first);
    final userId = authService.currentUser?.id ?? '';
    final cooldownActive = userId.isNotEmpty && userState.isBoardCooldownActive(userId, clubId);
    final cooldownEnds = cooldownActive ? userState.boardCooldownEnds(userId, clubId) : null;
    final cooldownStr = cooldownEnds != null
        ? '${cooldownEnds.day}/${cooldownEnds.month}/${cooldownEnds.year}'
        : '';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'How would you like to follow\n${club.name}?',
            style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.text, height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose your role — you can always leave later.',
            style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 20),

          // Individual follower card — always enabled
          _ChoiceCard(
            icon: Icons.person_outline_rounded,
            iconColor: AppColors.primaryRed,
            bgColor: AppColors.lightRed,
            title: 'Individual Follower',
            subtitle: "Follow the club's posts, events and stories. "
                'Access is granted immediately.',
            onTap: () => Navigator.pop(context, _FollowChoice.individual),
          ),
          const SizedBox(height: 12),

          // Board member card — grayed out if cooldown is active
          _ChoiceCard(
            icon: Icons.shield_outlined,
            iconColor: cooldownActive
                ? AppColors.secondaryText
                : const Color(0xFF1565C0),
            bgColor: cooldownActive
                ? AppColors.divider
                : const Color(0xFFE3F2FD),
            title: 'Board Member',
            subtitle: cooldownActive
                ? 'You can reapply for board membership on $cooldownStr.'
                : 'Request elevated access to help manage the club. '
                    'Requires approval from the club admin.',
            badge: cooldownActive ? 'Cooldown active' : 'Requires approval',
            badgeColor: cooldownActive
                ? AppColors.secondaryText
                : const Color(0xFF1565C0),
            badgeBgColor: cooldownActive
                ? AppColors.divider
                : const Color(0xFFE3F2FD),
            disabled: cooldownActive,
            onTap: cooldownActive
                ? () {}
                : () => Navigator.pop(context, _FollowChoice.boardMember),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final Color? badgeBgColor;
  final bool disabled;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.badgeColor,
    this.badgeBgColor,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBgColor ?? const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(badge!,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor ?? const Color(0xFF1565C0))),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.secondaryText, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppColors.secondaryText.withValues(alpha: 0.5), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
