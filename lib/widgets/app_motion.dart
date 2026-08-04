import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A quiet floating loop for empty-state artwork. Motion stops completely when
/// the platform's reduced-motion preference is enabled.
class GentleFloat extends StatefulWidget {
  const GentleFloat({
    super.key,
    required this.child,
    this.distance = 6,
    this.duration = const Duration(milliseconds: 2800),
  });

  final Widget child;
  final double distance;
  final Duration duration;

  @override
  State<GentleFloat> createState() => _GentleFloatState();
}

class _GentleFloatState extends State<GentleFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 0.5,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final eased = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, (eased - 0.5) * widget.distance),
          child: child,
        );
      },
    );
  }
}

/// Gives newly mounted list content a short, capped staggered entrance.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 45),
  });

  final int index;
  final Widget child;
  final Duration step;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    final cappedIndex = widget.index.clamp(0, 6);
    _timer = Timer(widget.step * cappedIndex, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 14 * (1 - animation.value)),
          child: Transform.scale(
            alignment: Alignment.topCenter,
            scale: 0.985 + (0.015 * animation.value),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Replays a restrained horizontal shake whenever [trigger] changes.
class ShakeOnChange extends StatefulWidget {
  const ShakeOnChange({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<ShakeOnChange> createState() => _ShakeOnChangeState();
}

class _ShakeOnChangeState extends State<ShakeOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: 1,
  );
  late final Animation<double> _offset = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -5), weight: 16),
    TweenSequenceItem(tween: Tween(begin: -5, end: 4), weight: 22),
    TweenSequenceItem(tween: Tween(begin: 4, end: -3), weight: 22),
    TweenSequenceItem(tween: Tween(begin: -3, end: 2), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 2, end: 0), weight: 20),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant ShakeOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger == oldWidget.trigger || widget.trigger == 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        key: const ValueKey('validation-shake-motion'),
        offset: Offset(_offset.value, 0),
        child: child,
      ),
    );
  }
}

/// A reminder icon that swings on either state transition, then settles.
class AnimatedReminderBell extends StatefulWidget {
  const AnimatedReminderBell({
    super.key,
    required this.active,
    required this.color,
    this.inactiveColor,
    this.size = 22,
  });

  final bool active;
  final Color color;
  final Color? inactiveColor;
  final double size;

  @override
  State<AnimatedReminderBell> createState() => _AnimatedReminderBellState();
}

class _AnimatedReminderBellState extends State<AnimatedReminderBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _turns = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -0.09), weight: 20),
    TweenSequenceItem(tween: Tween(begin: -0.09, end: 0.075), weight: 26),
    TweenSequenceItem(tween: Tween(begin: 0.075, end: -0.04), weight: 22),
    TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.02), weight: 18),
    TweenSequenceItem(tween: Tween(begin: 0.02, end: 0), weight: 14),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant AnimatedReminderBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _turns,
      child: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: Icon(
          widget.active
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          key: ValueKey(widget.active),
          color: widget.active
              ? widget.color
              : widget.inactiveColor ?? widget.color,
          size: widget.size,
        ),
      ),
      builder: (context, child) => Transform.rotate(
        key: const ValueKey('event-reminder-bell-motion'),
        angle: _turns.value * math.pi * 2,
        child: child,
      ),
    );
  }
}

/// Brief ring/scale celebration around an avatar after a follow action.
class FollowAvatarPulse extends StatelessWidget {
  const FollowAvatarPulse({
    super.key,
    required this.active,
    required this.color,
    required this.child,
  });

  final bool active;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(active),
      tween: Tween(begin: 0, end: active && !reduceMotion ? 1 : 0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, progress, child) {
        final pulse = math.sin(progress * math.pi);
        return Transform.scale(
          key: const ValueKey('follow-avatar-ring-motion'),
          scale: 1 + (pulse * 0.055),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: pulse * 0.8),
                width: 2,
              ),
              boxShadow: pulse == 0
                  ? null
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: pulse * 0.24),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: Padding(padding: const EdgeInsets.all(2), child: child),
          ),
        );
      },
      child: child,
    );
  }
}

/// A small vertical roll for counts that increase, decrease, appear, or hide.
class RollingCount extends StatefulWidget {
  const RollingCount({super.key, required this.value, required this.style});

  final int? value;
  final TextStyle style;

  @override
  State<RollingCount> createState() => _RollingCountState();
}

class _RollingCountState extends State<RollingCount> {
  bool _increasing = true;

  @override
  void didUpdateWidget(covariant RollingCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    _increasing = (widget.value ?? 0) >= (oldWidget.value ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: Offset(0, _increasing ? 0.55 : -0.55),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return ClipRect(
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          ),
        );
      },
      child: widget.value == null
          ? const SizedBox.shrink(key: ValueKey('rolling-count-empty'))
          : Padding(
              key: ValueKey(widget.value),
              padding: const EdgeInsets.only(left: 6),
              child: Text('${widget.value}', style: widget.style),
            ),
    );
  }
}
