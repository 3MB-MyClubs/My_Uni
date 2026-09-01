import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../widgets/tutorial_design.dart';
import 'onboarding_steps.dart';
import 'widgets/onboarding_finish_view.dart';
import 'widgets/onboarding_guide_card.dart';
import 'widgets/onboarding_welcome_view.dart';

enum _Phase { welcome, tour, finish }

/// The student in-app tutorial, stacked over MainNavScreen's Scaffold:
/// welcome (step 01) → the coach-mark tour → tour complete (step 32).
///
/// Built from `STUDENT UI · IN-APP TUTORIAL` in ClubUp-Desings — the kit board
/// `canvas-tutorial-kit` 391:4 and the `tut-*` frames at y≈34000. One pattern
/// throughout: a dimmed scrim with the target subtracted out of it, so the real
/// UI stays readable and nothing underneath is redrawn or restyled.
///
/// The host owns tab switching (via [onStepChanged]) and persistence (via
/// [onComplete] / [onSkip]); this widget owns everything visual.
class OnboardingFlow extends StatefulWidget {
  final List<OnboardingStep> steps;

  final ValueChanged<OnboardingStep>? onStepChanged;

  /// The final guide step was completed.
  final VoidCallback onComplete;

  /// The tour was skipped. "Skip tour ends the whole tour, not just the
  /// current page, and never asks a second time."
  final VoidCallback onSkip;

  /// Moves the host back Home while the overlay fades away.
  final VoidCallback? onNavigateHome;

  const OnboardingFlow({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onSkip,
    this.onStepChanged,
    this.onNavigateHome,
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
  /// the step degrades to a hole-less card centred on the screen.
  bool _spotlightMissing = false;

  Rect? _displayRect;
  Rect? _animationFrom;
  Rect? _animationTo;
  Rect? _targetHitRect;
  Rect? _layoutTargetRect;

  final GlobalKey _guideCardMeasureKey = GlobalKey();
  Size? _guideCardSize;
  bool _chromeMeasureScheduled = false;

  late final AnimationController _entranceController;
  late final AnimationController _spotlightController;

  late List<ResolvedOnboardingStep> _resolved;

  ResolvedOnboardingStep get _step => _resolved[_index];

  @override
  void initState() {
    super.initState();
    _resolved = resolveOnboardingSteps(widget.steps);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _spotlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addListener(_updateSpotlight);

    localeService.addListener(_environmentChanged);
    themeService.addListener(_environmentChanged);
    _entranceController.forward();
  }

  @override
  void didUpdateWidget(covariant OnboardingFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.steps, widget.steps)) {
      _resolved = resolveOnboardingSteps(widget.steps);
    }
  }

  @override
  void dispose() {
    localeService.removeListener(_environmentChanged);
    themeService.removeListener(_environmentChanged);
    _entranceController.dispose();
    _spotlightController.dispose();
    super.dispose();
  }

  /// A theme or language change re-measures the card, whose height depends on
  /// both.
  void _environmentChanged() {
    if (mounted) setState(() => _guideCardSize = null);
  }

  // ── Phase transitions ──────────────────────────────────────────────────────

  void _startTour() {
    if (_resolved.isEmpty) {
      setState(() => _phase = _Phase.finish);
      return;
    }
    setState(() {
      _phase = _Phase.tour;
      _index = 0;
    });
    widget.onStepChanged?.call(_step.step);
    _beginStep();
  }

  Future<void> _skip() async {
    if (_closing) return;
    _closing = true;
    HapticFeedback.selectionClick();
    widget.onNavigateHome?.call();
    await _entranceController.reverse();
    if (mounted) widget.onSkip();
  }

  Future<void> _finishFlow() async {
    if (_closing) return;
    _closing = true;
    HapticFeedback.mediumImpact();
    // The host starts its tab transition while the tour fades, so Home is
    // already in place when the overlay disappears.
    widget.onNavigateHome?.call();
    await _entranceController.reverse();
    if (mounted) widget.onComplete();
  }

  /// "Replay the tour" on the finish card. `panel-behaviour` 392:5 puts the
  /// restart at step 01, which is the welcome card.
  void _replay() {
    if (_closing) return;
    HapticFeedback.selectionClick();
    widget.onNavigateHome?.call();
    setState(() {
      _phase = _Phase.welcome;
      _index = 0;
      _displayRect = null;
      _targetHitRect = null;
      _layoutTargetRect = null;
      _guideCardSize = null;
    });
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
    if (_closing || index < 0 || index >= _resolved.length) return;
    setState(() => _index = index);
    widget.onStepChanged?.call(_step.step);
    _beginStep();
  }

