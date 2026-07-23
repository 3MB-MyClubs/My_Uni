import 'package:flutter/material.dart';

import '../services/app_colors.dart';

/// A short, Discord-style boot animation played once at cold start: the ClubUp
/// logo pops in and spins briefly at the center of a solid brand-red backdrop,
/// settles, then crossfades into [child] (whichever screen the app would
/// normally open on — Login, the Terms gate, a resumed Sign-up, etc.).
///
/// This is purely a cosmetic branding beat — it gates on nothing async. When
/// its timeline finishes it calls [onFinished] so the host can drop the splash
/// wrapper and render [child] directly (making the animation truly one-shot per
/// process launch).
///
/// Respects the platform "reduce motion" setting: when
/// `MediaQuery.disableAnimations` is true it skips straight to [child] with no
/// pop/spin/crossfade.
class BootSplashScreen extends StatefulWidget {
  final Widget child;
  final VoidCallback onFinished;

  const BootSplashScreen({
    super.key,
    required this.child,
    required this.onFinished,
  });

  @override
  State<BootSplashScreen> createState() => _BootSplashScreenState();
}

class _BootSplashScreenState extends State<BootSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _logoAsset =
      'assets/branding/clubup_app_icon_foreground_1024.png';

  late final AnimationController _controller;

  // Pop-in — scale 0.6 → 1.0 with overshoot, opacity 0 → 1 (first ~330ms).
  late final Animation<double> _popScale;
  late final Animation<double> _popOpacity;
  // Spin — two full turns settling to rest (~600ms), then a brief hold.
  late final Animation<double> _spin;
  // Crossfade out — splash fades away while [child] fades in (last ~250ms).
  late final Animation<double> _splashOpacity;
  late final Animation<double> _childOpacity;

  bool _started = false;
  bool _finished = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );

    _popScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.26, curve: Curves.easeOutBack),
      ),
    );
    _popOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
      ),
    );
    _spin = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.24, 0.72, curve: Curves.easeInOut),
      ),
    );
    // Hold at rest spans 0.72 → 0.82 (both fades below start at 0.82).
    _splashOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.82, 1.0, curve: Curves.easeIn),
      ),
    );
    _childOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.82, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery isn't available in initState, so kick off (or skip) here —
    // guarded so a later dependency change (theme/locale) never restarts it.
    if (_started) return;
    _started = true;
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_reducedMotion) {
      // Hand off after this frame so we don't call setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else {
      _controller.forward();
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion: no splash at all, just the destination.
    if (_reducedMotion) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Destination fades in underneath during the final crossfade.
            Opacity(opacity: _childOpacity.value, child: widget.child),
            // Brand-red splash on top, fading out at the very end.
            Opacity(
              opacity: _splashOpacity.value,
              child: ColoredBox(
                color: AppColors.primaryRed,
                child: Center(
                  child: Opacity(
                    opacity: _popOpacity.value,
                    child: Transform.scale(
                      scale: _popScale.value,
                      child: RotationTransition(
                        turns: _spin,
                        child: Image.asset(
                          _logoAsset,
                          width: 112,
                          height: 112,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
