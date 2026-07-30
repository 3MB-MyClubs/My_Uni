import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/app_strings.dart';
import '../services/club_chat_prefs.dart';
import 'club_chat_theme.dart';

/// One participant of a club community, as the stream and sheets need them.
class ClubPerson {
  final String id;
  final String name;

  /// Board title ("President", "Vice President", …) or the admin label.
  /// `null` for a plain member — the design hides the chip for those.
  final String? role;
  final bool online;
  final bool isClubAccount;
  final String? lastSeenLabel;

  const ClubPerson({
    required this.id,
    required this.name,
    this.role,
    this.online = false,
    this.isClubAccount = false,
    this.lastSeenLabel,
  });
}

/// Uppercase role pill shown next to a name. Hidden for plain members and
/// when the reader turned badges off.
class ClubRoleChip extends StatelessWidget {
  const ClubRoleChip({
    super.key,
    required this.person,
    required this.t,
    this.show = true,
    this.onBoldSurface = false,
  });

  final ClubPerson person;
  final ClubChatTheme t;
  final bool show;
  final bool onBoldSurface;

  @override
  Widget build(BuildContext context) {
    final role = person.role;
    if (!show || role == null || role.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: onBoldSurface
            ? Colors.white.withValues(alpha: 0.2)
            : t.accent.withValues(alpha: t.isDark ? 0.24 : 0.11),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
          height: 1.3,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: onBoldSurface ? Colors.white : t.red,
        ),
      ),
    );
  }
}

/// Sticky day separator ("Today", "Yesterday", "3 Oct").
class ClubDayMark extends StatelessWidget {
  const ClubDayMark({super.key, required this.label, required this.t});

  final String label;
  final ClubChatTheme t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          decoration: BoxDecoration(
            color: t.card.withValues(alpha: t.isDark ? 0.86 : 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.hair),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: t.sub,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hairline system event ("… joined the club").
class ClubSystemLine extends StatelessWidget {
  const ClubSystemLine({super.key, required this.label, required this.t});

  final String label;
  final ClubChatTheme t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: t.hair)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: t.sub,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: t.hair)),
        ],
      ),
    );
  }
}

/// "You left off here · N new" divider, and the scroll anchor on open.
class ClubUnreadDivider extends StatelessWidget {
  const ClubUnreadDivider({super.key, required this.count, required this.t});

  final int count;
  final ClubChatTheme t;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 1.5,
        decoration: BoxDecoration(
          color: t.red.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
    return Padding(
      key: const ValueKey('club-unread-divider'),
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: t.red,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                S.leftOffHere(count).toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}

/// Message text with `@mention` tokens highlighted.
class ClubMessageText extends StatelessWidget {
  const ClubMessageText({
    super.key,
    required this.text,
    required this.t,
    required this.onDark,
  });

  final String text;
  final ClubChatTheme t;
  final bool onDark;

  static final _mentionPattern = RegExp(r'@[\wçğıöşüÇĞİÖŞÜ]+');

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 15,
      height: 1.52,
      letterSpacing: -0.15,
      color: onDark ? Colors.white : t.textSoft,
    );
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in _mentionPattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: onDark ? Colors.white.withValues(alpha: 0.18) : t.ltRed,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              match.group(0)!,
              style: base.copyWith(
                fontWeight: FontWeight.w800,
                color: onDark ? Colors.white : t.red,
              ),
            ),
          ),
        ),
      );
      index = match.end;
    }
    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

/// Attachment row for a non-image file.
class ClubFileChip extends StatelessWidget {
  const ClubFileChip({
    super.key,
    required this.message,
    required this.t,
    required this.onOpen,
  });

  final ChatMessage message;
  final ClubChatTheme t;
  final VoidCallback onOpen;

