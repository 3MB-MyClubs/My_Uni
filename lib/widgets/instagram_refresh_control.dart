import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/material.dart';

import '../services/app_colors.dart';

/// A restrained, Instagram-style pull-to-refresh control.
///
/// Pulling progressively reveals the activity indicator's twelve ticks. Once
/// released, the indicator rotates until [onRefresh] completes, then the sliver
/// retracts immediately without a separate success animation.
class InstagramRefreshControl extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final double refreshTriggerPullDistance;
  final double refreshIndicatorExtent;

  const InstagramRefreshControl({
    super.key,
    required this.onRefresh,
    this.refreshTriggerPullDistance = 82,
    this.refreshIndicatorExtent = 48,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: refreshTriggerPullDistance,
      refreshIndicatorExtent: refreshIndicatorExtent,
      onRefresh: onRefresh,
      builder:
          (
            context,
            refreshState,
            pulledExtent,
            triggerDistance,
            indicatorExtent,
          ) {
            final progress = (pulledExtent / triggerDistance).clamp(0.0, 1.0);
            return Center(
              child: _InstagramSpinner(
                progress: progress,
                spinning: refreshState == RefreshIndicatorMode.refresh,
              ),
            );
          },
    );
  }
}

class _InstagramSpinner extends StatefulWidget {
  final double progress;
  final bool spinning;

  const _InstagramSpinner({required this.progress, required this.spinning});

  @override
  State<_InstagramSpinner> createState() => _InstagramSpinnerState();
}

class _InstagramSpinnerState extends State<_InstagramSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.stop();
    } else if (widget.spinning && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _InstagramSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_reduceMotion && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spinning && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (widget.progress * 2.2).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: 24,
        height: 24,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _InstagramSpinnerPainter(
              progress: widget.progress,
              phase: _controller.value,
              spinning: widget.spinning,
              reduceMotion: _reduceMotion,
              color: AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _InstagramSpinnerPainter extends CustomPainter {
  static const int _tickCount = 12;

  final double progress;
  final double phase;
  final bool spinning;
  final bool reduceMotion;
  final Color color;

  const _InstagramSpinnerPainter({
    required this.progress,
    required this.phase,
    required this.spinning,
    required this.reduceMotion,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final visibleTicks = spinning
        ? _tickCount
        : (progress * _tickCount).ceil().clamp(1, _tickCount);
    final pullRotation =
        Curves.easeOutCubic.transform(progress) * math.pi * 1.3;
    final rotation = spinning && !reduceMotion
        ? phase * math.pi * 2
        : pullRotation;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    for (var index = 0; index < _tickCount; index++) {
      if (!spinning && index >= visibleTicks) continue;

      final tickAlpha = spinning
          ? (0.16 + 0.84 * ((index + 1) / _tickCount))
          : (0.28 + 0.72 * ((index + 1) / visibleTicks));
      final paint = Paint()
        ..color = color.withValues(alpha: tickAlpha)
        ..strokeWidth = 1.75
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(const Offset(0, -7.0), const Offset(0, -10.0), paint);
      canvas.rotate(math.pi * 2 / _tickCount);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InstagramSpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.spinning != spinning ||
      oldDelegate.reduceMotion != reduceMotion ||
      oldDelegate.color != color;
}
