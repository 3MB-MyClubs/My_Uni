import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import 'onboarding_steps.dart';
import 'widgets/onboarding_finish_view.dart';
import 'widgets/onboarding_guide_card.dart';
import 'widgets/onboarding_spotlight.dart';
import 'widgets/onboarding_welcome_view.dart';

enum _Phase { welcome, tour, finish }

/// The full first-run experience, stacked over MainNavScreen's Scaffold:
/// welcome (Act 1) → spotlight tour (Act 2) → finish (Act 3) → Home.
///
/// The host owns tab switching (via [onStepChanged]) and persistence (via
/// [onComplete] / [onSkip]); this widget owns everything visual.
class OnboardingFlow extends StatefulWidget {
  final List<OnboardingStep> steps;
  final String userId;
  final String firstName;
  final bool showChecklist;

  final ValueChanged<OnboardingStep>? onStepChanged;

  /// The final guide step was completed.
  final VoidCallback onComplete;

  /// The tour was skipped (from the welcome view or the mid-tour skip pill).
  final VoidCallback onSkip;

  /// Moves the host back Home while the overlay fades away.
  final VoidCallback? onNavigateHome;

  /// A finish-view checklist row was tapped: complete the tour and jump to
  /// the relevant tab instead of Home.
  final ValueChanged<int>? onDeepLink;

  const OnboardingFlow({
    super.key,
    required this.steps,
    required this.userId,
    required this.firstName,
    required this.showChecklist,
    required this.onComplete,
    required this.onSkip,
    this.onStepChanged,
    this.onNavigateHome,
    this.onDeepLink,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.welcome;
  int _index = 0;
  int _measureAttempt = 0;
  bool _transitioning = false;
  bool _closing = false;

  /// Set when a step's anchor never mounted (e.g. no events to RSVP to):
  /// the step degrades to a hole-less guide card with Next-only advancement.
  bool _spotlightMissing = false;

  Rect? _displayRect;
  Rect? _animationFrom;
  Rect? _animationTo;
  Rect? _targetHitRect;
  Rect? _layoutTargetRect;

  final GlobalKey _guideCardMeasureKey = GlobalKey();
  final GlobalKey _skipMeasureKey = GlobalKey();
  Size? _guideCardSize;
  Size? _skipSize;
  bool _chromeMeasureScheduled = false;

  late final AnimationController _entranceController;
  late final AnimationController _spotlightController;
  late final AnimationController _pulseController;

  OnboardingStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _spotlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addListener(_updateSpotlight);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );

    localeService.addListener(_localeChanged);
    themeService.addListener(_environmentChanged);
    _entranceController.forward();
  }

