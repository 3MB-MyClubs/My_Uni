import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The student-chat thread wallpaper from the UniHub messaging design: a soft
/// two-corner bloom under a scattered campus motif.
///
/// The motif is two tiles of simple geometric marks (168px and 121px) offset
/// against each other so the repeat never reads as a grid, and the whole layer
/// fades out toward the bottom and the edges so message bubbles stay legible.
///
/// Used by student threads (over a flat body) and by club communities (over the
/// club's chosen background gradient).
///
/// Pass [child] to paint the wallpaper behind existing content — constraints
/// pass straight through, so it is safe to wrap a stream or a filling column.
/// Omit it to use the backdrop as a `Positioned.fill` layer.
class ChatCampusBackdrop extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final Widget? child;

  const ChatCampusBackdrop({
    super.key,
    required this.isDark,
    required this.accent,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final painted = CustomPaint(
      painter: _CampusBloomPainter(isDark: isDark, accent: accent),
      size: child == null ? Size.infinite : Size.zero,
      child: child,
    );
    return child == null ? IgnorePointer(child: painted) : painted;
  }
}

class _CampusBloomPainter extends CustomPainter {
  final bool isDark;
  final Color accent;

  const _CampusBloomPainter({required this.isDark, required this.accent});

  /// Light on light in day mode, light on dark at night — same ink as the
  /// design's `rgba(140,29,64)` / `rgba(255,255,255)` pair.
  Color get _ink => isDark ? Colors.white : accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paintBloom(canvas, size);
    _paintCampusMotif(canvas, size);
  }

  // ── Corner bloom ───────────────────────────────────────────────────────────

  void _paintBloom(Canvas canvas, Size size) {
    _glow(
      canvas,
      center: Offset(size.width * 0.12, size.height * 0.04),
      radiusX: size.width * 0.70,
      radiusY: size.height * 0.42,
      color: _ink.withValues(alpha: isDark ? 0.16 : 0.10),
      edge: 0.68,
    );
    _glow(
      canvas,
      center: Offset(size.width * 0.96, size.height * 0.88),
      radiusX: size.width * 0.60,
      radiusY: size.height * 0.38,
      color: _ink.withValues(alpha: isDark ? 0.12 : 0.075),
      edge: 0.70,
    );
  }

  /// An elliptical radial gradient — drawn in unit space and scaled, which is
  /// how CSS `radial-gradient(70% 42% at …)` behaves.
  void _glow(
    Canvas canvas, {
    required Offset center,
    required double radiusX,
    required double radiusY,
    required Color color,
    required double edge,
  }) {
    if (radiusX <= 0 || radiusY <= 0) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radiusX, radiusY);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: [0, edge],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
    canvas.drawCircle(Offset.zero, 1, paint);
    canvas.restore();
  }

  // ── Campus motif ───────────────────────────────────────────────────────────

  void _paintCampusMotif(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    // The fade is applied to the finished motif, so both tiles need to live in
    // the same layer.
    canvas.saveLayer(bounds, Paint());

    final primary = Paint()
      ..color = _ink.withValues(alpha: isDark ? 0.10 : 0.085)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final primaryFill = Paint()..color = primary.color;
    final secondary = Paint()
      ..color = _ink.withValues(alpha: isDark ? 0.075 : 0.065)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final secondaryFill = Paint()..color = secondary.color;

    _tile(
      canvas,
      size,
      step: 168,
      origin: Offset.zero,
      draw: (tileCanvas) => _tileA(tileCanvas, primary, primaryFill),
    );
    _tile(
      canvas,
      size,
      step: 121,
      origin: const Offset(46, 31),
      draw: (tileCanvas) => _tileB(tileCanvas, secondary, secondaryFill),
    );

    _fadeOut(canvas, size);
    canvas.restore();
  }

  void _tile(
    Canvas canvas,
    Size size, {
    required double step,
    required Offset origin,
    required void Function(Canvas canvas) draw,
  }) {
    for (var y = origin.dy - step; y < size.height + step; y += step) {
      for (var x = origin.dx - step; x < size.width + step; x += step) {
        canvas.save();
        canvas.translate(x, y);
        draw(canvas);
        canvas.restore();
      }
    }
  }

  /// The dense 168px tile: rings, diamonds, plus marks, a bridge arch, a
  /// chevron, a tilted card and two text rules.
  void _tileA(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawCircle(const Offset(26, 32), 7, stroke);
    canvas.drawPath(_diamond(const Offset(96, 21), 9), stroke);
    canvas.drawLine(const Offset(140, 52), const Offset(140, 63), stroke);
    canvas.drawLine(const Offset(134.5, 57.5), const Offset(145.5, 57.5), stroke);
    canvas.drawCircle(const Offset(64, 74), 2.6, fill);
    canvas.drawPath(
      Path()
        ..moveTo(18, 112)
        ..arcToPoint(
          const Offset(44, 112),
          radius: const Radius.circular(16),
        ),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(104, 116)
        ..lineTo(111, 123)
        ..lineTo(104, 130),
      stroke,
    );
    canvas.save();
    canvas.translate(148, 138);
    canvas.rotate(22 * math.pi / 180);
    canvas.translate(-148, -138);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(142, 132, 12, 12),
        const Radius.circular(2),
      ),
      stroke,
    );
    canvas.restore();
    canvas.drawLine(const Offset(62, 150), const Offset(75, 150), stroke);
    canvas.drawLine(const Offset(62, 157), const Offset(70, 157), stroke);
    canvas.drawPath(_diamond(const Offset(120, 82), 8), stroke);
  }

  /// The sparser 121px tile that breaks up the first one's rhythm.
  void _tileB(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawCircle(const Offset(18, 88), 4, stroke);
    canvas.drawPath(_diamond(const Offset(86, 52), 6), stroke);
    canvas.drawLine(const Offset(44, 16), const Offset(44, 25), stroke);
    canvas.drawLine(const Offset(39.5, 20.5), const Offset(48.5, 20.5), stroke);
    canvas.drawCircle(const Offset(104, 104), 1.9, fill);
    canvas.drawLine(const Offset(8, 34), const Offset(18, 34), stroke);
  }

  Path _diamond(Offset center, double half) => Path()
    ..moveTo(center.dx, center.dy - half)
    ..lineTo(center.dx + half, center.dy)
    ..lineTo(center.dx, center.dy + half)
    ..lineTo(center.dx - half, center.dy)
    ..close();

  /// Fades the motif from full strength near the top of the thread down to a
  /// quarter at the far edges, matching the design's radial mask.
  void _fadeOut(Canvas canvas, Size size) {
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.04;
    final radiusX = size.width * 1.35;
    final radiusY = size.height * 1.05;
    if (radiusX <= 0 || radiusY <= 0) return;
    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.scale(radiusX, radiusY);
    final paint = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          Colors.white,
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.25),
        ],
        stops: const [0, 0.22, 0.72, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
    canvas.drawRect(
      Rect.fromLTRB(
        -centerX / radiusX,
        -centerY / radiusY,
        (size.width - centerX) / radiusX,
        (size.height - centerY) / radiusY,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CampusBloomPainter oldDelegate) {
    return isDark != oldDelegate.isDark || accent != oldDelegate.accent;
  }
}
