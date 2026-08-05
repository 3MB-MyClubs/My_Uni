import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/app_strings.dart';
import '../services/chat_store.dart';
import 'app_pressable.dart';
import 'club_chat_theme.dart';
import 'club_stream_items.dart';

/// The one navigation control of a club room: Board | Chat, each segment
/// carrying its own unread count.
///
/// Follows the "Club Board + Chat" handoff — a notice is one object, so the
/// Board is the notice area and the Chat is the room where board replies live.
class ClubLaneSwitch extends StatelessWidget {
  const ClubLaneSwitch({
    super.key,
    required this.lane,
    required this.onLane,
    required this.boardUnread,
    required this.chatUnread,
    required this.t,
  });

  final ClubChatLane lane;
  final void Function(ClubChatLane lane) onLane;
  final int boardUnread;
  final int chatUnread;
  final ClubChatTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('club-lane-switch'),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 11),
      decoration: BoxDecoration(
        color: t.body,
        border: Border(bottom: BorderSide(color: t.hair)),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: t.solid,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: t.border),
        ),
        child: Row(
          children: [
            _segment(
              ClubChatLane.board,
              Icons.campaign_outlined,
              S.clubBoardTab,
              boardUnread,
            ),
            const SizedBox(width: 4),
            _segment(
              ClubChatLane.chat,
              Icons.groups_2_outlined,
              S.clubChatTab,
              chatUnread,
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(ClubChatLane value, IconData icon, String label, int unread) {
    final on = lane == value;
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        label: unread > 0 ? '$label, ${S.nNew(unread)}' : label,
        child: GestureDetector(
          key: ValueKey('club-lane-${value.name}'),
          onTap: () => onLane(value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? t.sheet : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: t.accent.withValues(alpha: 0.16),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: on ? t.red : t.sub),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: on ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: -0.2,
                    color: on ? t.text : t.sub,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 7),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? t.red : t.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: on ? Colors.white : t.red,
                      ),
                    ),
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

/// Uppercase group label above a notice group ("Pinned", "New · 2", "Earlier").
class ClubBoardLabel extends StatelessWidget {
  const ClubBoardLabel({
    super.key,
    required this.label,
    required this.t,
    this.top = false,
  });

  final String label;
  final ClubChatTheme t;

  /// Extra breathing room when another group sits above this one.
  final bool top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top ? 22 : 6, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.3,
          color: t.sub,
        ),
      ),
    );
  }
}

/// One grouped list of notices — a single card, one hairline-separated row per
/// notice.
class ClubNoticeGroup extends StatelessWidget {
  const ClubNoticeGroup({
    super.key,
    required this.rows,
    required this.t,
  });

  final List<Widget> rows;
  final ClubChatTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

/// A notice as a row: headline only until it is tapped, then the body, its
/// attachment, reactions, and the route into Chat.
///
/// The Board stays scannable however long the copy is, which is why nothing
/// expands by default and replies never live under the notice.
class ClubNoticeRow extends StatefulWidget {
  const ClubNoticeRow({
    super.key,
    required this.message,
    required this.author,
    required this.avatar,
    required this.whenLabel,
    required this.unread,
    required this.replyCount,
    required this.showRoles,
    required this.last,
    required this.t,
    required this.onReplyInChat,
    this.replyEnabled = true,
    this.onLongPress,
    this.onOpenAuthor,
    this.attachments = const [],
    this.reactions,
    this.initiallyExpanded = false,
  });

  final ChatMessage message;
  final ClubPerson author;
  final Widget avatar;
  final String whenLabel;

  /// Posted after this reader last opened the Board.
  final bool unread;
  final int replyCount;
  final bool showRoles;

  /// Last row of its group — drops the trailing hairline.
  final bool last;
  final ClubChatTheme t;
  final VoidCallback onReplyInChat;

  /// False for a reader who cannot post in the room: the notice still opens,
  /// it just has no reply route.
  final bool replyEnabled;
  final VoidCallback? onLongPress;
  final VoidCallback? onOpenAuthor;
  final List<Widget> attachments;
  final Widget? reactions;
  final bool initiallyExpanded;

  @override
  State<ClubNoticeRow> createState() => _ClubNoticeRowState();
}

class _ClubNoticeRowState extends State<ClubNoticeRow> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final message = widget.message;
    final title = (message.title ?? '').trim().isEmpty
        ? message.content
        : message.title!;
    final body = (message.title ?? '').trim().isEmpty ? '' : message.content;
    final hasAttachment = message.attachmentPath != null;

