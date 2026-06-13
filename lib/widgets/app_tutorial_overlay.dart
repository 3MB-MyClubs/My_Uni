import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_colors.dart';

class AppTutorialStep {
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final GlobalKey? targetKey;
  final int tabIndex;
  final List<String> tips;

  const AppTutorialStep({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.tabIndex,
    this.targetKey,
    this.tips = const [],
  });
}

class AppTutorialOverlay extends StatefulWidget {
  final List<AppTutorialStep> steps;
  final ValueChanged<AppTutorialStep> onStepChanged;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const AppTutorialOverlay({
    super.key,
    required this.steps,
    required this.onStepChanged,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<AppTutorialOverlay> createState() => _AppTutorialOverlayState();
}

class _AppTutorialOverlayState extends State<AppTutorialOverlay>
    with TickerProviderStateMixin {
  int _index = 0;

  // The rect currently painted as the spotlight. Driven by [_spotCtrl] so it
  // glides smoothly from one highlighted element to the next.
  Rect? _displayRect;
  Rect? _animFrom;
  Rect? _animTo;
  bool _shrinkToNull = false;
  int _measureAttempts = 0;

  late final AnimationController _enterCtrl; // whole-overlay fade-in
  late final AnimationController _spotCtrl; // spotlight glide between targets
  late final AnimationController _pulseCtrl; // breathing glow ring + halo
  late final AnimationController _contentCtrl; // per-step card entrance

  late final Animation<double> _enter;
  late final Animation<double> _spot;
  late final Animation<double> _content;

  AppTutorialStep get _step => widget.steps[_index];
  bool get _isHero => _step.targetKey == null;
  bool get _isLast => _index == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _spotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _enter = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _spot = CurvedAnimation(parent: _spotCtrl, curve: Curves.easeInOutCubic);
    _content = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic);

    _spotCtrl.addListener(_onSpotTick);

    _enterCtrl.forward();
    _pulseCtrl.repeat(reverse: true);
    _contentCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onStepChanged(_step);
      _scheduleMeasure();
    });
  }

  @override
  void dispose() {
    _spotCtrl.removeListener(_onSpotTick);
    _enterCtrl.dispose();
    _spotCtrl.dispose();
    _pulseCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // ── Spotlight measurement & glide ──────────────────────────────────────────

  void _onSpotTick() {
    final from = _animFrom;
    final to = _animTo;
    if (from == null || to == null) return;
    final t = _spot.value;
    setState(() {
      _displayRect = (t >= 1.0 && _shrinkToNull) ? null : Rect.lerp(from, to, t);
    });
  }

  void _scheduleMeasure() {
    _measureAttempts = 0;
    _attemptMeasure();
  }

  void _attemptMeasure() {
    if (!mounted) return;
    final rect = _resolveTargetRect();
    // The target lives inside a tab that may need a frame or two to lay out
    // after a tab switch — retry briefly before giving up.
    if (rect == null && _step.targetKey != null && _measureAttempts < 6) {
      _measureAttempts++;
      Future.delayed(
        const Duration(milliseconds: 45),
        () => _attemptMeasure(),
      );
      return;
    }
    _beginSpotlight(rect);
  }

  Rect? _resolveTargetRect() {
    final context = _step.targetKey?.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final origin = renderObject.localToGlobal(Offset.zero);
    return (origin & renderObject.size).inflate(8);
  }

  void _beginSpotlight(Rect? to) {
    final from = _displayRect;
    _shrinkToNull = false;

    if (from == null && to == null) {
      setState(() => _displayRect = null);
      return;
    }

    Rect animFrom;
    Rect animTo;
    if (from == null && to != null) {
      // Grow the spotlight out of the target's center.
      animFrom = Rect.fromCenter(center: to.center, width: 0, height: 0);
      animTo = to;
    } else if (to == null && from != null) {
      // Collapse into the last center, then clear.
      animFrom = from;
      animTo = Rect.fromCenter(center: from.center, width: 0, height: 0);
      _shrinkToNull = true;
    } else {
      animFrom = from!;
      animTo = to!;
    }

    _animFrom = animFrom;
    _animTo = animTo;
    _spotCtrl.forward(from: 0);
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _moveTo(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= widget.steps.length) return;
    HapticFeedback.selectionClick();
    setState(() => _index = nextIndex);
    widget.onStepChanged(_step);
    _contentCtrl.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleMeasure();
    });
  }

  void _complete() {
    HapticFeedback.mediumImpact();
    widget.onComplete();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _enter,
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
            final target = _visibleTarget(screenSize);

            return Stack(
              children: [
                // Dimming scrim + soft-edged spotlight cutout.
                // Tapping the dimmed area advances (except on the last step).
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _isLast ? null : () => _moveTo(_index + 1),
                    child: CustomPaint(
                      painter: _SpotlightPainter(target),
                      size: screenSize,
                    ),
                  ),
                ),

                // Breathing glow ring around the highlighted element.
                if (target != null && !_shrinkToNull) _buildGlowRing(target),

                // Always-available skip affordance.
                _buildSkipButton(context),

                // The coaching card.
                _buildCard(context, screenSize, target),
              ],
            );
          },
        ),
      ),
    );
  }

  Rect? _visibleTarget(Size screenSize) {
    final target = _displayRect;
    if (target == null) return null;
    final visible = target.intersect(Offset.zero & screenSize);
    if (visible.width < 8 || visible.height < 8) return null;
    return visible;
  }

  Widget _buildGlowRing(Rect target) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final p = Curves.easeInOut.transform(_pulseCtrl.value);
        final rect = target.inflate(2 * p);
        return Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.92),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.35 + 0.35 * p),
                    blurRadius: 16 + 10 * p,
                    spreadRadius: 1 + 3 * p,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkipButton(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      right: 14,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.transparent,
          child: TextButton.icon(
            onPressed: widget.onSkip,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text(
              'Skip tour',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Card placement ──────────────────────────────────────────────────────────

  Widget _buildCard(BuildContext context, Size screenSize, Rect? target) {
    const margin = 16.0;
    final media = MediaQuery.of(context);

    // Absorb taps so tapping the card itself never triggers scrim-advance.
    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: _animatedContent(child: _isHero ? _buildHeroCard() : _buildAnchoredCard()),
    );

    if (_isHero || target == null) {
      return Positioned(
        left: margin,
        right: margin,
        top: 0,
        bottom: 0,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 460,
              maxHeight: screenSize.height * 0.86,
            ),
            child: SingleChildScrollView(child: card),
          ),
        ),
      );
    }

    final maxCardHeight = math.min(430.0, screenSize.height * 0.6);
    final wrapped = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxCardHeight),
      child: SingleChildScrollView(child: card),
    );

    final isLargeTarget = target.height > screenSize.height * 0.45;
    if (isLargeTarget || target.center.dy > screenSize.height * 0.55) {
      // Place the card above the target (anchored to the bottom).
      final bottom = isLargeTarget
          ? math.max(96.0, media.padding.bottom + 90)
          : screenSize.height - target.top + 14;
      return Positioned(
        left: margin,
        right: margin,
        bottom: bottom.clamp(20.0, screenSize.height * 0.72),
        child: wrapped,
      );
    }

    // Place the card below the target.
    final top = math.min(
      target.bottom + 14,
      screenSize.height - maxCardHeight - 16,
    );
    return Positioned(
      left: margin,
      right: margin,
      top: math.max(media.padding.top + 60, top),
      child: wrapped,
    );
  }

  Widget _animatedContent({required Widget child}) {
    return AnimatedBuilder(
      animation: _content,
      builder: (context, inner) {
        final v = _content.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 18),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }

  // ── Hero card (welcome & finale) ──────────────────────────────────────────

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _counterPill(),
          const SizedBox(height: 18),
          SizedBox(
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (_isLast) _buildSparkles(),
                _buildHeroHalo(),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _step.eyebrow.toUpperCase(),
            style: TextStyle(
              color: AppColors.primaryRed,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _step.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _step.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
          if (_step.tips.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _tipWidgets(),
              ),
            ),
          ],
          const SizedBox(height: 22),
          _progressBar(),
          const SizedBox(height: 18),
          _buttonRow(),
        ],
      ),
    );
  }

  Widget _buildHeroHalo() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final p = Curves.easeInOut.transform(_pulseCtrl.value);
        return Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primaryRed, AppColors.darkRed],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.35 + 0.25 * p),
                blurRadius: 26 + 14 * p,
                spreadRadius: 2 + 4 * p,
              ),
            ],
          ),
          child: Icon(_step.icon, color: Colors.white, size: 42),
        );
      },
    );
  }

  Widget _buildSparkles() {
    const spots = [
      Offset(-78, -26),
      Offset(80, -16),
      Offset(-64, 34),
      Offset(70, 40),
      Offset(2, -62),
      Offset(14, 60),
    ];
    const sizes = [12.0, 9.0, 10.0, 13.0, 8.0, 11.0];
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < spots.length; i++)
              Transform.translate(
                offset: spots[i],
                child: Opacity(
                  opacity: (0.25 +
                          0.75 * ((_pulseCtrl.value + i / spots.length) % 1.0))
                      .clamp(0.0, 1.0),
                  child: Icon(
                    Icons.star_rounded,
                    size: sizes[i],
                    color: AppColors.accentGold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Anchored card (per-feature steps) ─────────────────────────────────────

  Widget _buildAnchoredCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBadge(),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _step.eyebrow.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primaryRed,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _step.title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _counterPill(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _step.description,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (_step.tips.isNotEmpty) ...[
            const SizedBox(height: 14),
            ..._tipWidgets(),
          ],
          const SizedBox(height: 16),
          _progressBar(),
          const SizedBox(height: 16),
          _buttonRow(),
        ],
      ),
    );
  }

  Widget _iconBadge() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryRed.withValues(alpha: 0.18),
            AppColors.primaryRed.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.25)),
      ),
      child: Icon(_step.icon, color: AppColors.primaryRed, size: 24),
    );
  }

  // ── Shared pieces ───────────────────────────────────────────────────────────

  List<Widget> _tipWidgets() {
    return _step.tips
        .map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 21,
                  height: 21,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: AppColors.primaryRed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _counterPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.lightRed,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '${_index + 1}/${widget.steps.length}',
        style: TextStyle(
          color: AppColors.primaryRed,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _progressBar() {
    final value = (_index + 1) / widget.steps.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: Stack(
        children: [
          Container(height: 5, color: AppColors.divider),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 460),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v.clamp(0.0, 1.0),
              child: Container(
                height: 5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.darkRed, AppColors.primaryRed],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttonRow() {
    return Row(
      children: [
        if (_index > 0) ...[
          Expanded(child: _backButton()),
          const SizedBox(width: 10),
        ],
        Expanded(flex: 2, child: _primaryButton()),
      ],
    );
  }

  Widget _backButton() {
    return OutlinedButton(
      onPressed: () => _moveTo(_index - 1),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: BorderSide(color: AppColors.divider),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _primaryButton() {
    final label = _isLast ? 'Start exploring' : 'Next';
    final onTap = _isLast ? _complete : () => _moveTo(_index + 1);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryRed, AppColors.darkRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 7),
                Icon(
                  _isLast
                      ? Icons.rocket_launch_rounded
                      : Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: AppColors.glassEdge),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.30),
          blurRadius: 40,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: AppColors.primaryRed.withValues(alpha: 0.10),
          blurRadius: 30,
          spreadRadius: -6,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? target;

  const _SpotlightPainter(this.target);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(
      bounds,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );

    if (target != null && target!.shortestSide > 2) {
      // A soft-feathered cutout reads as a focused spotlight rather than a
      // hard-edged hole.
      final clear = Paint()
        ..blendMode = BlendMode.clear
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(18)),
        clear,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}
