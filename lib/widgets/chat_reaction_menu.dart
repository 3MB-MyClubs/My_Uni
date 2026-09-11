import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/theme_service.dart';
import 'chats_design.dart';
import 'clubup_design.dart';

/// The long-press reaction menu for a chat message.
///
/// This replaces the bottom sheet the thread used to raise for reactions. A
/// sheet slides the whole conversation out of view for what is a *pointed*
/// gesture — the reader is aiming at one bubble — so the emoji row now floats
/// beside that bubble the way WhatsApp's does: the page dims except for the
/// message itself, an emoji pill springs out of the bubble's near corner with
/// the faces popping in one after another, and the actions arrive under it.
///
/// The undimmed message is not a copy of the bubble. The scrim is painted with
/// a rounded hole over the bubble's own rect ([_ScrimPainter]), so the real
/// bubble — photo, reply quote, tail and all — shows through untouched and
/// stays exactly where the reader left it.

/// Tap target per face, and the pill that holds them.
const double _emojiSlot = 44;
const double _pillPadH = 7;
const double _pillPadV = 6;
const double _pillHeight = _emojiSlot + _pillPadV * 2;

/// Breathing room between the bubble, the pill and the action card, and the
/// margin the whole thing keeps from the screen edges.
const double _gap = 10;
const double _edge = 12;

const double _menuWidth = 214;
const double _menuRowHeight = 46;

/// How long the tapped face lingers, grown, before the menu leaves. Short
/// enough that it reads as one motion with the chip landing on the bubble.
const Duration _confirmLinger = Duration(milliseconds: 120);

/// Opens the reaction menu over [anchor] — the pressed bubble's rect in global
/// coordinates.
///
/// [alignEnd] pins the pill and the action card to the bubble's trailing edge,
/// so an outgoing message's menu hangs off the right the way the bubble does.
Future<void> showChatReactionMenu(
  BuildContext context, {
  required Rect anchor,
  required bool alignEnd,
  required List<String> emojis,
  required Set<String> selected,
  required ValueChanged<String> onEmoji,
  required List<ChatsMenuAction> actions,
  double anchorRadius = kChatBubbleRadius,
  Key? pillKey,
}) {
  HapticFeedback.selectionClick();
  return Navigator.of(context, rootNavigator: true).push(
    _ReactionMenuRoute(
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (routeContext, animation) => _ChatReactionMenu(
        animation: animation,
        anchor: anchor,
        anchorRadius: anchorRadius,
        alignEnd: alignEnd,
        emojis: emojis,
        selected: selected,
        onEmoji: onEmoji,
        actions: actions,
        pillKey: pillKey,
      ),
    ),
  );
}

/// A transparent-barrier popup: the dim is painted by the page itself, and
/// leaving is deliberately quicker than arriving.
class _ReactionMenuRoute extends PopupRoute<void> {
  _ReactionMenuRoute({required this.pageBuilder, required this.barrierLabel});

  final Widget Function(BuildContext, Animation<double>) pageBuilder;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 170);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => pageBuilder(context, animation);
}

class _ChatReactionMenu extends StatelessWidget {
  const _ChatReactionMenu({
    required this.animation,
    required this.anchor,
    required this.anchorRadius,
    required this.alignEnd,
    required this.emojis,
    required this.selected,
    required this.onEmoji,
    required this.actions,
    required this.pillKey,
  });

  final Animation<double> animation;
  final Rect anchor;
  final double anchorRadius;
  final bool alignEnd;
  final List<String> emojis;
  final Set<String> selected;
  final ValueChanged<String> onEmoji;
  final List<ChatsMenuAction> actions;
  final Key? pillKey;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final top = media.padding.top + 8;
    final bottom = size.height - media.padding.bottom - 8;

    // A bubble taller than the viewport (a full-bleed photo) would push the
    // pill off-screen if we anchored to its true edges.
    final target = Rect.fromLTRB(
      anchor.left,
      math.max(anchor.top, top),
      anchor.right,
      math.min(anchor.bottom, bottom),
    );

    final pillWidth = math.min(
      emojis.length * _emojiSlot + _pillPadH * 2,
      size.width - _edge * 2,
    );
    final menuHeight =
        actions.length * _menuRowHeight +
        12 +
        actions.where((a) => a.dividerAbove).length;