  static String formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final name = message.attachmentName ?? '';
    final extension = name.contains('.')
        ? name.split('.').last.toUpperCase()
        : S.attachFile.toUpperCase();
    final size = formatSize(message.attachmentSize);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 13, 10),
          decoration: BoxDecoration(
            color: t.solid,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: t.ltRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 17,
                  color: t.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      [extension, if (size.isNotEmpty) size].join(' · '),
                      style: TextStyle(fontSize: 11, color: t.sub),
                    ),
                  ],
                ),
              ),
              Icon(Icons.file_download_outlined, size: 17, color: t.sub),
            ],
          ),
        ),
      ),
    );
  }
}

/// Emoji reaction pills plus the "add a reaction" affordance.
class ClubReactionsRow extends StatelessWidget {
  const ClubReactionsRow({
    super.key,
    required this.message,
    required this.myId,
    required this.t,
    required this.onToggle,
    required this.onPick,
  });

  final ChatMessage message;
  final String myId;
  final ClubChatTheme t;
  final void Function(String emoji) onToggle;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final entries = message.reactions.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final entry in entries)
            GestureDetector(
              onTap: () => onToggle(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: entry.value.contains(myId) ? t.ltRed : t.solid,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: entry.value.contains(myId) ? t.red : t.border,
                  ),
                ),
                child: Text(
                  '${entry.key} ${entry.value.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.textMuted,
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 26,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.borderB, style: BorderStyle.solid),
              ),
              child: Icon(
                Icons.add_reaction_outlined,
                size: 13,
                color: t.sub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Officer broadcast card. [ClubAnnouncementEmphasis] switches between the
/// design's subtle / tinted / bold treatments.
class ClubAnnouncementCard extends StatelessWidget {
  const ClubAnnouncementCard({
    super.key,
    required this.message,
    required this.author,
    required this.avatar,
    required this.t,
    required this.emphasis,
    required this.showRoles,
    required this.seenCount,
    required this.timeLabel,
    required this.onLongPress,
    this.reactions,
  });

  final ChatMessage message;
  final ClubPerson author;
  final Widget avatar;
  final ClubChatTheme t;
  final ClubAnnouncementEmphasis emphasis;
  final bool showRoles;
  final int seenCount;
  final String timeLabel;
  final VoidCallback onLongPress;
  final Widget? reactions;

  @override
  Widget build(BuildContext context) {
    final bold = emphasis == ClubAnnouncementEmphasis.bold;
    final subtle = emphasis == ClubAnnouncementEmphasis.subtle;
    final foreground = bold ? Colors.white : t.text;
    final soft = bold ? Colors.white.withValues(alpha: 0.82) : t.textMuted;
    final label = bold ? Colors.white.withValues(alpha: 0.85) : t.red;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          key: ValueKey('club-announcement-${message.id}'),
          decoration: BoxDecoration(
            color: bold ? null : (subtle ? t.card : t.ltRed),
            gradient: bold ? t.announceGradient : null,
            borderRadius: BorderRadius.circular(16),
            border: bold
                ? null
                : Border(
                    left: BorderSide(
                      color: subtle ? t.red : t.accent.withValues(alpha: 0.2),
                      width: subtle ? 3 : 1,
                    ),
                    top: BorderSide(
                      color: subtle
                          ? t.border
                          : t.accent.withValues(alpha: 0.2),
                    ),
                    right: BorderSide(
                      color: subtle
                          ? t.border
                          : t.accent.withValues(alpha: 0.2),
                    ),
                    bottom: BorderSide(
                      color: subtle
                          ? t.border
                          : t.accent.withValues(alpha: 0.2),
                    ),
                  ),
            boxShadow: bold
                ? [
                    BoxShadow(
                      color: t.accent.withValues(alpha: t.isDark ? 0.3 : 0.26),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign_outlined, size: 14, color: label),
                  const SizedBox(width: 7),
                  Text(
                    S.announcementLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                      color: label,
                    ),
                  ),
                  if (message.pinned) ...[
                    const Spacer(),
                    Icon(Icons.push_pin_outlined, size: 11, color: label),
                    const SizedBox(width: 3),
                    Text(
                      S.pinnedLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: label,
                      ),
                    ),
                  ],
                ],
              ),
              if ((message.title ?? '').isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  message.title!,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: foreground,
                  ),
                ),
              ],
              if (message.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message.content,
                  style: TextStyle(fontSize: 14.5, height: 1.5, color: soft),
                ),
              ],
              ?reactions,
              const SizedBox(height: 13),
              Container(
                padding: const EdgeInsets.only(top: 11),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: bold
                          ? Colors.white.withValues(alpha: 0.22)
                          : t.hair,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    avatar,
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: bold ? Colors.white : t.textSoft,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ClubRoleChip(
                      person: author,
                      t: t,
                      show: showRoles,
                      onBoldSurface: bold,
                    ),
                    const Spacer(),
                    Text(
                      '${S.seenCount(seenCount)} · $timeLabel',
                      style: TextStyle(fontSize: 11, color: soft),
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

/// In-stream poll with live percentages.
class ClubPollMessageCard extends StatelessWidget {
  const ClubPollMessageCard({
    super.key,
    required this.message,
    required this.author,
    required this.avatar,
    required this.t,
    required this.myId,
    required this.showRoles,
    required this.closesLabel,
    required this.onVote,
    required this.onLongPress,
  });

  final ChatMessage message;
  final ClubPerson author;
  final Widget avatar;
  final ClubChatTheme t;
  final String myId;
  final bool showRoles;
  final String closesLabel;
  final void Function(int optionIndex) onVote;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final myVote = message.pollVotes[myId];
    final total = message.totalPollVotes;
    final counts = [
      for (var i = 0; i < message.pollOptions.length; i++)
        message.votesForOption(i),
    ];
    final leader = counts.isEmpty
        ? 0
        : counts.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          key: ValueKey('club-poll-${message.id}'),
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 15, color: t.red),
                  const SizedBox(width: 7),
                  Text(
                    S.pollLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                      color: t.red,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    closesLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: t.sub,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                message.title ?? message.content,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 11),
              for (var i = 0; i < message.pollOptions.length; i++) ...[
                if (i > 0) const SizedBox(height: 7),
                _PollOption(
                  label: message.pollOptions[i],
                  percent: total == 0 ? 0 : (counts[i] / total * 100).round(),
                  picked: myVote == i,
                  leading: counts[i] == leader && leader > 0,
                  enabled: !message.pollIsClosed,
                  t: t,
                  onTap: () => onVote(i),
                ),
              ],
              const SizedBox(height: 11),
              Row(
                children: [
                  avatar,
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: t.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ClubRoleChip(person: author, t: t, show: showRoles),
                  const Spacer(),
                  Text(
                    myVote == null
                        ? S.pollVotes(total)
                        : '${S.pollVotes(total)} · ${S.pollVoted}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: t.sub,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.label,
    required this.percent,
    required this.picked,
    required this.leading,
    required this.enabled,
    required this.t,
    required this.onTap,
  });

  final String label;
  final int percent;
  final bool picked;
  final bool leading;
  final bool enabled;
  final ClubChatTheme t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: t.isDark ? Colors.white.withValues(alpha: 0.03) : t.body,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: picked ? t.red : t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (percent / 100).clamp(0.0, 1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  color: picked
                      ? t.ltRed
                      : (leading
                            ? t.accent.withValues(
                                alpha: t.isDark ? 0.1 : 0.055,
                              )
                            : t.solid),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: picked ? t.red : Colors.transparent,
                      border: Border.all(
                        color: picked ? t.red : t.borderB,
                        width: 1.6,
                      ),
                    ),
                    child: picked
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: picked
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: picked ? t.red : t.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Event card with an inline RSVP toggle. Used both in the stream and,
/// with [compact], inside the Events sheet.
class ClubEventCard extends StatelessWidget {
  const ClubEventCard({
    super.key,
    required this.title,
    required this.dayLabel,
    required this.dateLabel,
    required this.clockLabel,
    required this.place,
    required this.goingCount,
    required this.going,
    required this.t,
    required this.onToggleRsvp,
    required this.onOpen,
    this.compact = false,
  });

  final String title;
  final String dayLabel;
  final String dateLabel;
  final String clockLabel;
  final String place;
  final int goingCount;
  final bool going;
  final ClubChatTheme t;
  final VoidCallback onToggleRsvp;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: compact ? 0 : 12),
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: going ? t.red : t.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: t.ltRed,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  children: [
                    Text(
                      dayLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: t.red,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: t.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [clockLabel, place].where((v) => v.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: t.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.goingCount(goingCount),
                      style: TextStyle(fontSize: 11, color: t.sub),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onToggleRsvp,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: going ? t.meGradient : null,
                    borderRadius: BorderRadius.circular(999),
                    border: going
                        ? null
                        : Border.all(color: t.borderB, width: 1.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (going) ...[
                        const Icon(Icons.check, size: 12, color: Colors.white),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        going ? S.going : S.rsvp,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: going ? Colors.white : t.text,
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
    );
  }
}

/// A message (or the first message of a same-sender run) in the stream.
///
/// [ClubMessageStyle] switches between the design's three chat-area layouts:
/// `rows` (avatar spine + wide text), `bubbles`, and `cards`.
class ClubMessageGroup extends StatelessWidget {
  const ClubMessageGroup({
    super.key,
    required this.message,
    required this.sender,
    required this.avatar,
    required this.mine,
    required this.head,
    required this.style,
    required this.showRoles,
    required this.timeLabel,
    required this.flagged,
    required this.t,
    required this.onLongPress,
    this.statusLabel,
    this.attachments = const [],
    this.reactions,
  });

  final ChatMessage message;
  final ClubPerson sender;
  final Widget avatar;
  final bool mine;

  /// First message of a same-sender run — shows the avatar and name row.
  final bool head;
  final ClubMessageStyle style;
  final bool showRoles;
  final String timeLabel;

  /// The reader was mentioned — the design outlines/tints these.
  final bool flagged;
  final ClubChatTheme t;
  final VoidCallback onLongPress;
  final String? statusLabel;
  final List<Widget> attachments;
  final Widget? reactions;

  Widget _body({required bool onDark}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (message.content.isNotEmpty)
        ClubMessageText(text: message.content, t: t, onDark: onDark),
      ...attachments,
      ?reactions,
    ],
  );

  Widget _nameRow() => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        Flexible(
          child: Text(
            sender.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              color: mine ? t.red : t.text,
            ),
          ),
        ),
        const SizedBox(width: 6),
        ClubRoleChip(person: sender, t: t, show: showRoles),
        const SizedBox(width: 6),
        Text(
          timeLabel,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: t.sub,
          ),
        ),
        if (mine && statusLabel != null) ...[
          const SizedBox(width: 5),
          _Ticks(seen: statusLabel == S.seen, t: t),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: switch (style) {
        ClubMessageStyle.bubbles => _buildBubbles(context),
        ClubMessageStyle.cards => _buildCard(context),
        ClubMessageStyle.rows => _buildRow(context),
      },
    );
  }

  // ── rows (default) ─────────────────────────────────────────────────────────
  Widget _buildRow(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: head
              ? Center(child: avatar)
              : Center(
                  child: Container(width: 1, height: 18, color: t.hair),
                ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [if (head) _nameRow(), _body(onDark: false)],
          ),
        ),
      ],
    );
    if (!flagged) {
      return Padding(
        padding: EdgeInsets.only(top: head ? 12 : 3),
        child: content,
      );
    }
    return Container(
      margin: EdgeInsets.fromLTRB(-6, head ? 12 : 3, -6, 0),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: t.ltRed,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: t.red, width: 2.5)),
      ),
      child: content,
    );
  }

  // ── bubbles ────────────────────────────────────────────────────────────────
  Widget _buildBubbles(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: head ? 10 : 3),
      child: Row(
        textDirection: mine ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 30, child: head && !mine ? avatar : null),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (head && !mine)
                  Padding(
                    padding: const EdgeInsets.only(left: 3, bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            sender.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: t.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        ClubRoleChip(person: sender, t: t, show: showRoles),
                      ],
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: mine ? null : t.card,
                    gradient: mine ? t.meGradient : null,
                    border: mine
                        ? null
                        : Border.all(color: flagged ? t.red : t.border),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 6),
                      bottomRight: Radius.circular(mine ? 6 : 18),
                    ),
                  ),
                  child: _body(onDark: mine),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 3, right: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: t.sub,
                        ),
                      ),
                      if (mine && statusLabel != null) ...[
                        const SizedBox(width: 5),
                        _Ticks(seen: statusLabel == S.seen, t: t),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── cards ──────────────────────────────────────────────────────────────────
  Widget _buildCard(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: head ? 10 : 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: mine ? t.red : t.accent, width: 3),
            top: BorderSide(color: flagged ? t.red : t.border),
            right: BorderSide(color: flagged ? t.red : t.border),
            bottom: BorderSide(color: flagged ? t.red : t.border),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar,
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_nameRow(), _body(onDark: false)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delivered / seen double check.
class _Ticks extends StatelessWidget {
  const _Ticks({required this.seen, required this.t});

  final bool seen;
  final ClubChatTheme t;

  @override
  Widget build(BuildContext context) {
    return Icon(
      seen ? Icons.done_all_rounded : Icons.check_rounded,
      size: 13,
      color: seen ? t.red : t.sub,
    );
  }
}

/// Animated "… is typing" row.
class ClubTypingRow extends StatefulWidget {
  const ClubTypingRow({
    super.key,
    required this.avatars,
    required this.label,
    required this.t,
  });

  final List<Widget> avatars;
  final String label;
  final ClubChatTheme t;

  @override
  State<ClubTypingRow> createState() => _ClubTypingRowState();
}

class _ClubTypingRowState extends State<ClubTypingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Row(
        key: const ValueKey('club-typing-row'),
        children: [
          SizedBox(
            width: 30,
            height: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < widget.avatars.length && i < 2; i++)
                  Positioned(left: i * 9 - 4, child: widget.avatars[i]),
              ],
            ),
          ),
          const SizedBox(width: 11),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Transform.translate(
                    offset: Offset(0, _dotOffset(i)),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.red.withValues(alpha: _dotAlpha(i)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: t.sub,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _phase(int index) => (_controller.value - index * 0.18) % 1.0;

  double _dotOffset(int index) {
    final phase = _phase(index);
    if (phase >= 0.6) return 0;
    // 0 → -4 → 0 over the first 60% of the cycle, matching the design's
    // `mDot` keyframes.
    final t = phase / 0.6;
    return -4 * (1 - (2 * t - 1).abs());
  }

  double _dotAlpha(int index) {
    final phase = _phase(index);
    if (phase >= 0.6) return 0.45;
    final t = phase / 0.6;
    return 0.45 + 0.55 * (1 - (2 * t - 1).abs());
  }
}

/// Inline photo attachment.
class ClubPhotoAttachment extends StatelessWidget {
  const ClubPhotoAttachment({
    super.key,
    required this.path,
    required this.t,
  });

  final String path;
  final ClubChatTheme t;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: GestureDetector(
        onTap: file.existsSync()
            ? () => showDialog<void>(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.92),
                builder: (dialogContext) => GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Center(child: Image.file(file, fit: BoxFit.contain)),
                  ),
                ),
              )
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 240),
            width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: t.border)),
            child: file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : Container(
                    height: 140,
                    alignment: Alignment.center,
                    color: t.solid,
                    child: Icon(
                      Icons.image_outlined,
                      color: t.sub,
                      size: 22,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