  void _next() {
    if (_closing || _transitioning) return;
    if (_index == _resolved.length - 1) {
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

  /// A tap landed on the spotlit target (via the hole Listener). "Tapping
  /// inside the spotlight performs the real action and advances the step."
  Future<void> _advanceFromTap() async {
    if (_closing || _transitioning) return;
    setState(() => _transitioning = true);
    HapticFeedback.lightImpact();
    if (_step.step.tapThrough) {
      // Leave one beat for the real control beneath the hole to react.
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }
    if (!mounted) return;
    _transitioning = false;
    _next();
  }

  // ── Spotlight measurement ──────────────────────────────────────────────────

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
    final targetContext = _step.step.targetKey.currentContext;
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

    final currentTargetContext = _step.step.targetKey.currentContext;
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
    _targetHitRect = rawRect;
    // "Target bounds inflated by 8 px on every side."
    final targetRect = rawRect.inflate(TutorialMetrics.spotlightInset);
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
              onStartTour: _startTour,
              onSkip: _skip,
            ),
            _Phase.tour => KeyedSubtree(
              key: const ValueKey('onboarding-tour'),
              child: _buildTour(context),
            ),
            _Phase.finish => OnboardingFinishView(
              key: const ValueKey('onboarding-finish'),
              onReplay: _replay,
              onDone: _finishFlow,
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
        final hole = (_displayRect == null || _spotlightMissing)
            ? null
            : _clampRect(_displayRect!, size);
        // Placed from the settled rect, not the animating one: the card is
        // faded out during the move and should land at its final spot.
        final media = MediaQuery.of(context);
        final placement = placeTutorialCard(
          screen: size,
          safeArea: EdgeInsets.only(
            top: media.padding.top,
            bottom: media.viewInsets.bottom + media.padding.bottom,
          ),
          hole: _spotlightMissing ? null : (_layoutTargetRect ?? hole),
          cardSize: Size(
            TutorialMetrics.cardWidth,
            _guideCardSize?.height ?? 200.0,
          ),
        );
        _scheduleChromeMeasurement();
        final hitTarget = (_transitioning || _spotlightMissing)
            ? null
            : _targetHitRect;
        final radius = _step.step.spotlightRadius;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: TutorialSpotlight(hole: hole, radius: radius),
            ),
            // "Tapping the scrim does nothing, so the tour cannot be dismissed
            // by accident."
            ..._outsideBlockers(size, hitTarget),
            if (hitTarget != null)
              Positioned.fromRect(
                rect: _clampRect(hitTarget, size),
                child: Listener(
                  // translucent: the tap reaches the real control beneath the
                  // overlay AND we observe it to advance. opaque: we swallow
                  // it (targets that would push a covering route).
                  behavior: _step.step.tapThrough
                      ? HitTestBehavior.translucent
                      : HitTestBehavior.opaque,
                  onPointerUp: (event) => unawaited(_advanceFromTap()),
                ),
              ),
            if (placement.beak != null) _buildBeak(placement.beak!),
            _buildGuideCard(placement.card),
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

  Widget _buildBeak(TutorialBeak beak) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      left: beak.left,
      top: beak.top,
      width: TutorialMetrics.beakWidth,
      height: TutorialMetrics.beakHeight,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _transitioning ? 0.0 : 1.0,
          child: TutorialBeakView(beak: beak),
        ),
      ),
    );
  }

  Widget _buildGuideCard(Rect guideRect) {
    final hidden = _transitioning && !_spotlightMissing;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      left: guideRect.left,
      top: guideRect.top,
      width: guideRect.width,
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: hidden ? 0.0 : 1.0,
          child: KeyedSubtree(
            key: _guideCardMeasureKey,
            child: OnboardingGuideCard(
              eyebrow: _step.eyebrow,
              title: _step.step.title?.call(),
              body: _step.step.body(),
              progressIndex: _step.showProgress ? _step.indexInPage : null,
              progressTotal: _step.stepsInPage,
              isPageEnd: _step.isPageEnd,
              onNext: _next,
              onSkip: _skip,
              onBack: _step.showBack ? _back : null,
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleChromeMeasurement() {
    if (_chromeMeasureScheduled) return;
    _chromeMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chromeMeasureScheduled = false;
      if (!mounted || _phase != _Phase.tour) return;
      final guideBox = _guideCardMeasureKey.currentContext?.findRenderObject();
      if (guideBox is! RenderBox || !guideBox.hasSize) return;
      final next = guideBox.size;
      final changed =
          _guideCardSize == null ||
          (next.height - _guideCardSize!.height).abs() > 0.5 ||
          (next.width - _guideCardSize!.width).abs() > 0.5;
      if (changed) setState(() => _guideCardSize = next);
    });
  }
}
