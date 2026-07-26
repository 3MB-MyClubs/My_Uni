import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dims the whole screen and punches a rounded-rect hole over the spotlight.
class SpotlightMaskPainter extends CustomPainter {
  final Rect? spotlight;
  final Color color;

  const SpotlightMaskPainter({required this.spotlight, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (spotlight != null) {
      path.addRRect(
        RRect.fromRectAndRadius(
          spotlight!,
          Radius.circular(math.min(18, spotlight!.shortestSide / 2)),
        ),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant SpotlightMaskPainter oldDelegate) {
    return oldDelegate.spotlight != spotlight || oldDelegate.color != color;
  }
}

/// The soft pulsing ring drawn just outside the spotlight hole.
class TargetGlowPainter extends CustomPainter {
  final Color color;
  final double pulse;

  const TargetGlowPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = math.min(22.0, rect.shortestSide / 2);
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(7),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: 0.18 + (pulse * 0.14))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + (pulse * 9)),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: 0.88 - (pulse * 0.16))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawRRect(
      rrect.deflate(3),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28 + (pulse * 0.12))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // A tiny travelling glint makes the spotlight feel active without
    // competing with the real control inside it.
    final glint = Offset(
      rrect.right - 4 - (pulse * 6),
      rrect.top + 3 + (pulse * 4),
    );
    canvas.drawCircle(
      glint,
      2.2 + pulse,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72 - (pulse * 0.18))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  @override
  bool shouldRepaint(covariant TargetGlowPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.color != color;
  }
}
