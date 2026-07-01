import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Instagram-style, in-place pinch-to-zoom for any [child] (typically an image).
///
/// Placing two fingers on the child zooms it around the gesture's focal point
/// and lets it pan as the fingers move. The zoomed content is lifted into the
/// root [Overlay] so it floats above surrounding UI (feed cards, etc.). As soon
/// as the pinch ends (a finger lifts), the content smoothly animates back to its
/// original scale and position — it is never left zoomed.
///
/// Vertical scrolling of an enclosing list is only suppressed while an actual
/// two-finger pinch is in progress: single-finger drags fall through to the
/// scrollable, and single-finger taps fall through to ancestor tap handlers.
class PinchZoomImage extends StatefulWidget {
  final Widget child;

  /// Maximum magnification relative to the on-screen size of [child].
  final double maxScale;

  const PinchZoomImage({super.key, required this.child, this.maxScale = 3.0});

  @override
  State<PinchZoomImage> createState() => _PinchZoomImageState();
}

class _PinchZoomImageState extends State<PinchZoomImage>
    with SingleTickerProviderStateMixin {
  final GlobalKey _childKey = GlobalKey();

  OverlayEntry? _overlay;
  bool _childHidden = false;
  bool _pinching = false;

  // Geometry of the child at gesture start (global / screen coordinates).
  Offset _origin = Offset.zero;
  Size _size = Size.zero;

  // Gesture anchor.
  Offset _startFocalGlobal = Offset.zero;
  Offset _startFocalLocal = Offset.zero;

  // Live transform state, read by the overlay builder.
  Matrix4 _matrix = Matrix4.identity();
  double _backdrop = 0;

  // Snap-back animation.
  late final AnimationController _reset;
  late final Animation<double> _resetCurve;
  Matrix4Tween _resetTween = Matrix4Tween(
    begin: Matrix4.identity(),
    end: Matrix4.identity(),
  );
  double _resetBackdropStart = 0;

  @override
  void initState() {
    super.initState();
    _reset = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _resetCurve = CurvedAnimation(parent: _reset, curve: Curves.easeOutCubic);
    _resetCurve.addListener(() {
      final t = _resetCurve.value;
      _matrix = _resetTween.transform(t);
      _backdrop = _resetBackdropStart * (1 - t);
      _overlay?.markNeedsBuild();
    });
    _reset.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finishPinch();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _reset.dispose();
    super.dispose();
  }

  // ── Gesture handlers ─────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    if (d.pointerCount < 2) return;
    _startPinch(d.focalPoint);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return;
    if (!_pinching) _startPinch(d.focalPoint);
    if (!_pinching) return; // measurement failed
    _applyPinch(d);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (!_pinching) return;
    _pinching = false;
    _animateBack();
  }

  // ── Pinch lifecycle ──────────────────────────────────────────────────────

  void _startPinch(Offset focalGlobal) {
    final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    _reset.stop();
    _origin = box.localToGlobal(Offset.zero);
    _size = box.size;
    _startFocalGlobal = focalGlobal;
    _startFocalLocal = focalGlobal - _origin;
    _matrix = Matrix4.identity();
    _backdrop = 0;
    _pinching = true;

    if (_overlay == null) {
      final overlay = Overlay.of(context, rootOverlay: true);
      _overlay = OverlayEntry(builder: _buildOverlay);
      overlay.insert(_overlay!);
    } else {
      _overlay!.markNeedsBuild();
    }
    if (!_childHidden) setState(() => _childHidden = true);
  }

  void _applyPinch(ScaleUpdateDetails d) {
    final scale = d.scale.clamp(1.0, widget.maxScale);
    final pan = d.focalPoint - _startFocalGlobal;

    // Zoom about the initial focal point, then follow the fingers' movement.
    _matrix = Matrix4.identity()
      ..translateByDouble(pan.dx, pan.dy, 0, 1)
      ..translateByDouble(_startFocalLocal.dx, _startFocalLocal.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-_startFocalLocal.dx, -_startFocalLocal.dy, 0, 1);
    _backdrop = ((scale - 1) / (widget.maxScale - 1)).clamp(0.0, 1.0) * 0.75;
    _overlay?.markNeedsBuild();
  }

  void _animateBack() {
    _resetTween = Matrix4Tween(begin: _matrix, end: Matrix4.identity());
    _resetBackdropStart = _backdrop;
    _reset.forward(from: 0);
  }

  void _finishPinch() {
    _removeOverlay();
    if (mounted && _childHidden) setState(() => _childHidden = false);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  // ── Overlay ──────────────────────────────────────────────────────────────

  Widget _buildOverlay(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: _backdrop,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
          Positioned(
            left: _origin.dx,
            top: _origin.dy,
            width: _size.width,
            height: _size.height,
            child: Transform(
              transform: _matrix,
              filterQuality: FilterQuality.medium,
              child: RepaintBoundary(child: widget.child),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.deferToChild,
      gestures: {
        _PinchScaleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_PinchScaleGestureRecognizer>(
              () => _PinchScaleGestureRecognizer(debugOwner: this),
              (r) => r
                ..onStart = _onScaleStart
                ..onUpdate = _onScaleUpdate
                ..onEnd = _onScaleEnd,
            ),
      },
      child: Opacity(
        // Keep the slot occupied (layout unchanged) while the overlay shows the
        // lifted copy, so the feed doesn't reflow during a pinch.
        opacity: _childHidden ? 0.0 : 1.0,
        child: KeyedSubtree(key: _childKey, child: widget.child),
      ),
    );
  }
}

/// A [ScaleGestureRecognizer] that only engages for genuine two-finger pinches.
///
/// Single-finger moves are ignored (so an enclosing scrollable keeps them) and
/// single-finger taps/lifts bow out of the gesture arena (so ancestor tap and
/// double-tap handlers still fire). Only once two fingers are active does it
/// compete — and win — claiming the pointers away from vertical scrolling.
class _PinchScaleGestureRecognizer extends ScaleGestureRecognizer {
  _PinchScaleGestureRecognizer({super.debugOwner});

  bool _hadTwoFingers = false;
  bool _claimed = false;

  @override
  void handleEvent(PointerEvent event) {
    if (pointerCount >= 2) {
      _hadTwoFingers = true;
      // A two-finger gesture is always a pinch, never a scroll. Claim the arena
      // as soon as the fingers move so the enclosing scrollable can't steal a
      // two-finger drag — this makes pinch mode (and the scroll lock) engage
      // immediately, even before the fingers spread to zoom.
      if (!_claimed && event is PointerMoveEvent) {
        _claimed = true;
        resolve(GestureDisposition.accepted);
      }
    }

    if (!_hadTwoFingers) {
      if (event is PointerMoveEvent) {
        // Single-finger drag → let the enclosing scrollable have it.
        return;
      }
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        // Single-finger tap/lift → leave the arena so tap handlers win.
        resolve(GestureDisposition.rejected);
      }
    }
    super.handleEvent(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _hadTwoFingers = false;
    _claimed = false;
    super.didStopTrackingLastPointer(pointer);
  }
}
