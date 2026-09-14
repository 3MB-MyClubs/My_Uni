import 'package:flutter/material.dart';

import 'chat_reaction_menu.dart';

/// How a [ChatReactionStrip] paints.
///
/// The strip is shared by the student thread's design bubbles, the legacy
/// bubbles and the club chat bubbles, and each of those areas owns its own
/// palette — so the colours arrive from the call site instead of the strip
/// reaching for one area's tokens and imposing them on the others.
@immutable
class ChatReactionStyle {
  const ChatReactionStyle({
    required this.mineFill,
    required this.otherFill,
    required this.border,
    required this.label,
    this.mineBorder,
    this.chipPadding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    this.chipHeight,
  }) : bare = false;

  /// A strip with nothing behind the faces: the emoji on its own, tucked under
  /// the bubble as a quiet indicator. Fills and frames mean nothing once the
  /// pill is gone, so this constructor does not ask for them.
  const ChatReactionStyle.bare({
    required this.label,
    this.chipPadding = const EdgeInsets.symmetric(horizontal: 2),
  }) : bare = true,
       mineFill = const Color(0x00000000),
       otherFill = const Color(0x00000000),
       border = const Color(0x00000000),
       mineBorder = null,
       chipHeight = null;

  /// Fill of a chip — or of a stacked face — you are part of, and of one you
  /// are not.
  final Color mineFill;
  final Color otherFill;

  /// Hairline around somebody else's chip, and around every stacked face:
  /// without it the overlapping circles run together into one blob.
  final Color border;

  /// Frame around your own chip. Null leaves it borderless, which is what the
  /// student thread wants — a ring around an emoji reads as a warning.
  final Color? mineBorder;

  final TextStyle label;
  final EdgeInsets chipPadding;

  /// Drop the pill and paint the emoji straight onto whatever is behind it.
  final bool bare;

  /// Fixed chip height, for the club bubbles that pin theirs to 22.
  final double? chipHeight;
}

/// The reaction chips under a chat bubble.
///
/// One person holds one face per message (see `ChatStore.toggleReaction`), so a
/// chip count is a headcount. Up to [maxVisible] distinct faces sit side by
/// side; past that the row collapses into overlapping circles plus the total,
/// so a busy group message cannot push a wall of chips across the thread.
/// Tapping the stack opens it, and the trailing button folds it back.
class ChatReactionStrip extends StatefulWidget {
  const ChatReactionStrip({
    super.key,
    required this.messageId,
    required this.reactions,
    required this.myId,
    required this.style,
    required this.onToggle,
    this.newEmojis = const <String>{},
    this.alignEnd = false,
    this.keyPrefix = 'chat-reaction',
    this.maxVisible = 3,
  });

  final String messageId;

  /// emoji → the user ids holding it, straight off the message.
  final Map<String, List<String>> reactions;
  final String myId;
  final ChatReactionStyle style;
  final ValueChanged<String> onToggle;

  /// Faces that were not on this message the last time the row was drawn, so
  /// only an *arriving* reaction pops.
  final Set<String> newEmojis;

  /// Outgoing bubbles hang their chips off the right edge.
  final bool alignEnd;

  /// Prefix of the per-chip widget keys: `<prefix>-<messageId>-<emoji>`.
  final String keyPrefix;

  /// How many distinct faces stay side by side before the row stacks.
  final int maxVisible;

  @override
  State<ChatReactionStrip> createState() => _ChatReactionStripState();
}

class _ChatReactionStripState extends State<ChatReactionStrip> {
  static const double _faceSize = 24;

  /// A bare face carries no circle, so it needs no room for one.
  static const double _bareFaceSize = 18;
  static const double _faceOverlap = 7;

  /// Whether the reader has opened a stacked row. Held here rather than in the
  /// screen so every bubble keeps its own answer, and it survives the rebuild
  /// that each new reaction triggers.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final faces =
        widget.reactions.entries
            .map((entry) => _Face(entry.key, entry.value))
            .toList()
          ..sort((a, b) {
            final byCount = b.users.length.compareTo(a.users.length);
            // Equal counts fall back to the emoji itself: a bare count sort is not
            // stable, and the stack would reshuffle its faces on every rebuild.
            return byCount != 0 ? byCount : a.emoji.compareTo(b.emoji);
          });
    if (faces.isEmpty) return const SizedBox.shrink();

    if (faces.length > widget.maxVisible && !_expanded) return _stack(faces);

