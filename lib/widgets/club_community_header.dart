import 'package:flutter/material.dart';

import '../models/club.dart';
import '../services/app_strings.dart';
import 'club_avatar.dart';
import 'club_chat_theme.dart';
import 'club_community_sheet.dart';
import 'club_stream_items.dart';

/// Identity + live community information header for every club chat.
///
/// Follows the Club Community handoff: back, club monogram, name, the
/// member count, and the notification / settings icon buttons.
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
              label:
                  '${club.name}, ${S.communityMembers(memberCount)}',
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
                          Text(
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
      child: GestureDetector(
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

/// Members / Events / Notices row under the header.
class ClubContextBar extends StatelessWidget {
  const ClubContextBar({
    super.key,
    required this.t,
    required this.onlinePeople,
    required this.avatarBuilder,
    required this.eventCount,
    required this.noticeCount,
    required this.activeTab,
    required this.onOpen,
  });

  final ClubChatTheme t;
  final List<ClubPerson> onlinePeople;
  final Widget Function(ClubPerson person, double size) avatarBuilder;
  final int eventCount;
  final int noticeCount;
  final ClubSheetTab? activeTab;
  final void Function(ClubSheetTab tab) onOpen;

  @override
  Widget build(BuildContext context) {
    final stack = onlinePeople.take(4).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: t.body,
        border: Border(bottom: BorderSide(color: t.hair)),
      ),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('club-members-button'),
            onTap: () => onOpen(ClubSheetTab.members),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              decoration: BoxDecoration(
                color: activeTab == ClubSheetTab.members
                    ? t.ltRed
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (stack.isNotEmpty)
                    SizedBox(
                      height: 24,
                      width: 24 + (stack.length - 1) * 15,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 0; i < stack.length; i++)
                            Positioned(
                              left: i * 15,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: t.body, width: 2),
                                ),
                                child: avatarBuilder(stack[i], 22),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (stack.isNotEmpty) const SizedBox(width: 8),
                  Text(
                    S.communityMembersButton,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 18,
            color: t.hair,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Pill(
                    key: const ValueKey('club-events-button'),
                    icon: Icons.calendar_today_outlined,
                    label: S.communityEventsButton(eventCount),
                    active: activeTab == ClubSheetTab.events,
                    t: t,
                    onTap: () => onOpen(ClubSheetTab.events),
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    key: const ValueKey('club-notices-button'),
                    icon: Icons.campaign_outlined,
                    label: noticeCount > 0
                        ? '${S.communityNotices} · $noticeCount'
                        : S.communityNotices,
                    active: activeTab == ClubSheetTab.notices,
                    t: t,
                    onTap: () => onOpen(ClubSheetTab.notices),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.t,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final ClubChatTheme t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.ltRed : t.solid,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? t.red : t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? t.red : t.sub),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: active ? t.red : t.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dismissible strip showing the club's pinned notice.
class ClubPinnedStrip extends StatelessWidget {
  const ClubPinnedStrip({
    super.key,
    required this.text,
    required this.t,
    required this.onOpen,
    required this.onDismiss,
  });

  final String text;
  final ClubChatTheme t;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('club-pinned-strip'),
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: t.isDark
              ? Colors.white.withValues(alpha: 0.035)
              : t.accent.withValues(alpha: 0.045),
          border: Border(bottom: BorderSide(color: t.hair)),
        ),
        child: Row(
          children: [
            Icon(Icons.push_pin_outlined, size: 13, color: t.red),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.textSoft,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.close_rounded, size: 14, color: t.sub),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
