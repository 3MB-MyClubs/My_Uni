import 'package:flutter/material.dart';

/// Gives a freshly sent message the short upward hand-off used by modern chat
/// apps: it starts near the composer, then settles into its list position.
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
  static const _duration = Duration(milliseconds: 440);
  static const _settleCurve = Cubic(0.20, 0.72, 0.24, 1);

  late final AnimationController _controller;
  late final Animation<double> _settle;
  bool _reportedCompletion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: widget.animate ? 0 : 1,
    );
    _settle = CurvedAnimation(parent: _controller, curve: _settleCurve);
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _settle,
      child: widget.child,
      builder: (context, child) {
        final progress = _settle.value;
        return Opacity(
          opacity: 0.78 + (0.22 * progress),
          child: Transform.translate(
            offset: Offset(0, 34 * (1 - progress)),
            child: Transform.scale(
              alignment: Alignment.bottomRight,
              scale: 0.975 + (0.025 * progress),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
