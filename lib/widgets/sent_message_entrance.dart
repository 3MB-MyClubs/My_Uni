import 'package:flutter/material.dart';

/// How long a freshly sent message takes to travel from the composer into the
/// thread. Short on purpose: the list's scroll-to-bottom runs on the same
/// clock, so the bubble and the conversation above it move as one gesture.
const sentMessageEntranceDuration = Duration(milliseconds: 300);

/// Decelerating, with no overshoot. This curve drives the row's *height*, so an
/// overshooting one would shove the messages above their resting place and pull
/// them back — the exact wobble this animation exists to avoid.
const sentMessageEntranceCurve = Cubic(0.22, 1, 0.36, 1);

/// Opacity is finished well before the slide is, so the bubble is only
/// translucent while it is still half-hidden behind the composer edge.
const _sentMessageFadeCurve = Interval(0, 0.5, curve: Curves.easeOut);

/// Gives a freshly sent message the hand-off used by modern chat apps: the row
/// opens from zero height while the bubble rides up through the opening, so the
/// bubble appears to slide out from behind the composer and the rest of the
/// conversation is pushed up in lockstep instead of jumping by a full bubble.
///
/// Both effects come from one clock, which is what makes it read as a single
/// rigid movement: [SizeTransition] with `axisAlignment: -1` pins the child's
/// top to the growing box and clips its bottom, so in a `reverse: true` list —
/// where the newest row's bottom sits at the bottom of the viewport — the child
/// translates upward by exactly the amount the row grows.
///
/// The animation is opt-in so messages loaded from storage or received from
/// another participant never replay it during ordinary list rebuilds.
class SentMessageEntrance extends StatefulWidget {
  const SentMessageEntrance({
    super.key,
    required this.animate,
    required this.child,
    this.onCompleted,
  });

  final bool animate;
  final Widget child;
  final VoidCallback? onCompleted;

  @override
  State<SentMessageEntrance> createState() => _SentMessageEntranceState();
}

class _SentMessageEntranceState extends State<SentMessageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _reveal;
  late final CurvedAnimation _fade;
  bool _reportedCompletion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: sentMessageEntranceDuration,
      value: widget.animate ? 0 : 1,
    );
    _reveal = CurvedAnimation(
      parent: _controller,
      curve: sentMessageEntranceCurve,
    );
    _fade = CurvedAnimation(parent: _controller, curve: _sentMessageFadeCurve);
    if (widget.animate) _start();
  }

  @override
  void didUpdateWidget(covariant SentMessageEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _reportedCompletion = false;
      _controller.value = 0;
      _start();
    }
  }

  void _start() {
    _controller.forward().whenComplete(_reportCompletion);
  }

  void _reportCompletion() {
    if (!mounted || _reportedCompletion) return;
    _reportedCompletion = true;
    widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _reveal.dispose();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    // Both transitions are RenderObject-driven and take the row as a cached
    // `child`, so a frame of this animation costs one relayout of the box and
    // no rebuild of the bubble underneath it.
    return SizeTransition(
      sizeFactor: _reveal,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _fade,
        // The alignment inside SizeTransition hands the row loose constraints;
        // without this the row could size to its content mid-flight and the
        // bubble would re-wrap and shift sideways as it arrives.
        child: SizedBox(width: double.infinity, child: widget.child),
      ),
    );
  }
}