    return Wrap(
      spacing: 5,
      runSpacing: 4,
      alignment: widget.alignEnd ? WrapAlignment.end : WrapAlignment.start,
      children: [
        for (final face in faces) _chip(face),
        if (faces.length > widget.maxVisible) _collapseButton(),
      ],
    );
  }

  Widget _chip(_Face face) => ChatReactionPop(
    key: ValueKey('${widget.keyPrefix}-${widget.messageId}-${face.emoji}'),
    animate: widget.newEmojis.contains(face.emoji),
    child: GestureDetector(
      onTap: () => widget.onToggle(face.emoji),
      // A bare face is a small target with no fill to catch the tap, so the
      // padding around it has to answer for the whole box.
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: widget.style.chipHeight,
        padding: widget.style.chipPadding,
        decoration: widget.style.bare
            ? null
            : _pill(mine: face.mine(widget.myId)),
        // Align with both factors, not Container.alignment: a bare Align
        // expands to the Wrap's loose width.
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            face.users.length > 1
                ? '${face.emoji} ${face.users.length}'
                : face.emoji,
            style: widget.style.label,
          ),
        ),
      ),
    ),
  );

  /// The collapsed row: the leading faces overlapping like stacked avatars,
  /// then how many people reacted in all.
  Widget _stack(List<_Face> faces) {
    final shown = faces.take(widget.maxVisible).toList();
    // Overlapping circles need the tuck to read as a stack; bare faces have no
    // edge to overlap, so they simply sit side by side.
    final step = widget.style.bare ? _bareFaceSize : _faceSize - _faceOverlap;
    final total = faces.fold<int>(0, (sum, face) => sum + face.users.length);
    return ChatReactionPop(
      // Keyed by the faces it holds, so a reaction landing on an already
      // stacked row still gets its pop.
      key: ValueKey(
        '${widget.keyPrefix}-stack-${widget.messageId}-'
        '${faces.map((face) => face.emoji).join()}',
      ),
      animate: widget.newEmojis.isNotEmpty,
      child: GestureDetector(
        key: ValueKey('${widget.keyPrefix}-stack-${widget.messageId}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _expanded = true),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _faceExtent + step * (shown.length - 1),
              height: _faceExtent,
              child: Stack(
                children: [
                  // Back to front, so the busiest face is the one on top.
                  for (var i = shown.length - 1; i >= 0; i--)
                    Positioned(left: i * step, top: 0, child: _face(shown[i])),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Text('$total', style: widget.style.label),
            ),
          ],
        ),
      ),
    );
  }

  double get _faceExtent => widget.style.bare ? _bareFaceSize : _faceSize;

  Widget _face(_Face face) {
    final mine = face.mine(widget.myId);
    if (widget.style.bare) {
      return SizedBox(
        width: _bareFaceSize,
        height: _bareFaceSize,
        child: Center(
          child: Text(
            face.emoji,
            style: widget.style.label.copyWith(height: 1),
          ),
        ),
      );
    }
    return Container(
      width: _faceSize,
      height: _faceSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Flattened against the chip fill: your own wash is translucent, and
        // overlapping circles would otherwise show each other through.
        color: mine
            ? Color.alphaBlend(widget.style.mineFill, widget.style.otherFill)
            : widget.style.otherFill,
        border: Border.all(
          color: widget.style.mineBorder ?? widget.style.border,
        ),
      ),
      child: Text(
        face.emoji,
        style: widget.style.label.copyWith(fontSize: 13, height: 1),
      ),
    );
  }

  Widget _collapseButton() => GestureDetector(
    key: ValueKey('${widget.keyPrefix}-collapse-${widget.messageId}'),
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => _expanded = false),
    child: Container(
      height: widget.style.chipHeight,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: widget.style.bare ? null : _pill(mine: false),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Icon(
          Icons.unfold_less,
          size: 13,
          color: widget.style.label.color,
        ),
      ),
    ),
  );

  BoxDecoration _pill({required bool mine}) {
    final style = widget.style;
    final border = mine ? style.mineBorder : style.border;
    return BoxDecoration(
      color: mine ? style.mineFill : style.otherFill,
      borderRadius: BorderRadius.circular(999),
      border: border == null ? null : Border.all(color: border),
    );
  }
}

@immutable
class _Face {
  const _Face(this.emoji, this.users);

  final String emoji;
  final List<String> users;

  bool mine(String myId) => users.contains(myId);
}