  @override
  void dispose() {
    localeService.removeListener(_localeChanged);
    themeService.removeListener(_environmentChanged);
    _entranceController.dispose();
    _spotlightController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _environmentChanged() {
    if (mounted) {
      setState(() {
        _guideCardSize = null;
        _skipSize = null;
      });
    }
  }

  void _localeChanged() => _environmentChanged();

  // ── Phase transitions ──────────────────────────────────────────────────────

  void _startTour() {
    if (widget.steps.isEmpty) {
      setState(() => _phase = _Phase.finish);
      return;
    }
    setState(() {
      _phase = _Phase.tour;
      _index = 0;
    });
    widget.onStepChanged?.call(_step);
    _pulseController.repeat(reverse: true);
    _beginStep();
  }

  Future<void> _skip() async {
    if (_closing) return;
    _closing = true;
    _pulseController.stop();
    HapticFeedback.selectionClick();
    widget.onNavigateHome?.call();
    await _entranceController.reverse();
    if (mounted) widget.onSkip();
  }

  Future<void> _finishFlow() async {
    if (_closing) return;
    _closing = true;
    _pulseController.stop();
    HapticFeedback.mediumImpact();
    // The host starts its tab transition while the tour fades, so Home is
    // already in place when the overlay disappears.
    widget.onNavigateHome?.call();
    await _entranceController.reverse();
    if (mounted) widget.onComplete();
  }

  Future<void> _deepLink(int tabIndex) async {
    if (_closing) return;
    _closing = true;
    _pulseController.stop();
    widget.onDeepLink?.call(tabIndex);
    await _entranceController.reverse();
    if (mounted) widget.onComplete();
  }

  // ── Tour stepping ──────────────────────────────────────────────────────────

  void _beginStep() {
    setState(() {
      _transitioning = true;
      _spotlightMissing = false;
      _targetHitRect = null;
      _guideCardSize = null;
      _measureAttempt = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  void _goTo(int index) {
    if (_closing || index < 0 || index >= widget.steps.length) return;
    setState(() => _index = index);
    widget.onStepChanged?.call(_step);
    _beginStep();
  }

  void _next() {
    if (_closing || _transitioning) return;
    if (_index == widget.steps.length - 1) {
      _pulseController.stop();
      setState(() {
        _phase = _Phase.finish;
        _displayRect = null;
        _targetHitRect = null;
        _layoutTargetRect = null;
      });
      return;
    }
    _goTo(_index + 1);
  }

  void _back() => _goTo(_index - 1);

  /// A tap landed on the spotlit target (via the hole Listener).
  Future<void> _advanceFromTap() async {
    if (_closing || _transitioning) return;
    setState(() => _transitioning = true);
    HapticFeedback.lightImpact();
    if (_step.tapThrough) {
      // Leave one beat for the real control beneath the hole to react.
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }
    if (!mounted) return;
    _transitioning = false;
    _next();
  }

  // ── Spotlight measurement (ported from the previous tutorial overlay) ─────

  void _updateSpotlight() {
    final from = _animationFrom;
    final to = _animationTo;
    if (!mounted || from == null || to == null) return;
    setState(() {
      _displayRect = Rect.lerp(
        from,
        to,
        Curves.easeInOutCubicEmphasized.transform(_spotlightController.value),
      );
    });
  }

  Future<void> _measureTarget() async {
    if (!mounted || _phase != _Phase.tour || _closing) return;
    final measuredIndex = _index;
    final targetContext = _step.targetKey.currentContext;
    if (targetContext == null) {
      if (_measureAttempt++ < 12) {
        await Future<void>.delayed(const Duration(milliseconds: 70));
        if (mounted && measuredIndex == _index) unawaited(_measureTarget());
        return;
      }
      // Anchor never mounted — degrade gracefully to a card-only step.
      if (mounted && measuredIndex == _index) {
        setState(() {
          _spotlightMissing = true;
          _displayRect = null;
          _targetHitRect = null;
          _layoutTargetRect = null;
          _transitioning = false;
        });
      }
      return;
    }

    try {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        alignment: 0.5,
      );
    } catch (_) {
      // Fixed navigation targets do not belong to a scrollable viewport.
    }

    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!mounted || measuredIndex != _index) return;

    final currentTargetContext = _step.targetKey.currentContext;
    if (currentTargetContext == null || !currentTargetContext.mounted) return;
    final targetObject = currentTargetContext.findRenderObject();
    final overlayObject = context.findRenderObject();
    if (targetObject is! RenderBox ||
        overlayObject is! RenderBox ||
        !targetObject.hasSize ||
        !overlayObject.hasSize) {
      if (_measureAttempt++ < 12) unawaited(_measureTarget());
      return;
    }

    final globalOrigin = targetObject.localToGlobal(Offset.zero);
    final localOrigin = overlayObject.globalToLocal(globalOrigin);
    final rawRect = localOrigin & targetObject.size;
    if (rawRect.isEmpty) return;

    _measureAttempt = 0;
    _targetHitRect = rawRect.inflate(3);
    final targetRect = rawRect.inflate(9);
    final from =
        _displayRect ??
        Rect.fromCenter(center: targetRect.center, width: 2, height: 2);

    setState(() {
      _animationFrom = from;
      _animationTo = targetRect;
      _layoutTargetRect = targetRect;
      _transitioning = true;
    });

    await _spotlightController.forward(from: 0);
    if (!mounted || measuredIndex != _index) return;
    setState(() {
      _displayRect = targetRect;
      _transitioning = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final onboardingTextStyle =
        (Theme.of(context).textTheme.bodyMedium ??
                const TextStyle(color: Colors.white, fontSize: 14))
            .copyWith(decoration: TextDecoration.none);
    return DefaultTextStyle(
      // Onboarding is stacked above the Scaffold's Material. Give it a real
      // default style so plain Text widgets never inherit MaterialApp's
      // red/yellow fallback warning (a yellow double underline).
      style: onboardingTextStyle,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _entranceController,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: switch (_phase) {
            _Phase.welcome => OnboardingWelcomeView(
              key: const ValueKey('onboarding-welcome'),
              userId: widget.userId,
              firstName: widget.firstName,
              onStartTour: _startTour,
              onSkip: _skip,
            ),
            _Phase.tour => KeyedSubtree(
              key: const ValueKey('onboarding-tour'),
              child: _buildTour(context),
            ),
            _Phase.finish => OnboardingFinishView(
              key: const ValueKey('onboarding-finish'),
              showChecklist: widget.showChecklist,
              onDone: _finishFlow,
              onDeepLink: widget.onDeepLink == null ? null : _deepLink,
            ),
          },
        ),
      ),
    );
  }

  Widget _buildTour(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final spotlight = _displayRect == null
            ? null
            : _clampRect(_displayRect!, size);
        final layout = _layoutChrome(context, size, spotlight);
        _scheduleChromeMeasurement();
        final hitTarget = (_transitioning || _spotlightMissing)
            ? null
            : _targetHitRect;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SpotlightMaskPainter(
                    spotlight: spotlight,
                    color: const Color(0xFF10070A).withValues(alpha: 0.72),
                  ),
                ),
              ),
            ),
            ..._outsideBlockers(size, hitTarget),
            if (hitTarget != null)
              Positioned.fromRect(
                rect: _clampRect(hitTarget, size),
                child: Listener(
                  // translucent: the tap reaches the real control beneath the
                  // overlay AND we observe it to advance. opaque: we swallow
                  // it (targets that would push a covering route).
                  behavior: _step.tapThrough
                      ? HitTestBehavior.translucent
                      : HitTestBehavior.opaque,
                  onPointerUp: (event) => unawaited(_advanceFromTap()),
                ),
              ),
            if (spotlight != null && !_spotlightMissing)
              _buildTargetGlow(spotlight),
            _buildGuideCard(layout.guideRect),
            _buildSkip(layout.skipRect),
          ],
        );
      },
    );
  }

  Rect _clampRect(Rect rect, Size size) {
    return Rect.fromLTRB(
      rect.left.clamp(0.0, size.width),
      rect.top.clamp(0.0, size.height),
      rect.right.clamp(0.0, size.width),
      rect.bottom.clamp(0.0, size.height),
    );
  }

  List<Widget> _outsideBlockers(Size size, Rect? target) {
    if (target == null) {
      return [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => HapticFeedback.selectionClick(),
          ),
        ),
      ];
    }

    final hole = _clampRect(target, size);
    final rects = <Rect>[
      Rect.fromLTRB(0, 0, size.width, hole.top),
      Rect.fromLTRB(0, hole.bottom, size.width, size.height),
      Rect.fromLTRB(0, hole.top, hole.left, hole.bottom),
      Rect.fromLTRB(hole.right, hole.top, size.width, hole.bottom),
    ];
    return rects
        .where((rect) => rect.width > 0 && rect.height > 0)
        .map(
          (rect) => Positioned.fromRect(
            rect: rect,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => HapticFeedback.selectionClick(),
            ),
          ),
        )
        .toList();
  }

  Widget _buildTargetGlow(Rect target) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = Curves.easeInOut.transform(_pulseController.value);
        return Positioned.fromRect(
          rect: target.inflate(8),
          child: IgnorePointer(
            child: CustomPaint(
              painter: TargetGlowPainter(
                color: AppColors.primaryRed,
                pulse: pulse,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideCard(Rect guideRect) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      left: guideRect.left,
      top: guideRect.top,
      width: guideRect.width,
      child: IgnorePointer(
        ignoring: _transitioning && !_spotlightMissing,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: (_transitioning && !_spotlightMissing) ? 0.0 : 1.0,
          child: KeyedSubtree(
            key: _guideCardMeasureKey,
            child: OnboardingGuideCard(
              text: _step.text,
              icon: _step.icon,
              index: _index,
              total: widget.steps.length,
              isLast: _index == widget.steps.length - 1,
              onNext: _next,
              onBack: _index == 0 ? null : _back,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkip(Rect skipRect) {
    final isDark = themeService.isDark;
    const accent = Color(0xFF9E2045);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      left: skipRect.left,
      top: skipRect.top,
      child: KeyedSubtree(
        key: _skipMeasureKey,
        child: Semantics(
          button: true,
          label: S.onboardingSkipTour,
          child: Material(
            key: const ValueKey('onboarding-skip-button'),
            color: isDark
                ? const Color(0xFF191416).withValues(alpha: 0.96)
                : const Color(0xFFFFFBF7).withValues(alpha: 0.97),
            elevation: 0,
            shadowColor: accent.withValues(alpha: 0.25),
            shape: StadiumBorder(
              side: BorderSide(
                color: accent.withValues(alpha: isDark ? 0.68 : 0.32),
              ),
            ),
            child: InkWell(
              onTap: _skip,
              borderRadius: BorderRadius.circular(99),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      S.onboardingSkipTour,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A0610),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isDark ? Colors.white : const Color(0xFF1A0610),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _TourChromeLayout _layoutChrome(
    BuildContext context,
    Size screenSize,
    Rect? animatedSpotlight,
  ) {
    final media = MediaQuery.of(context);
    const edge = 16.0;
    final safeTop = math.max(edge, media.padding.top + 10);
    final safeBottom = math.max(
      safeTop,
      screenSize.height - media.viewInsets.bottom - media.padding.bottom - 12,
    );
    final safeRect = Rect.fromLTRB(
      edge,
      safeTop,
      math.max(edge, screenSize.width - edge),
      safeBottom,
    );

    final guideWidth = math.min(390.0, safeRect.width);
    final measuredGuideHeight = _guideCardSize?.height ?? 260.0;
    final guideSize = Size(
      guideWidth,
      math.min(measuredGuideHeight, safeRect.height),
    );
    final target = _spotlightMissing
        ? null
        : (_layoutTargetRect ?? animatedSpotlight);
    final guideRect = _chooseGuideRect(safeRect, target, guideSize);

    final measuredSkip = _skipSize ?? const Size(122, 42);
    final skipSize = Size(
      math.min(measuredSkip.width, safeRect.width),
      math.min(measuredSkip.height, safeRect.height),
    );
    final skipRect = _chooseSkipRect(
      safeRect: safeRect,
      target: target,
      guideRect: guideRect,
      skipSize: skipSize,
    );
    return _TourChromeLayout(guideRect: guideRect, skipRect: skipRect);
  }

  Rect _chooseGuideRect(Rect safeRect, Rect? target, Size guideSize) {
    const gap = 18.0;
    final width = math.min(guideSize.width, safeRect.width);
    final height = math.min(guideSize.height, safeRect.height);

    if (target == null) {
      final reservedNavSpace = safeRect.height > 520 ? 82.0 : 0.0;
      return _fitRect(
        Rect.fromLTWH(
          safeRect.center.dx - width / 2,
          safeRect.bottom - reservedNavSpace - height,
          width,
          height,
        ),
        safeRect,
      );
    }

    final clearance = target.inflate(12);
    final rawCandidates = <_PositionCandidate>[
      _PositionCandidate(
        rect: Rect.fromLTWH(
          target.center.dx - width / 2,
          clearance.top - gap - height,
          width,
          height,
        ),
        preference: 0,
      ),
      _PositionCandidate(
        rect: Rect.fromLTWH(
          target.center.dx - width / 2,
          clearance.bottom + gap,
          width,
          height,
        ),
        preference: 1,
      ),
      _PositionCandidate(
        rect: Rect.fromLTWH(
          clearance.right + gap,
          target.center.dy - height / 2,
          width,
          height,
        ),
        preference: 2,
      ),
      _PositionCandidate(
        rect: Rect.fromLTWH(
          clearance.left - gap - width,
          target.center.dy - height / 2,
          width,
          height,
        ),
        preference: 3,
      ),
    ];

    Rect? best;
    var bestScore = double.infinity;
    for (final candidate in rawCandidates) {
      final fitted = _fitRect(candidate.rect, safeRect);
      final overlap = _intersectionArea(fitted, clearance);
      final score =
          (_overflowDistance(candidate.rect, safeRect) * 10000) +
          (overlap * 100000) +
          candidate.preference;
      if (score < bestScore) {
        bestScore = score;
        best = fitted;
      }
    }
    return best!;
  }

  Rect _chooseSkipRect({
    required Rect safeRect,
    required Rect? target,
    required Rect guideRect,
    required Size skipSize,
  }) {
    const separation = 12.0;
    final maxX = math.max(safeRect.left, safeRect.right - skipSize.width);
    final maxY = math.max(safeRect.top, safeRect.bottom - skipSize.height);
    final xPositions = <double>{
      safeRect.left,
      (safeRect.center.dx - skipSize.width / 2).clamp(safeRect.left, maxX),
      maxX,
    };
    final yPositions = <double>{safeRect.top, maxY};

    // Scan both vertical edges as a fallback for compact screens where a
    // corner is occupied by either the target or the card.
    final verticalRoom = math.max(0.0, maxY - safeRect.top);
    final slots = math.max(1, (verticalRoom / 52).floor());
    for (var i = 1; i < slots; i++) {
      yPositions.add(safeRect.top + (verticalRoom * i / slots));
    }

    final candidates = <Rect>[];
    for (final y in yPositions) {
      for (final x in xPositions) {
        candidates.add(Rect.fromLTWH(x, y, skipSize.width, skipSize.height));
      }
    }

    final targetClearance = target?.inflate(separation);
    final guideClearance = guideRect.inflate(separation);
    Rect? best;
    var bestScore = double.infinity;
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final targetOverlap = targetClearance == null
          ? 0.0
          : _intersectionArea(candidate, targetClearance);
      final cardOverlap = _intersectionArea(candidate, guideClearance);
      final targetDistance = target == null
          ? 0.0
          : (candidate.center - target.center).distance;
      final isPreferredTopRight =
          candidate.top == safeRect.top && candidate.right == safeRect.right;
      final score =
          (targetOverlap * 100000) +
          (cardOverlap * 100000) -
          (targetDistance * 0.05) +
          (isPreferredTopRight ? 0 : 8 + index * 0.01);
      if (score < bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best!;
  }

  Rect _fitRect(Rect rect, Rect bounds) {
    final width = math.min(rect.width, bounds.width);
    final height = math.min(rect.height, bounds.height);
    final maxLeft = math.max(bounds.left, bounds.right - width);
    final maxTop = math.max(bounds.top, bounds.bottom - height);
    return Rect.fromLTWH(
      rect.left.clamp(bounds.left, maxLeft),
      rect.top.clamp(bounds.top, maxTop),
      width,
      height,
    );
  }

  double _overflowDistance(Rect rect, Rect bounds) {
    return math.max(0, bounds.left - rect.left) +
        math.max(0, bounds.top - rect.top) +
        math.max(0, rect.right - bounds.right) +
        math.max(0, rect.bottom - bounds.bottom);
  }

  double _intersectionArea(Rect first, Rect second) {
    final intersection = first.intersect(second);
    if (intersection.isEmpty) return 0;
    return intersection.width * intersection.height;
  }

  void _scheduleChromeMeasurement() {
    if (_chromeMeasureScheduled) return;
    _chromeMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chromeMeasureScheduled = false;
      if (!mounted || _phase != _Phase.tour) return;
      final guideBox = _guideCardMeasureKey.currentContext?.findRenderObject();
      final skipBox = _skipMeasureKey.currentContext?.findRenderObject();
      final nextGuideSize = guideBox is RenderBox && guideBox.hasSize
          ? guideBox.size
          : null;
      final nextSkipSize = skipBox is RenderBox && skipBox.hasSize
          ? skipBox.size
          : null;
      final guideChanged =
          nextGuideSize != null &&
          (_guideCardSize == null ||
              (nextGuideSize.height - _guideCardSize!.height).abs() > 0.5 ||
              (nextGuideSize.width - _guideCardSize!.width).abs() > 0.5);
      final skipChanged =
          nextSkipSize != null &&
          (_skipSize == null ||
              (nextSkipSize.height - _skipSize!.height).abs() > 0.5 ||
              (nextSkipSize.width - _skipSize!.width).abs() > 0.5);
      if (guideChanged || skipChanged) {
        setState(() {
          if (nextGuideSize != null) _guideCardSize = nextGuideSize;
          if (nextSkipSize != null) _skipSize = nextSkipSize;
        });
      }
    });
  }
}

class _TourChromeLayout {
  final Rect guideRect;
  final Rect skipRect;

  const _TourChromeLayout({required this.guideRect, required this.skipRect});
}

class _PositionCandidate {
  final Rect rect;
  final double preference;

  const _PositionCandidate({required this.rect, required this.preference});
}
