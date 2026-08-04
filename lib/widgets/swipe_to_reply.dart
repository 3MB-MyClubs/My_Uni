import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_colors.dart';

/// Drag a message bubble to the right to reply to it — the WhatsApp/Instagram
/// gesture. The bubble follows your finger, a reply arrow slides in from the
/// left, and passing [_threshold] arms the action: a haptic tick fires the
/// moment it arms, then releasing calls [onReply] and the bubble springs back.
///
/// Pulling further than the threshold is damped rather than blocked, so the
/// gesture still feels alive at the end of its travel. Dragging back under the
/// threshold disarms it, which is how you bail out mid-swipe.
///
/// Horizontal-only: the enclosing list keeps every vertical drag, so scrolling
/// through a thread never trips a reply.
class SwipeToReply extends StatefulWidget {
  final Widget child;

  /// Fired once, on release, when the swipe passed the arming threshold.
  final VoidCallback onReply;

  /// False for read-only threads — matches the long-press menu, which only
  /// offers Reply where the viewer can actually write.
  final bool enabled;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  /// Travel needed to arm the reply.
  static const double _threshold = 46;

  /// Hard stop on how far the bubble can move.
  static const double _maxDrag = 74;

  /// Movement past the threshold is scaled by this — the rubber-band feel.
  static const double _overdragDamping = 0.32;

  late final AnimationController _springBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  double _dx = 0;

  /// Offset the bubble sat at when the release began, so the spring-back
  /// animates from wherever the finger actually left off.
  double _releasedFrom = 0;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _springBack.addListener(() {
      final eased = Curves.easeOutCubic.transform(_springBack.value);
      setState(() => _dx = _releasedFrom * (1 - eased));
    });
  }

  @override
  void dispose() {
    _springBack.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    var next = _dx + delta;
    if (next < 0) {
      // Left of rest is dead travel — this gesture only goes one way.
      next = 0;
    } else if (next > _threshold) {
      next = _threshold + (next - _threshold) * _overdragDamping;
      if (next > _maxDrag) next = _maxDrag;
    }

    final armed = next >= _threshold;
    if (armed != _armed) {
      // Tick on the way in and on the way back out, so bailing out is felt too.
      HapticFeedback.selectionClick();
    }
    setState(() {
      _dx = next;
      _armed = armed;
    });
  }

  void _onDragEnd() {
    final fire = _armed;
    _armed = false;
    if (_dx == 0) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _dx = 0);
    } else {
      _releasedFrom = _dx;
      _springBack.forward(from: 0);
    }
    // After the snap starts, so the composer's reply preview and the bubble
    // settling back read as one motion rather than competing.
    if (fire) widget.onReply();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final progress = (_dx / _threshold).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: (_) => _onDragEnd(),
      onHorizontalDragCancel: _onDragEnd,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Trails the bubble in from the left margin. Sized off the bubble by
          // the Stack, so it lines up with whatever row it's dropped into.
          Positioned(
            left: -34 + _dx * 0.86,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  // Settles at full size exactly as the reply arms.
                  scale: 0.62 + 0.38 * progress,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _armed
                          ? AppColors.primaryRed
                          : AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.glassEdge),
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      size: 16,
                      color: _armed
                          ? Colors.white
                          : AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
