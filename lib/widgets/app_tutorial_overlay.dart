import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_colors.dart';

/// One step of the interactive app tour.
///
/// When [targetKey] is null the step is a centered "hero" card (welcome /
/// finale). Otherwise the overlay highlights the live widget that key is
/// attached to — scrolling it into view, drawing a pulsing ring + a pointer
/// arrow on it, and placing the coaching card so the element stays visible.
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

/// Transparent, step-by-step coach-mark overlay.
///
/// The app underneath stays fully visible — there is no dimming scrim. Each
/// anchored step points an animated ring + arrow at the real UI element it
/// describes. A full-screen transparent layer keeps the tour in control
/// (tap-anywhere advances) without hiding anything.
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

  // The rect currently highlighted. Driven by [_spotCtrl] so it glides smoothly
  // from one element to the next.
  Rect? _displayRect;
  Rect? _animFrom;
  Rect? _animTo;
  bool _shrinkToNull = false;
  int _measureAttempts = 0;
  bool _didScrollForStep = false;

  late final AnimationController _enterCtrl; // whole-overlay fade-in
  late final AnimationController _spotCtrl; // ring glide between targets
  late final AnimationController _pulseCtrl; // breathing glow + arrow bob
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
    _content = CurvedAnimation(
      parent: _contentCtrl,
      curve: Curves.easeOutCubic,
    );

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

  // ── Target measurement, scroll-into-view & glide ────────────────────────────

  void _onSpotTick() {
    final from = _animFrom;
    final to = _animTo;
    if (from == null || to == null) return;
    final t = _spot.value;
    setState(() {
      _displayRect = (t >= 1.0 && _shrinkToNull)
          ? null
          : Rect.lerp(from, to, t);
    });
  }

  void _scheduleMeasure() {
    _measureAttempts = 0;
    _didScrollForStep = false;
    _attemptMeasure();
  }

  void _attemptMeasure() {
    if (!mounted) return;
    final context = _step.targetKey?.currentContext;

    // Before the first measurement of an anchored step, bring the element into
    // view so the highlight and the card are visible together. Re-measure once
    // the scroll has settled.
    if (context != null && !_didScrollForStep) {
      _didScrollForStep = true;
      try {
        Scrollable.ensureVisible(
          context,
          alignment: 0.42,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeInOutCubic,
        );
      } catch (_) {
        // Element isn't inside a Scrollable (e.g. the nav bar) — nothing to do.
      }
      Future.delayed(const Duration(milliseconds: 380), _attemptMeasure);
      return;
    }

    final rect = _resolveTargetRect();
    // The target lives inside a tab that may need a frame or two to lay out
    // after a tab switch — retry briefly before giving up.
    if (rect == null && _step.targetKey != null && _measureAttempts < 8) {
      _measureAttempts++;
      Future.delayed(const Duration(milliseconds: 45), _attemptMeasure);
      return;
    }
    _beginSpotlight(rect);
  }

  Rect? _resolveTargetRect() {
    final context = _step.targetKey?.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final origin = renderObject.localToGlobal(Offset.zero);
    return (origin & renderObject.size).inflate(7);
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
      // Grow the ring out of the target's center.
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
            final screenSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final target = _visibleTarget(screenSize);
            final placement = target == null
                ? null
                : _resolveCardPlacement(
                    target,
                    screenSize,
                    MediaQuery.paddingOf(context),
                  );
            final cardAbove = placement?.above ?? false;

            return Stack(
              children: [
                // Transparent tap-catcher. Keeps the tour in control without
                // dimming the app; tapping anywhere advances (except the last
                // step). Tapping the card itself is absorbed separately.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _isLast ? null : () => _moveTo(_index + 1),
                  ),
                ),

                // Ring + arrow on the live element.
                if (target != null && !_shrinkToNull) ...[
                  _buildGlowRing(target),
                  _buildPointerArrow(target, cardAbove, screenSize),
                ],

                // The coaching card (carries its own Skip control).
                _buildCard(screenSize, target, placement),
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

  // Chooses the side of [target] with more room and caps the card height to
  // that side's free space, so the coaching card can never overlap the element
  // it is pointing at. The element (and the live UI) always stays visible.
  _CardPlacement _resolveCardPlacement(
    Rect target,
    Size screen,
    EdgeInsets pad,
  ) {
    const gap = 22.0; // room for the pointer arrow + breathing space
    final topInset = pad.top + 56; // clear the Skip button at the top-right
    final bottomInset = pad.bottom + 16;
    final ceiling = math.min(440.0, screen.height * 0.62);

    final spaceAbove = target.top - topInset - gap;
    final spaceBelow = screen.height - target.bottom - bottomInset - gap;
    final placeBelow = spaceBelow >= spaceAbove;
    final avail = math.max(0.0, placeBelow ? spaceBelow : spaceAbove);

    return _CardPlacement(
      above: !placeBelow,
      // Distance from the screen edge (top when below, bottom when above) to
      // the card's near edge.
      offset: placeBelow
          ? target.bottom + gap
          : screen.height - target.top + gap,
      maxHeight: math.min(ceiling, avail),
    );
  }

  // Highlight drawn as STROKES only (outline + outward glow), never a fill — so
  // the element inside the ring (its icons and labels) stays fully readable
  // while the tour points at it.
  Widget _buildGlowRing(Rect target) {
    const pad =
        16.0; // transparent room for the blurred glow so it isn't clipped
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final p = Curves.easeInOut.transform(_pulseCtrl.value);
        return Positioned.fromRect(
          rect: target.inflate(2 * p).inflate(pad),
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RingPainter(pulse: p, pad: pad),
            ),
          ),
        );
      },
    );
  }

  // Small triangle sitting in the gap between the card and the element,
  // pointing at the element and gently bobbing toward it.
  Widget _buildPointerArrow(Rect target, bool cardAbove, Size screenSize) {
    const w = 26.0;
    const h = 14.0;
    const margin = 16.0;
    final cx = target.center.dx.clamp(
      margin + w,
      screenSize.width - margin - w,
    );

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final p = Curves.easeInOut.transform(_pulseCtrl.value);
        // Arrow points down at the element when the card is above it, and up
        // when the card is below it.
        final pointDown = cardAbove;
        final top = pointDown
            ? target.top - h - 4 - 2 * p
            : target.bottom + 4 + 2 * p;
        return Positioned(
          left: cx - w / 2,
          top: top,
          child: IgnorePointer(
            child: CustomPaint(
              size: const Size(w, h),
              painter: _ArrowPainter(
                pointDown: pointDown,
                color: AppColors.primaryRed,
              ),
            ),
          ),
        );
      },
    );
  }

  // Low-emphasis "Skip tour" control that lives INSIDE the coaching card, so no
  // floating chrome ever covers the element being taught. Hidden on the last
  // step, where the primary button already finishes the tour.
  Widget _skipButton() {
    return TextButton.icon(
      onPressed: widget.onSkip,
      icon: const Icon(Icons.close_rounded, size: 15),
      label: const Text(
        'Skip tour',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondaryText,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ── Card placement ──────────────────────────────────────────────────────────

  Widget _buildCard(Size screenSize, Rect? target, _CardPlacement? placement) {
    const margin = 16.0;

    // Absorb taps so tapping the card itself never triggers tap-to-advance.
    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: _animatedContent(
        child: _isHero ? _buildHeroCard() : _buildAnchoredCard(),
      ),
    );

    if (_isHero || target == null || placement == null) {
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

    // Height is capped to the free space on the chosen side, so the card is
    // always fully on one side of the element — never on top of it. If space
    // is tight the card scrolls internally rather than spilling over.
    final wrapped = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: placement.maxHeight),
      child: SingleChildScrollView(child: card),
    );

    return Positioned(
      left: margin,
      right: margin,
      top: placement.above ? null : placement.offset,
      bottom: placement.above ? placement.offset : null,
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
              children: [if (_isLast) _buildSparkles(), _buildHeroHalo()],
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
          if (!_isLast) ...[
            const SizedBox(height: 4),
            Center(child: _skipButton()),
          ],
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
                  opacity:
                      (0.25 +
                              0.75 *
                                  ((_pulseCtrl.value + i / spots.length) % 1.0))
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
          if (!_isLast) ...[
            const SizedBox(height: 4),
            Center(child: _skipButton()),
          ],
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
        borderRadius: BorderRadius.all(Radius.circular(14)),
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
        borderRadius: BorderRadius.all(Radius.circular(100)),
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
      borderRadius: BorderRadius.all(Radius.circular(100)),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
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
        borderRadius: BorderRadius.all(Radius.circular(14)),
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
          borderRadius: BorderRadius.all(Radius.circular(14)),
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
      borderRadius: BorderRadius.all(Radius.circular(26)),
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

/// Draws the highlight as concentric strokes with an outward-only glow — no
/// fill — so the element inside the ring stays fully visible.
class _RingPainter extends CustomPainter {
  final double pulse; // 0..1 breathing
  final double pad; // transparent padding around the element

  const _RingPainter({required this.pulse, required this.pad});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pad, pad, size.width - 2 * pad, size.height - 2 * pad),
      const Radius.circular(18),
    );

    // Soft glow that hugs the outline and falls OUTWARD only (BlurStyle.outer),
    // so it never washes over the element.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppColors.primaryRed.withValues(alpha: 0.30 + 0.18 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 4 + 3 * pulse),
    );

    // Thin white separation line just outside the red ring (reads on busy UI).
    canvas.drawRRect(
      rrect.inflate(1.6),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Crisp red outline — the primary "look here" cue.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppColors.primaryRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.pulse != pulse || old.pad != pad;
}

/// Where to put the coaching card relative to the highlighted element.
class _CardPlacement {
  final bool above; // card sits above the element → arrow points down
  final double offset; // top inset (card below) or bottom inset (card above)
  final double maxHeight; // capped to the element's free side — never overlaps

  const _CardPlacement({
    required this.above,
    required this.offset,
    required this.maxHeight,
  });
}

/// Filled triangle with a white outline, pointing up or down at the element.
class _ArrowPainter extends CustomPainter {
  final bool pointDown;
  final Color color;

  const _ArrowPainter({required this.pointDown, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    } else {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.pointDown != pointDown || oldDelegate.color != color;
}
