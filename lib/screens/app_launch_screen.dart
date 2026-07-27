import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Branded first Flutter frame shown while the app finishes local startup.
class AppLaunchScreen extends StatefulWidget {
  const AppLaunchScreen({super.key});

  static const logoKey = Key('app_launch_logo');
  static const progressKey = Key('app_launch_progress');

  @override
  State<AppLaunchScreen> createState() => _AppLaunchScreenState();
}

class _AppLaunchScreenState extends State<AppLaunchScreen>
    with TickerProviderStateMixin {
  // Dark Koç burgundy used across the app instead of a bright generic red.
  static const _brandBurgundy = Color(0xFF4A0F24);

  late final AnimationController _revealController;
  late final AnimationController _motionController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _motionConfigured = false;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fade = CurvedAnimation(
      parent: _revealController,
      curve: const Interval(0, 0.62, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOutBack),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionConfigured) return;
    _motionConfigured = true;

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _revealController.value = 1;
      return;
    }

    _revealController.forward();
    _motionController.repeat();
  }

  @override
  void dispose() {
    _revealController.dispose();
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandBurgundy,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_revealController, _motionController]),
          builder: (context, _) {
            final motion = _motionController.value;
            final pulse = 1 + (math.sin(motion * math.pi * 2) * 0.018);
            return CustomPaint(
              painter: _LaunchBackdropPainter(motion),
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: Transform.scale(
                    scale: _scale.value * pulse,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 252,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size.square(252),
                                painter: _LaunchOrbitPainter(motion),
                              ),
                              Image.asset(
                                'assets/branding/clubup_app_icon_foreground_1024.png',
                                key: AppLaunchScreen.logoKey,
                                width: 248,
                                height: 248,
                                filterQuality: FilterQuality.high,
                                semanticLabel: 'ClubUp',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'ClubUp',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your campus, connected',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.25,
                          ),
                        ),
                        const SizedBox(height: 34),
                        SizedBox(
                          key: AppLaunchScreen.progressKey,
                          width: 58,
                          height: 18,
                          child: _LoadingDots(progress: motion),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  final double progress;

  const _LoadingDots({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (index) {
        final phase = (progress - (index * 0.14)) * math.pi * 2;
        final lift = math.max(0.0, math.sin(phase));
        return Transform.translate(
          offset: Offset(0, -5 * lift),
          child: Opacity(
            opacity: 0.45 + (0.55 * lift),
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _LaunchOrbitPainter extends CustomPainter {
  final double progress;

  _LaunchOrbitPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseAngle = progress * math.pi * 2;
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 108),
      baseAngle,
      math.pi * 0.72,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 119),
      -baseAngle * 0.72,
      math.pi * 0.48,
      false,
      arcPaint..color = Colors.white.withValues(alpha: 0.13),
    );

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    for (var index = 0; index < 3; index++) {
      final angle = baseAngle + (index * math.pi * 2 / 3);
      final radius = index.isEven ? 108.0 : 119.0;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        index == 0 ? 3.4 : 2.4,
        dotPaint..color = Colors.white.withValues(alpha: 0.92 - index * 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LaunchOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LaunchBackdropPainter extends CustomPainter {
  final double progress;

  _LaunchBackdropPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = progress * math.pi * 2;
    final paint = Paint()..style = PaintingStyle.fill;
    final bubbles = <({Offset origin, double radius, double drift})>[
      (origin: const Offset(-0.08, 0.18), radius: 92, drift: 18),
      (origin: const Offset(1.04, 0.28), radius: 68, drift: 24),
      (origin: const Offset(0.10, 0.88), radius: 54, drift: 14),
      (origin: const Offset(0.92, 0.82), radius: 112, drift: 20),
    ];

    for (var index = 0; index < bubbles.length; index++) {
      final bubble = bubbles[index];
      final offsetPhase = phase + (index * math.pi / 2);
      final center = Offset(
        size.width * bubble.origin.dx + math.cos(offsetPhase) * bubble.drift,
        size.height * bubble.origin.dy + math.sin(offsetPhase) * bubble.drift,
      );
      paint.color = Colors.white.withValues(alpha: 0.035 + index * 0.008);
      canvas.drawCircle(center, bubble.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LaunchBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