    // Above the bubble when it fits — that is where the thumb already is —
    // otherwise under it, for a message pinned to the top of the thread.
    final pillAbove = target.top - _gap - _pillHeight >= top;
    final pillTop = pillAbove
        ? target.top - _gap - _pillHeight
        : target.bottom + _gap;

    // The actions go on the bubble's far side from the pill, and fall back to
    // the pill's own side when there is no room there.
    double menuTop;
    if (pillAbove) {
      menuTop = target.bottom + _gap;
      if (menuTop + menuHeight > bottom) {
        menuTop = math.max(top, pillTop - _gap - menuHeight);
      }
    } else {
      menuTop = pillTop + _pillHeight + _gap;
      if (menuTop + menuHeight > bottom) {
        menuTop = math.max(top, target.top - _gap - menuHeight);
      }
    }
    final menuMaxHeight = math.max(_menuRowHeight, bottom - menuTop);

    double clampX(double left, double width) =>
        left.clamp(_edge, math.max(_edge, size.width - _edge - width));

    final pillLeft = clampX(
      alignEnd ? target.right - pillWidth : target.left,
      pillWidth,
    );
    final menuLeft = clampX(
      alignEnd ? target.right - _menuWidth : target.left,
      _menuWidth,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Material(
          // The dialog route is outside the page's own `Material`, and a bare
          // `Text` there picks up the framework's yellow debug underline.
          type: MaterialType.transparency,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ScrimPainter(
                        hole: target,
                        radius: anchorRadius,
                        color: ChatsColors.scrim.withValues(
                          alpha:
                              ChatsColors.scrim.a *
                              Curves.easeOut.transform(t.clamp(0.0, 1.0)),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: pillLeft,
                  top: pillTop,
                  width: pillWidth,
                  height: _pillHeight,
                  child: _scaleIn(
                    t: t,
                    start: 0,
                    end: 0.68,
                    from: 0.7,
                    // Out of the corner the bubble sits in.
                    alignment: Alignment(
                      alignEnd ? 0.8 : -0.8,
                      pillAbove ? 1 : -1,
                    ),
                    child: _EmojiPill(
                      pillKey: pillKey,
                      emojis: emojis,
                      selected: selected,
                      progress: t,
                      onEmoji: onEmoji,
                    ),
                  ),
                ),
                if (actions.isNotEmpty)
                  Positioned(
                    left: menuLeft,
                    top: menuTop,
                    width: _menuWidth,
                    child: _scaleIn(
                      t: t,
                      start: 0.08,
                      end: 0.75,
                      from: 0.92,
                      alignment: Alignment(alignEnd ? 0.8 : -0.8, -1),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: menuMaxHeight),
                        child: _ActionCard(actions: actions),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scaleIn({
    required double t,
    required double start,
    required double end,
    required double from,
    required Alignment alignment,
    required Widget child,
  }) {
    final p = _interval(t, start, end, Curves.easeOutBack);
    return Opacity(
      opacity: _interval(t, start, start + (end - start) * 0.5, Curves.easeOut),
      child: Transform.scale(
        scale: from + (1 - from) * p,
        alignment: alignment,
        child: child,
      ),
    );
  }
}

/// [curve] applied to the slice of `[start, end]` that [t] has covered.
double _interval(double t, double start, double end, Curve curve) {
  if (end <= start) return curve.transform(t.clamp(0.0, 1.0));
  return curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
}

/// The floating row of faces.
class _EmojiPill extends StatelessWidget {
  const _EmojiPill({
    required this.pillKey,
    required this.emojis,
    required this.selected,
    required this.progress,
    required this.onEmoji,
  });

  final Key? pillKey;
  final List<String> emojis;
  final Set<String> selected;
  final double progress;
  final ValueChanged<String> onEmoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: pillKey,
      padding: const EdgeInsets.symmetric(
        horizontal: _pillPadH,
        vertical: _pillPadV,
      ),
      decoration: BoxDecoration(
        color: ChatsColors.card,
        borderRadius: BorderRadius.circular(999),
        boxShadow: _floatShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < emojis.length; i++)
            _EmojiButton(
              key: ValueKey('chat-reaction-option-${emojis[i]}'),
              emoji: emojis[i],
              mine: selected.contains(emojis[i]),
              // Left to right, one after the next, rather than the whole row
              // arriving as a block.
              entrance: _interval(
                progress,
                0.10 + i * 0.05,
                0.55 + i * 0.05,
                Curves.easeOutBack,
              ),
              onTap: () => onEmoji(emojis[i]),
            ),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatefulWidget {
  const _EmojiButton({
    super.key,
    required this.emoji,
    required this.mine,
    required this.entrance,
    required this.onTap,
  });

  final String emoji;
  final bool mine;
  final double entrance;
  final VoidCallback onTap;

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton> {
  bool _chosen = false;

  Future<void> _handleTap() async {
    if (_chosen) return;
    setState(() => _chosen = true);
    HapticFeedback.selectionClick();
    // Grow the face where the reader tapped it, then let the menu go: the
    // reaction reaching the bubble is the second half of the same beat.
    await Future<void>.delayed(_confirmLinger);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: SizedBox(
        width: _emojiSlot,
        height: _emojiSlot,
        child: Transform.scale(
          scale: widget.entrance,
          child: AnimatedScale(
            scale: _chosen ? 1.32 : 1,
            duration: _confirmLinger,
            curve: Curves.easeOutBack,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // The face you already left keeps a plain wash behind it.
                // There is deliberately no accent ring here — a burgundy
                // circle around an emoji reads as an error state.
                color: widget.mine ? ChatsColors.fill : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(widget.emoji, style: const TextStyle(fontSize: 25)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reply / Copy / Delete, in the same vocabulary as [showChatsMenuSheet]'s
/// rows but sized for a card that floats beside the bubble.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.actions});

  final List<ChatsMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kChatCardRadius + 2),
        boxShadow: _floatShadow,
      ),
      // A `Material`, not a coloured `Container`: the rows are `InkWell`s, and
      // a decoration between them and their material would swallow the ripple.
      child: Material(
        color: ChatsColors.card,
        borderRadius: BorderRadius.circular(kChatCardRadius + 2),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in actions) ...[
                if (action.dividerAbove)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: const ChatsCardDivider(),
                  ),
                _ActionRow(action: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final ChatsMenuAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.destructive
        ? ChatsColors.danger
        : ChatsColors.accentText;
    return InkWell(
      key: action.rowKey,
      onTap: () {
        Navigator.of(context).pop();
        action.onTap();
      },
      child: SizedBox(
        height: _menuRowHeight,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(action.icon, size: 19, color: color),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 14,
                  weight: FontWeight.w600,
                  color: action.destructive
                      ? ChatsColors.danger
                      : ChatsColors.text,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

List<BoxShadow> get _floatShadow => [
  BoxShadow(
    color: Colors.black.withValues(alpha: themeService.isDark ? 0.55 : 0.16),
    offset: const Offset(0, 6),
    blurRadius: 22,
  ),
];

/// A full-screen dim with the pressed bubble punched out of it, so the message
/// the reader is aiming at stays lit while everything else recedes.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({
    required this.hole,
    required this.radius,
    required this.color,
  });

  final Rect hole;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;
    final full = Offset.zero & size;
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, Paint()..color = color);
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole.inflate(3), Radius.circular(radius + 3)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.color != color || old.hole != hole || old.radius != radius;
}

/// One-shot pop for a reaction chip as it lands on a bubble.
///
/// [animate] is false for a chip that was already there when the row was first
/// built, so opening a thread full of reactions does not set every chip
/// bouncing — the pop belongs to a reaction *arriving*.
class ChatReactionPop extends StatefulWidget {
  const ChatReactionPop({
    super.key,
    required this.animate,
    required this.child,
  });

  final bool animate;
  final Widget child;

  @override
  State<ChatReactionPop> createState() => _ChatReactionPopState();
}

class _ChatReactionPopState extends State<ChatReactionPop>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  CurvedAnimation? _pop;

  @override
  void initState() {
    super.initState();
    // Read once: a rebuild that no longer calls this chip new must not cut the
    // pop short half way through.
    if (!widget.animate) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _controller = controller;
    _pop = CurvedAnimation(parent: controller, curve: Curves.easeOutBack);
    controller.forward();
  }

  @override
  void dispose() {
    _pop?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    return FadeTransition(
      opacity: controller,
      child: ScaleTransition(scale: _pop!, child: widget.child),
    );
  }
}
