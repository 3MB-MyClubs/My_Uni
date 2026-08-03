import 'package:flutter/material.dart';

import '../models/club.dart';
import '../services/app_strings.dart';
import 'club_avatar.dart';
import 'club_chat_theme.dart';
import 'club_stream_items.dart';
import 'app_pressable.dart';

/// Identity + live community information header for every club chat.
///
/// Follows the Club Board + Chat handoff: back, club monogram, name with the
/// reader's own role, "N members · M active", and the notification / settings
/// icon buttons. Navigation between the two lanes belongs to the segments
/// below, and Members / About live behind the ••• menu.
class ClubCommunityHeader extends StatelessWidget {
  const ClubCommunityHeader({
    super.key,
    required this.club,
    required this.avatarColor,
    required this.memberCount,
    required this.onOpenClub,
    required this.t,
    this.topInset = 0,
    this.onBack,
    this.onToggleMute,
    this.onOpenSettings,
    this.muted = false,
    this.activeCount = 0,
    this.viewerRoleTitle,
  });

  final Club club;
  final Color avatarColor;
  final int memberCount;
  final VoidCallback onOpenClub;
  final ClubChatTheme t;
  final double topInset;
  final VoidCallback? onBack;
  final VoidCallback? onToggleMute;
  final VoidCallback? onOpenSettings;
  final bool muted;

  /// Members online right now, shown next to the member count.
  final int activeCount;

  /// The reader's own board title, when they hold one — the design puts it
  /// straight next to the club name so authority is visible without a tap.
  final String? viewerRoleTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('club-community-header'),
      color: t.body,
      padding: EdgeInsets.fromLTRB(10, topInset + 2, 14, 8),
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              key: const ValueKey('chat-thread-back'),
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: t.red,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: true,
              label: '${club.name}, ${S.communityMembers(memberCount)}',
              child: GestureDetector(
                onTap: onOpenClub,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    ClubAvatar(
                      clubId: club.id,
                      clubName: club.name,
                      color: avatarColor,
                      imageUrl: club.logoUrl,
                      size: 38,
                      fontSize: 13.5,
                      shape: 'rounded',
                      borderRadius: 12,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  club.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.35,
                                    color: t.text,
                                  ),
                                ),
                              ),
                              if ((viewerRoleTitle ?? '').isNotEmpty) ...[
                                const SizedBox(width: 6),
                                ClubRoleChip(
                                  person: ClubPerson(
                                    id: 'viewer',
                                    name: '',
                                    role: viewerRoleTitle,
                                  ),
                                  t: t,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Text(
                                S.communityMembers(memberCount),
                                key: const ValueKey('club-community-members'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: t.sub,
                                ),
                              ),
                              if (activeCount > 0) ...[
                                Text(
                                  ' · ',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                    color: t.sub,
                                  ),
                                ),
                                Text(
                                  S.communityActiveNow(activeCount),
                                  key: const ValueKey('club-community-active'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                    color: t.online,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ClubHeaderIconButton(
            icon: muted
                ? Icons.notifications_off_outlined
                : Icons.notifications_none_rounded,
            label: muted ? S.unmuteCommunity : S.muteCommunity,
            t: t,
            active: muted,
            onTap: onToggleMute,
          ),
          const SizedBox(width: 8),
          ClubHeaderIconButton(
            icon: Icons.more_horiz_rounded,
            label: S.clubSettings,
            t: t,
            onTap: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

/// Round icon button used across the community header.
class ClubHeaderIconButton extends StatelessWidget {
  const ClubHeaderIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.t,
    this.onTap,
    this.active = false,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final ClubChatTheme t;
  final VoidCallback? onTap;
  final bool active;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: AppPressable(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? t.ltRed : t.solid,
                shape: BoxShape.circle,
                border: Border.all(color: active ? t.red : t.border),
              ),
              child: Icon(icon, size: 18, color: active ? t.red : t.textMuted),
            ),
            if (badge > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.red,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: t.body, width: 2),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