    return Container(
      key: ValueKey('club-notice-${message.id}'),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: widget.last && !_open ? Colors.transparent : t.hair,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: _open ? S.boardCollapseNotice : S.boardExpandNotice,
            child: GestureDetector(
              key: ValueKey('club-notice-headline-${message.id}'),
              onTap: () => setState(() => _open = !_open),
              onLongPress: widget.onLongPress,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 7,
                      child: widget.unread && !_open
                          ? Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: t.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15.5,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: t.text,
                            ),
                          ),
                          const SizedBox(height: 5),
                          _metaRow(hasAttachment),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: t.sub,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 0, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onOpenAuthor,
                        child: widget.avatar,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onOpenAuthor,
                          child: Text(
                            widget.author.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: t.textSoft,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ClubRoleChip(
                        person: widget.author,
                        t: t,
                        show: widget.showRoles,
                      ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.55,
                        color: t.textMuted,
                      ),
                    ),
                  ],
                  ...widget.attachments,
                  ?widget.reactions,
                  if (widget.replyEnabled) ...[
                  const SizedBox(height: 13),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppPressable(
                      key: ValueKey('club-notice-reply-${message.id}'),
                      onTap: widget.onReplyInChat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: t.ltRed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.reply_rounded, size: 14, color: t.red),
                            const SizedBox(width: 6),
                            Text(
                              widget.replyCount > 0
                                  ? S.boardRepliesInChat(widget.replyCount)
                                  : S.boardReplyInChat,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: t.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _metaRow(bool hasAttachment) {
    final t = widget.t;
    final muted = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: t.sub,
    );
    final dot = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text('·', style: muted.copyWith(color: t.sub.withValues(alpha: 0.5))),
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (widget.message.pinned) ...[
          Icon(Icons.push_pin_outlined, size: 11, color: t.red),
          const SizedBox(width: 4),
          Text(
            S.pinnedLabel,
            style: muted.copyWith(color: t.red, fontWeight: FontWeight.w800),
          ),
          dot,
        ],
        Text(_firstName(widget.author.name), style: muted),
        dot,
        Text(widget.whenLabel, style: muted),
        if (hasAttachment) ...[
          dot,
          Icon(Icons.description_outlined, size: 11, color: t.sub),
        ],
        if (widget.replyCount > 0) ...[
          dot,
          Text(
            S.boardReplyCount(widget.replyCount),
            style: muted.copyWith(color: t.red, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  String _firstName(String name) => name.split(RegExp(r'\s+')).first;
}

/// Footer of the Board for a member holding a role: the notice composer.
class ClubBoardPostBar extends StatelessWidget {
  const ClubBoardPostBar({
    super.key,
    required this.t,
    required this.onPost,
  });

  final ClubChatTheme t;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: t.body,
        border: Border(top: BorderSide(color: t.hair)),
      ),
      child: SafeArea(
        top: false,
        child: AppPressable(
          key: const ValueKey('club-post-notice'),
          onTap: onPost,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: t.meGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.campaign_outlined, size: 17, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  S.boardPostNotice,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: Colors.white,
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

/// Footer of the Board for a member without a role. No disabled button — the
/// strip states the rule and doubles as the doorway into Chat.
class ClubBoardLockedStrip extends StatelessWidget {
  const ClubBoardLockedStrip({
    super.key,
    required this.t,
    required this.onGoToChat,
  });

  final ClubChatTheme t;
  final VoidCallback onGoToChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.body,
        border: Border(top: BorderSide(color: t.hair)),
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          key: const ValueKey('club-board-locked-strip'),
          onTap: onGoToChat,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 15, color: t.sub),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    S.boardOnlyBoardPosts,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: t.sub,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  S.boardSayItInChat,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: t.red,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(Icons.chevron_right_rounded, size: 16, color: t.red),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty Board: the notice area before its first notice.
class ClubBoardEmpty extends StatelessWidget {
  const ClubBoardEmpty({super.key, required this.t, required this.canPost});

  final ClubChatTheme t;
  final bool canPost;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          key: const ValueKey('club-board-empty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.ltRed, shape: BoxShape.circle),
              child: Icon(Icons.campaign_outlined, size: 28, color: t.red),
            ),
            const SizedBox(height: 16),
            Text(
              S.boardEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: t.text,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              canPost ? S.boardEmptyHintStaff : S.boardEmptyHintMember,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: t.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The composer's quote bar: "Reply in chat" carried the notice across lanes,
/// so the message being written is visibly attached to it.
class ClubNoticeQuoteBar extends StatelessWidget {
  const ClubNoticeQuoteBar({
    super.key,
    required this.title,
    required this.t,
    required this.onClear,
  });

  final String title;
  final ClubChatTheme t;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('club-notice-quote-bar'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.fromLTRB(11, 9, 6, 9),
      decoration: BoxDecoration(
        color: t.ltRed,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(left: BorderSide(color: t.red, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign_outlined, size: 14, color: t.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.boardReplyingToNotice,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: t.red,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: t.textSoft,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('club-clear-notice-quote'),
            tooltip: S.cancelReply,
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: Icon(Icons.close_rounded, size: 16, color: t.sub),
          ),
        ],
      ),
    );
  }
}
