import 'dart:math' as math;

import 'package:flutter/material.dart';

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

class _AppTutorialOverlayState extends State<AppTutorialOverlay> {
  int _index = 0;
  Rect? _targetRect;

  AppTutorialStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStepChanged(_step);
      _measureTarget();
    });
  }

  void _measureTarget() {
    if (!mounted) return;
    final context = _step.targetKey?.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      if (_targetRect != null) setState(() => _targetRect = null);
      return;
    }

    final origin = renderObject.localToGlobal(Offset.zero);
    final rect = (origin & renderObject.size).inflate(6);
    if (_targetRect != rect) setState(() => _targetRect = rect);
  }

  void _moveTo(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= widget.steps.length) return;
    setState(() {
      _index = nextIndex;
      _targetRect = null;
    });
    widget.onStepChanged(widget.steps[nextIndex]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLast = _index == widget.steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          final target = _visibleTarget(screenSize);

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _TutorialSpotlightPainter(target)),
              ),
              if (target != null)
                Positioned.fromRect(
                  rect: target,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withValues(alpha: 0.5),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: media.padding.top + 10,
                right: 14,
                child: SafeArea(
                  bottom: false,
                  child: TextButton(
                    onPressed: widget.onSkip,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Skip tour',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              _buildTutorialCard(context, screenSize, target, isLast),
            ],
          );
        },
      ),
    );
  }

  Rect? _visibleTarget(Size screenSize) {
    final target = _targetRect;
    if (target == null) return null;
    final screen = Offset.zero & screenSize;
    final visible = target.intersect(screen);
    if (visible.width < 8 || visible.height < 8) return null;
    return visible;
  }

  Widget _buildTutorialCard(
    BuildContext context,
    Size screenSize,
    Rect? target,
    bool isLast,
  ) {
    const margin = 16.0;
    final maxCardHeight = math.min(390.0, screenSize.height * 0.57);
    final card = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxCardHeight),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.lightRed,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      _step.icon,
                      color: AppColors.primaryRed,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _step.eyebrow.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primaryRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
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
                  Text(
                    '${_index + 1}/${widget.steps.length}',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _step.description,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (_step.tips.isNotEmpty) ...[
                const SizedBox(height: 14),
                ..._step.tips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
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
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: (_index + 1) / widget.steps.length,
                  minHeight: 4,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryRed,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_index > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _moveTo(_index - 1),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (_index > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isLast
                          ? widget.onComplete
                          : () => _moveTo(_index + 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: Text(
                        isLast ? 'Start exploring' : 'Next',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondaryText,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Skip tour',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (target == null) {
      return Positioned(
        left: margin,
        right: margin,
        top: math.max(
          mediaTop(context) + 70,
          (screenSize.height - maxCardHeight) / 2,
        ),
        child: card,
      );
    }

    final isLargeTarget = target.height > screenSize.height * 0.45;
    if (isLargeTarget || target.center.dy > screenSize.height * 0.58) {
      final bottom = isLargeTarget
          ? math.max(94.0, MediaQuery.paddingOf(context).bottom + 86)
          : screenSize.height - target.top + 14;
      return Positioned(
        left: margin,
        right: margin,
        bottom: bottom,
        child: card,
      );
    }

    return Positioned(
      left: margin,
      right: margin,
      top: math.min(target.bottom + 14, screenSize.height - maxCardHeight - 16),
      child: card,
    );
  }

  double mediaTop(BuildContext context) => MediaQuery.paddingOf(context).top;
}

class _TutorialSpotlightPainter extends CustomPainter {
  final Rect? target;

  const _TutorialSpotlightPainter(this.target);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(
      bounds,
      Paint()..color = Colors.black.withValues(alpha: 0.68),
    );

    if (target != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(18)),
        Paint()..blendMode = BlendMode.clear,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TutorialSpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}
