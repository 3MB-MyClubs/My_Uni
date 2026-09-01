import 'package:flutter/material.dart';

import '../services/app_strings.dart';
import 'chats_design.dart';
import 'clubup_design.dart';

/// The CLUB CHATS INSIDE section of the ClubUp-Desings handoff (Figma section
/// label `483:31`) — what a student sees after tapping a row in the Clubs tab.
///
/// Frames this file draws, light id first:
///
/// * `club-chats-loading` `140:94` / `140:187`, `club-chats-empty` `140:3` /
///   `140:48`, `club-chats-search` `141:3` / `141:73` — the three Clubs-tab
///   states.
/// * `club-announcements` `143:188` / `143:282` — the Board lane.
/// * `club-chat-reply` `143:3` / `143:95` — the Chats lane.
/// * `club-detail-dropdown` `219:6` / `219:103` — the Board / Chats / Direct
///   lane menu.
/// * `club-message-actions` `146:3` / `146:150` and `club-attachment-sheet`
///   `146:298` / `146:428`.
///
/// The palette is [ChatsColors] unchanged — sampling the club frames turns up
/// exactly the same ramp as the rest of CHATS, accent-text lift included.
///
/// Since the `CLUB CHATS` pass (section label `543:32`, the widgets at the end
/// of this file) the **club side** draws these too. Only the ClubUp platform
/// moderator still gets the previous chrome: no frame has been drawn for it.

/// The three destinations inside a club room. Mirrors `ClubCommunityTab`, kept
/// separate so this file has no dependency on the screen.
enum ClubRoomLane { board, chats, direct }

IconData clubLaneIcon(ClubRoomLane lane) => switch (lane) {
  ClubRoomLane.board => Icons.campaign_outlined,
  ClubRoomLane.chats => Icons.chat_bubble_outline_rounded,
  ClubRoomLane.direct => Icons.lock_outline_rounded,
};

String clubLaneLabel(ClubRoomLane lane) => switch (lane) {
  ClubRoomLane.board => S.clubLaneBoard,
  ClubRoomLane.chats => S.clubLaneChats,
  ClubRoomLane.direct => S.clubLaneDirect,
};

// ── header ───────────────────────────────────────────────────────────────────

/// `club-header` `221:354` — a 72pt bar with no rule under it: chevron, club
/// avatar, name over a member count, and the solid accent lane pill on the
/// right. The segmented Board/Chat/Solo switch the app used to draw below the
/// header is replaced by that pill.
class ClubRoomHeader extends StatelessWidget {
  final Widget avatar;
  final String clubName;
  final String memberLine;
  final ClubRoomLane lane;
  final GlobalKey laneAnchorKey;
  final VoidCallback onLaneTap;
  final VoidCallback? onBack;
  final VoidCallback? onOpenClub;
  final int laneBadge;

