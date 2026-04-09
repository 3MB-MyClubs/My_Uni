import 'package:flutter/material.dart';
import '../models/board_member_request.dart';
import '../models/notification.dart';
import 'app_colors.dart';
import 'auth_service.dart';
import 'content_store.dart';
import 'mock_data.dart';
import 'user_state.dart';
import 'user_prefs_service.dart';

/// Returns the clubId where [userId] is already a board member, or null.
String? _existingBoardClub(String userId) {
  try {
    return clubs.firstWhere((c) => c.boardMemberIds.contains(userId)).id;
  } catch (_) {
    return null;
  }
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
  // Individual follow is always unrestricted — no exclusive constraint.
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

  // Already pending? — check the persistent list, not session state.
  final alreadyPending = boardMemberRequests.any(
      (r) => r.userId == userId && r.clubId == clubId && r.status == 'pending');
  if (alreadyPending) {
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

  // Admins cannot apply for board membership — they already have elevated access.
  if (authService.currentAdmin != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Club admins cannot apply for board membership.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  // Already a board member of another club?
  final existingClubId = _existingBoardClub(userId);
  if (existingClubId != null && existingClubId != clubId) {
    final existingName =
        clubs.firstWhere((c) => c.id == existingClubId, orElse: () => clubs.first).name;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are already a board member of $existingName. '
              'You can only hold board status in one club at a time.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  final user = authService.currentUser;
  final userName = user?.name ?? 'Someone';
  final userEmail = user?.email ?? '';
  final club = clubs.firstWhere((c) => c.id == clubId, orElse: () => clubs.first);

  final now = DateTime.now();
  final ts = now.millisecondsSinceEpoch;

  // Persist a full BoardMemberRequest record — always pending until manually reviewed.
  final request = BoardMemberRequest(
    id: 'bmr_${userId}_${clubId}_$ts',
    userId: userId,
    userName: userName,
    userEmail: userEmail,
    clubId: clubId,
    requestedAt: now,
    status: 'pending',
  );
  boardMemberRequests.add(request);
  contentStore.saveBoardMemberRequests();

  // Record the pending request in user state.
  userState.sendBoardRequest(userId, clubId);

  // Notify every club admin and existing board member.
  // If no one is registered yet, the request stays pending until an admin is assigned.
  final recipientIds = {
    ...club.adminUserIds,
    ...club.boardMemberIds,
  }..remove(userId); // don't notify the requester themselves

  for (final recipientId in recipientIds) {
    final notif = AppNotification(
      id: 'board_req_${userId}_${clubId}_${recipientId}_$ts',
      userId: recipientId,
      message: '$userName wants to join ${club.name} as a board member.',
      createdAt: now,
      targetType: 'board_member_request',
      targetId: clubId,
      fromId: userId,
    );
    userState.addFollowRequestNotification(notif);
  }

  final myId = user?.id ?? '';
  if (myId.isNotEmpty) userPrefsService.save(myId);

  onChanged();

  if (context.mounted) {
    final hasAdmin = club.adminUserIds.isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasAdmin
              ? 'Board member request sent to ${club.name}.'
              : 'Your request for ${club.name} is pending — it will be reviewed once an admin is assigned.',
        ),
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
    // Admins cannot apply for board membership.
    final isAdmin = authService.currentAdmin != null;

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

          // Board member card — hidden for admins, always available for normal users
          _ChoiceCard(
            icon: Icons.shield_outlined,
            iconColor: isAdmin ? AppColors.secondaryText : const Color(0xFF1565C0),
            bgColor: isAdmin ? AppColors.divider : const Color(0xFFE3F2FD),
            title: 'Board Member',
            subtitle: isAdmin
                ? 'Club admins already have elevated access and cannot apply for board membership.'
                : 'Request elevated access to help manage the club. '
                    'Requires approval from the club admin.',
            badge: isAdmin ? 'Not available' : 'Requires approval',
            badgeColor: isAdmin ? AppColors.secondaryText : const Color(0xFF1565C0),
            badgeBgColor: isAdmin ? AppColors.divider : const Color(0xFFE3F2FD),
            disabled: isAdmin,
            onTap: isAdmin
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