  const ClubRoomHeader({
    super.key,
    required this.avatar,
    required this.clubName,
    required this.memberLine,
    required this.lane,
    required this.laneAnchorKey,
    required this.onLaneTap,
    this.onBack,
    this.onOpenClub,
    this.laneBadge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.viewPaddingOf(context).top),
      color: ChatsColors.background,
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            const SizedBox(width: 16),
            if (onBack != null) ...[
              Semantics(
                button: true,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                child: GestureDetector(
                  key: const ValueKey('club-room-back'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onBack,
                  child: SizedBox(
                    width: 24,
                    height: 72,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 24,
                      color: ChatsColors.accentText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: GestureDetector(
                key: const ValueKey('club-room-identity'),
                behavior: HitTestBehavior.opaque,
                onTap: onOpenClub,
                child: Row(
                  children: [
                    SizedBox(width: 38, height: 38, child: avatar),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clubName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: figtree(
                              size: 15,
                              weight: FontWeight.w700,
                              color: ChatsColors.text,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            memberLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: figtree(
                              size: 11,
                              weight: FontWeight.w500,
                              color: ChatsColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ClubLanePill(
              anchorKey: laneAnchorKey,
              lane: lane,
              onTap: onLaneTap,
              badge: laneBadge,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

/// `tab-dropdown` `221:363` — the solid accent pill that opens the lane menu.
class ClubLanePill extends StatelessWidget {
  final GlobalKey anchorKey;
  final ClubRoomLane lane;
  final VoidCallback onTap;
  final int badge;

  const ClubLanePill({
    super.key,
    required this.anchorKey,
    required this.lane,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('club-lane-pill'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        key: anchorKey,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ChatsColors.accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(clubLaneIcon(lane), size: 14, color: ChatsColors.onAccent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                clubLaneLabel(lane),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 13,
                  weight: FontWeight.w700,
                  color: ChatsColors.onAccent,
                ),
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: ChatsColors.onAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: figtree(
                      size: 9,
                      weight: FontWeight.w800,
                      color: ChatsColors.accent,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: ChatsColors.onAccent,
            ),
          ],
        ),
      ),
    );
  }
}

/// `club-detail-dropdown` `219:6` — a card anchored under the lane pill with
/// Board / Chats / Direct and a check on the current lane.
Future<ClubRoomLane?> showClubLaneMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required ClubRoomLane current,
  Set<ClubRoomLane> disabled = const {},
  Map<ClubRoomLane, int> badges = const {},
}) {
  final anchor = anchorKey.currentContext;
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlayBox =
      navigator.overlay!.context.findRenderObject()! as RenderBox;
  const menuWidth = 168.0;
  const menuHeight = 115.0;
  const menuGap = 6.0;
  var left = 0.0;
  var top = 0.0;
  if (anchor != null) {
    final box = anchor.findRenderObject()! as RenderBox;
    final topRight = box.localToGlobal(
      Offset(box.size.width, box.size.height + menuGap),
      ancestor: overlayBox,
    );
    left = topRight.dx - menuWidth;
    top = topRight.dy;
  }
  return showDialog<ClubRoomLane>(
    context: context,
    useRootNavigator: true,
    // The anchor coordinates are measured in the root overlay. Let the dialog
    // fill that same coordinate space; showDialog's default SafeArea would add
    // the status-bar inset a second time and move the menu away from the pill.
    useSafeArea: false,
    barrierColor: Colors.transparent,
    builder: (dialogContext) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('club-lane-menu-scrim'),
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(dialogContext),
          ),
        ),
        Positioned(
          left: left.clamp(8.0, overlayBox.size.width - menuWidth - 8),
          top: top.clamp(8.0, overlayBox.size.height - menuHeight - 8),
          child: Material(
            key: const ValueKey('club-lane-menu-card'),
            color: ChatsColors.card,
            borderRadius: BorderRadius.circular(kChatCardRadius),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            child: SizedBox(
              width: menuWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final lane in ClubRoomLane.values)
                      _LaneRow(
                        lane: lane,
                        selected: lane == current,
                        enabled: !disabled.contains(lane),
                        badge: badges[lane] ?? 0,
                        onTap: () => Navigator.pop(dialogContext, lane),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LaneRow extends StatelessWidget {
  final ClubRoomLane lane;
  final bool selected;
  final bool enabled;
  final int badge;
  final VoidCallback onTap;

  const _LaneRow({
    required this.lane,
    required this.selected,
    required this.enabled,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? ChatsColors.muted
        : selected
        ? ChatsColors.accentText
        : ChatsColors.text;
    return InkWell(
      key: ValueKey('club-lane-option-${lane.name}'),
      onTap: enabled ? onTap : null,
      child: SizedBox(
        height: 33,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(clubLaneIcon(lane), size: 14, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                clubLaneLabel(lane),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 14,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (badge > 0 && !selected)
              Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: ChatsColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: figtree(
                      size: 9,
                      weight: FontWeight.w800,
                      color: ChatsColors.onAccent,
                    ),
                  ),
                ),
              )
            else if (selected)
              Icon(Icons.check_rounded, size: 16, color: ChatsColors.accent),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

// ── Board lane ───────────────────────────────────────────────────────────────

/// `announcement-card` `143:222` — the notice as a card rather than a bubble:
/// author, role badge, when, body, reaction chips and a reply count.
class ClubNoticeCard extends StatelessWidget {
  final Widget avatar;
  final String authorName;
  final String? roleLabel;
  final String whenLabel;
  final String body;
  final String? title;
  final Widget? attachment;
  final bool pinned;
  final Map<String, int> reactions;
  final Set<String> myReactions;
  final int replyCount;
  final ValueChanged<String>? onToggleReaction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOpenReplies;

  const ClubNoticeCard({
    super.key,
    required this.avatar,
    required this.authorName,
    required this.whenLabel,
    required this.body,
    this.roleLabel,
    this.title,
    this.attachment,
    this.pinned = false,
    this.reactions = const {},
    this.myReactions = const {},
    this.replyCount = 0,
    this.onToggleReaction,
    this.onTap,
    this.onLongPress,
    this.onOpenReplies,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: ChatsColors.card,
        borderRadius: BorderRadius.circular(kChatCardRadius),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(kChatCardRadius),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kChatCardRadius),
              border: Border.all(color: ChatsColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 28, height: 28, child: avatar),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: figtree(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: ChatsColors.text,
                                  ),
                                ),
                              ),
                              if (roleLabel != null) ...[
                                const SizedBox(width: 6),
                                _Badge(label: roleLabel!),
                              ],
                              if (pinned) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.push_pin_rounded,
                                  size: 12,
                                  color: ChatsColors.accentText,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            whenLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: figtree(
                              size: 11,
                              weight: FontWeight.w500,
                              color: ChatsColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if ((title ?? '').trim().isNotEmpty) ...[
                  Text(
                    title!,
                    style: figtree(
                      size: 14,
                      weight: FontWeight.w700,
                      color: ChatsColors.text,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (body.trim().isNotEmpty)
                  Text(
                    body,
                    style: figtree(
                      size: 14,
                      weight: FontWeight.w400,
                      color: ChatsColors.text,
                      height: 1.5,
                    ),
                  ),
                ?attachment,
                if (reactions.isNotEmpty || replyCount > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final entry in reactions.entries)
                              _ReactionChip(
                                emoji: entry.key,
                                count: entry.value,
                                mine: myReactions.contains(entry.key),
                                onTap: onToggleReaction == null
                                    ? null
                                    : () => onToggleReaction!(entry.key),
                              ),
                          ],
                        ),
                      ),
                      if (replyCount > 0) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onOpenReplies,
                          child: Text(
                            S.clubReplyCount(replyCount),
                            style: figtree(
                              size: 11,
                              weight: FontWeight.w600,
                              color: ChatsColors.accentText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `badge` `143:228` — the accent-tinted role chip beside an author's name.
class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ChatsColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: figtree(
          size: 10,
          weight: FontWeight.w700,
          color: ChatsColors.accentText,
        ),
      ),
    );
  }
}

/// `reaction` `143:234` — a bordered card-coloured chip, unlike the flat chips
/// on a student thread.
class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback? onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.mine,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('club-reaction-$emoji'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: mine
              ? ChatsColors.accent.withValues(alpha: 0.10)
              : ChatsColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: mine ? ChatsColors.accent : ChatsColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
            // `143:236` prints a number beside every emoji, including 1.
            Text(
              '$count',
              style: figtree(
                size: 11,
                weight: FontWeight.w600,
                color: ChatsColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `composer-locked` `143:276` — the Board's footer when the reader cannot
/// post: a shield and one quiet line where the composer would be.
class ClubLockedStrip extends StatelessWidget {
  final String label;

  const ClubLockedStrip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ChatsColors.background,
        border: Border(top: BorderSide(color: ChatsColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 18, color: ChatsColors.muted),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: figtree(
                    size: 13,
                    weight: FontWeight.w500,
                    color: ChatsColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chats lane ───────────────────────────────────────────────────────────────

/// `system-message` `143:33` — the centred grey pill the Chats lane uses for
/// "Elif pinned a message".
class ClubSystemStrip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const ClubSystemStrip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: ChatsColors.fill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: ChatsColors.muted),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 11,
                      weight: FontWeight.w500,
                      color: ChatsColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `bubble-typing` `143:70` — three dots in a bubble beside the sender's
/// avatar, animating in sequence.
class ChatTypingBubble extends StatefulWidget {
  final List<Widget> avatars;
  final String semanticLabel;

  const ChatTypingBubble({
    super.key,
    required this.avatars,
    required this.semanticLabel,
  });

  @override
  State<ChatTypingBubble> createState() => _ChatTypingBubbleState();
}

class _ChatTypingBubbleState extends State<ChatTypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            SizedBox(
              width: widget.avatars.length > 1 ? 38 : 28,
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < widget.avatars.length && i < 2; i++)
                    Positioned(left: i * 10, child: widget.avatars[i]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 63,
              height: 35,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ChatsColors.fill,
                borderRadius: BorderRadius.circular(kChatBubbleRadius),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Opacity(
                        opacity:
                            0.35 +
                            0.65 *
                                (((_controller.value * 3) - i).clamp(0.0, 1.0) *
                                    (1 -
                                        ((_controller.value * 3) - i - 1).clamp(
                                          0.0,
                                          1.0,
                                        ))),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: ChatsColors.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── sheets ───────────────────────────────────────────────────────────────────

/// One row of the long-press sheet.
class ClubMessageAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final Key? rowKey;

  const ClubMessageAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.rowKey,
  });
}

/// `club-message-actions` `146:3` — a quick-reaction row over the action list.
/// The trailing ✓ chip opens the full emoji picker.
Future<void> showClubMessageActions(
  BuildContext context, {
  required List<String> quickEmojis,
  required Set<String> myReactions,
  required ValueChanged<String> onReact,
  required VoidCallback onMoreEmoji,
  required List<ClubMessageAction> actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: ChatsColors.scrim,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (sheetContext) => Container(
      key: const ValueKey('club-message-actions-sheet'),
      decoration: BoxDecoration(
        color: ChatsColors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kChatSheetRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: ChatsColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final emoji in quickEmojis)
                      _EmojiChip(
                        emoji: emoji,
                        selected: myReactions.contains(emoji),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          onReact(emoji);
                        },
                      ),
                    _EmojiChip(
                      icon: Icons.add_reaction_outlined,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onMoreEmoji();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const ChatsCardDivider(),
                  ),
                _ActionRow(action: actions[i]),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EmojiChip extends StatelessWidget {
  final String? emoji;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _EmojiChip({
    this.emoji,
    this.icon,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('club-quick-react-${emoji ?? 'more'}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? ChatsColors.accent.withValues(alpha: 0.12)
              : ChatsColors.fill,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: ChatsColors.accent) : null,
        ),
        child: icon != null
            ? Icon(icon, size: 19, color: ChatsColors.muted)
            : Text(emoji!, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final ClubMessageAction action;

  const _ActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final color = action.destructive
        ? ChatsColors.danger
        : ChatsColors.accentText;
    return InkWell(
      key: action.rowKey,
      onTap: () {
        Navigator.pop(context);
        action.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 53,
          child: Row(
            children: [
              Icon(action.icon, size: 20, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: figtree(
                    size: 15,
                    weight: FontWeight.w500,
                    color: action.destructive
                        ? ChatsColors.danger
                        : ChatsColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tile of the share sheet.
class ClubShareOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Key? tileKey;

  const ClubShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tileKey,
  });
}

/// `club-attachment-sheet` `146:298` — "Share to `<club>`", a grid of round
/// options, and a Cancel button. The subtitle is the point of the sheet: this
/// room is not private.
Future<void> showClubShareSheet(
  BuildContext context, {
  required String clubName,
  required String visibilityLine,
  required List<ClubShareOption> options,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: ChatsColors.scrim,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (sheetContext) => Container(
      key: const ValueKey('club-share-sheet'),
      decoration: BoxDecoration(
        color: ChatsColors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kChatSheetRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: ChatsColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  S.clubShareToTitle(clubName),
                  style: figtree(
                    size: 17,
                    weight: FontWeight.w700,
                    color: ChatsColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  visibilityLine,
                  style: figtree(
                    size: 13,
                    weight: FontWeight.w400,
                    color: ChatsColors.muted,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.05,
                  children: [
                    for (final option in options)
                      GestureDetector(
                        key: option.tileKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          option.onTap();
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: ChatsColors.fill,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                option.icon,
                                size: 22,
                                color: ChatsColors.accentText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              option.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: figtree(
                                size: 12,
                                weight: FontWeight.w500,
                                color: ChatsColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const ChatsCardDivider(),
                const SizedBox(height: 16),
                GestureDetector(
                  key: const ValueKey('club-share-cancel'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(sheetContext),
                  child: Container(
                    height: 47,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(kChatCardRadius),
                      border: Border.all(color: ChatsColors.border),
                    ),
                    child: Text(
                      S.cancel,
                      style: figtree(
                        size: 15,
                        weight: FontWeight.w700,
                        color: ChatsColors.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Clubs-tab states ─────────────────────────────────────────────────────────

/// `club-chats-empty` `140:31` — the Clubs tab with nothing in it.
class ClubChatsEmptyState extends StatelessWidget {
  final VoidCallback? onExploreClubs;
  final VoidCallback? onBrowseEvents;

  const ClubChatsEmptyState({
    super.key,
    this.onExploreClubs,
    this.onBrowseEvents,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(36, 60, 36, 40),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ChatsColors.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 26,
              color: ChatsColors.accentText,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            S.clubChatsEmptyTitle,
            textAlign: TextAlign.center,
            style: figtree(
              size: 17,
              weight: FontWeight.w800,
              color: ChatsColors.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            S.clubChatsEmptyBody,
            textAlign: TextAlign.center,
            style: figtree(
              size: 13,
              weight: FontWeight.w400,
              color: ChatsColors.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _EmptyAction(
            actionKey: const ValueKey('club-chats-explore-clubs'),
            icon: Icons.add_rounded,
            label: S.clubChatsExploreClubs,
            filled: true,
            onTap: onExploreClubs,
          ),
          const SizedBox(height: 10),
          _EmptyAction(
            actionKey: const ValueKey('club-chats-browse-events'),
            icon: Icons.calendar_today_outlined,
            label: S.clubChatsBrowseEvents,
            filled: false,
            onTap: onBrowseEvents,
          ),
          const SizedBox(height: 20),
          Text(
            S.clubChatsFriendsHint,
            textAlign: TextAlign.center,
            style: figtree(
              size: 11,
              weight: FontWeight.w400,
              color: ChatsColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAction extends StatelessWidget {
  final Key actionKey;
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _EmptyAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.filled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: actionKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: filled ? ChatsColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: filled ? null : Border.all(color: ChatsColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? ChatsColors.onAccent : ChatsColors.text,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: figtree(
                size: 14,
                weight: FontWeight.w700,
                color: filled ? ChatsColors.onAccent : ChatsColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `club-chats-loading` `140:94` — eight placeholder rows on the same 72pt
/// metrics as a real inbox row.
///
/// Deliberately **static**: the frame draws flat grey bars with no shimmer, and
/// a repeating controller here would hang `pumpAndSettle` in every widget test
/// that mounts the inbox while the first sync is still in flight.
class ClubChatsSkeleton extends StatelessWidget {
  final int rows;

  const ClubChatsSkeleton({super.key, this.rows = 8});

  @override
  Widget build(BuildContext context) {
    final base = ChatsColors.fill;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    return IgnorePointer(
      child: ListView.builder(
        key: const ValueKey('club-chats-skeleton'),
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: rows,
        itemBuilder: (context, index) => SizedBox(
          height: 72,
          child: Row(
            children: [
              const SizedBox(width: 20),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: base, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(index.isEven ? 150 : 116, 11),
                    const SizedBox(height: 8),
                    bar(index.isEven ? 210 : 176, 10),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  bar(34, 9),
                  const SizedBox(height: 10),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: base,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CLUB CHATS (the board side) ───────────────────────────────────────────────
//
// Section label `543:32`. The same room, read by the club rather than by a
// student, so the Board / Chats / Direct chrome above is reused as it stands.
// Two things are only on these frames:
//
// * `admin-dm-list` `335:6` / `335:127` — the Direct lane as an inbox. Its
//   header drops the club identity for a plain "Messages" title and gains a
//   search field, because the board side sees every student conversation
//   where a member sees exactly one.
// * `admin-chats-list` `331:136` / `331:235` — the Board lane with a real
//   composer ("Write an announcement…") where the student frame draws only the
//   locked strip.
//
// `admin-board-chat` `331:10` / `331:73` (the Chats lane) and
// `admin-direct-messages` `335:255` / `331:438` (a private thread) are the
// student frames with club content in them, and draw through the existing
// widgets unchanged.
//
// Palette is still [ChatsColors]: the Board and Chats frames sample to exactly
// the CHATS ramp. `admin-dm-list` and `admin-direct-messages` drift to a
// darker `#0A0A0A` page over `#1C1C1E` surfaces, which would put two different
// blacks inside one room — the majority wins, as it did for the inbox pair in
// [ChatsColors].

/// `chat-header` `335:21` — the Direct lane's own bar: a chevron back to the
/// lane you came from, "Messages" in ExtraBold 20, and the same accent lane
/// pill as [ClubRoomHeader].
class ClubDirectInboxHeader extends StatelessWidget {
  final String title;
  final GlobalKey laneAnchorKey;
  final VoidCallback onLaneTap;
  final VoidCallback? onBack;
  final int laneBadge;

  const ClubDirectInboxHeader({
    super.key,
    required this.title,
    required this.laneAnchorKey,
    required this.onLaneTap,
    this.onBack,
    this.laneBadge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.viewPaddingOf(context).top),
      color: ChatsColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 32,
          child: Row(
            children: [
              if (onBack != null) ...[
                Semantics(
                  button: true,
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  child: GestureDetector(
                    key: const ValueKey('club-direct-inbox-back'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onBack,
                    child: SizedBox(
                      width: 24,
                      height: 32,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 24,
                        color: ChatsColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: figtree(
                    size: 20,
                    weight: FontWeight.w800,
                    color: ChatsColors.text,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ClubLanePill(
                anchorKey: laneAnchorKey,
                lane: ClubRoomLane.direct,
                onTap: onLaneTap,
                badge: laneBadge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `search-container` `335:35` — a 38pt filled pill. The frame paints it
/// `#E4E4E7` at half alpha; [ChatsColors.fill] is the token for every other
/// search box in the area and lands within a shade of it.
class ClubDirectSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const ClubDirectSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: ChatsColors.fill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 14, color: ChatsColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('club-direct-search-field'),
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: figtree(
                  size: 14,
                  weight: FontWeight.w400,
                  color: ChatsColors.text,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: figtree(
                    size: 14,
                    weight: FontWeight.w400,
                    color: ChatsColors.muted,
                  ),
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `conversation-row` `335:52` — a 48pt avatar, the name over the last
/// message, and the time. No hairline between rows on this frame, and unread
/// is an 8pt dot beside the preview rather than a count: the board side reads
/// the inbox row by row, not by how much is waiting in each one.
class ClubDirectInboxRow extends StatelessWidget {
  final Widget avatar;
  final String name;
  final String whenLabel;
  final String preview;
  final bool unread;
  final VoidCallback? onTap;

  const ClubDirectInboxRow({
    super.key,
    required this.avatar,
    required this.name,
    required this.whenLabel,
    required this.preview,
    required this.unread,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // No wash behind an unread row here: 335:63 marks it with the dot and the
    // accent timestamp only, where the Friends inbox tints the whole row.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 48, height: 48, child: avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: figtree(
                              size: 15,
                              weight: FontWeight.w800,
                              color: ChatsColors.text,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          whenLabel,
                          style: figtree(
                            size: 12,
                            weight: FontWeight.w600,
                            color: unread
                                ? ChatsColors.accentText
                                : ChatsColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: figtree(
                              size: 13,
                              weight: unread
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: unread
                                  ? ChatsColors.text
                                  : ChatsColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ChatsColors.accent,
                              shape: BoxShape.circle,
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
    );
  }
}

/// A poll inside a chat bubble. The handoff's club frames never draw one —
/// `club-attachment-sheet` 146:298 offers Poll, but no frame shows the result —
/// so this stays inside the bubble it was sent in and borrows the bubble's own
/// colours rather than inventing a card. Without it a poll would render as an
/// empty bubble, which is what the design lane did before CLUB CHATS put the
/// club account (the only account that sends polls here) on this path.
class ClubBubblePoll extends StatelessWidget {
  final String question;
  final List<String> options;
  final List<int> counts;
  final int total;
  final int? myChoice;
  final String? closesLabel;
  final bool mine;
  final bool closed;
  final ValueChanged<int>? onVote;

  const ClubBubblePoll({
    super.key,
    required this.question,
    required this.options,
    required this.counts,
    required this.total,
    required this.mine,
    required this.closed,
    this.myChoice,
    this.closesLabel,
    this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final onBubble = mine ? ChatsColors.onAccent : ChatsColors.text;
    final track = onBubble.withValues(alpha: mine ? 0.18 : 0.06);
    final fill = mine
        ? ChatsColors.onAccent.withValues(alpha: 0.34)
        : ChatsColors.accent.withValues(alpha: 0.16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: figtree(
            size: 14,
            weight: FontWeight.w700,
            color: onBubble,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          GestureDetector(
            key: ValueKey('club-bubble-poll-option-$i'),
            behavior: HitTestBehavior.opaque,
            onTap: closed || onVote == null ? null : () => onVote!(i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Container(height: 34, color: track),
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: total == 0
                          ? 0
                          : (counts.length > i ? counts[i] : 0) / total,
                      child: ColoredBox(color: fill),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          if (myChoice == i) ...[
                            Icon(
                              Icons.check_circle_rounded,
                              size: 13,
                              color: onBubble,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              options[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: figtree(
                                size: 13,
                                weight: myChoice == i
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: onBubble,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${counts.length > i ? counts[i] : 0}',
                            style: figtree(
                              size: 12,
                              weight: FontWeight.w600,
                              color: onBubble.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (closesLabel != null && closesLabel!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            closesLabel!,
            style: figtree(
              size: 11,
              weight: FontWeight.w500,
              color: onBubble.withValues(alpha: 0.72),
            ),
          ),
        ],
      ],
    );
  }
}
