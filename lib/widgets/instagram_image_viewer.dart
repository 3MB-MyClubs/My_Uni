import 'package:flutter/material.dart';

/// Opens [imageProvider] in a full-screen, Instagram-style viewer with a
/// hero flight from the tapped thumbnail, pinch/double-tap zoom, panning
/// while zoomed, and swipe-down-to-dismiss.
Future<void> showInstagramImageViewer(
  BuildContext context, {
  required ImageProvider imageProvider,
  required Object heroTag,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: _InstagramImageViewer(
            imageProvider: imageProvider,
            heroTag: heroTag,
          ),
        );
      },
    ),
  );
}

class _InstagramImageViewer extends StatefulWidget {
  final ImageProvider imageProvider;
  final Object heroTag;

  const _InstagramImageViewer({
    required this.imageProvider,
    required this.heroTag,
  });

  @override
  State<_InstagramImageViewer> createState() => _InstagramImageViewerState();
}

enum _AnimTarget { zoom, dismissSpring }

class _InstagramImageViewerState extends State<_InstagramImageViewer>
    with SingleTickerProviderStateMixin {
  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;
  static const double _doubleTapScale = 2.5;
  static const double _dismissThreshold = 120;
  static const double _dismissVelocity = 700;

  // Pinch-zoom / pan state (image space).
  double _scale = _minScale;
  Offset _offset = Offset.zero;
  double _previousScale = _minScale;
  Offset _previousOffset = Offset.zero;
  Offset _startingFocalPoint = Offset.zero;

  // Swipe-to-dismiss state.
  Offset _dismissOffset = Offset.zero;
  bool? _gestureIsDismiss;

  Size _viewportSize = Size.zero;
  TapDownDetails? _doubleTapDetails;

  // Single reusable controller drives both the zoom-snap and the
  // dismiss-spring-back animations — avoids creating/disposing a fresh
  // AnimationController per gesture, which raced (double-dispose) when a
  // new animation started before the previous one's completion callback ran.
  late final AnimationController _animController;
  late final Animation<double> _animCurve;
  _AnimTarget? _activeAnim;
  Tween<double> _scaleTween = Tween(begin: _minScale, end: _minScale);
  Tween<Offset> _offsetTween = Tween(begin: Offset.zero, end: Offset.zero);
  Tween<Offset> _dismissTween = Tween(begin: Offset.zero, end: Offset.zero);

  bool get _isZoomed => _scale > _minScale + 0.01;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animCurve = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animCurve.addListener(() {
      setState(() {
        if (_activeAnim == _AnimTarget.zoom) {
          _scale = _scaleTween.transform(_animCurve.value);
          _offset = _offsetTween.transform(_animCurve.value);
        } else if (_activeAnim == _AnimTarget.dismissSpring) {
          _dismissOffset = _dismissTween.transform(_animCurve.value);
        }
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _animController.stop();
    _previousScale = _scale;
    _previousOffset = _offset;
    _startingFocalPoint = details.focalPoint;
    _gestureIsDismiss = _isZoomed ? false : null;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _gestureIsDismiss ??= details.pointerCount == 1 ? true : false;

    if (_gestureIsDismiss == true) {
      setState(() {
        final dy = details.focalPointDelta.dy;
        final resisted = _dismissOffset.dy < 0 || dy < 0 ? dy * 0.5 : dy;
        _dismissOffset += Offset(details.focalPointDelta.dx, resisted);
      });
      return;
    }

    final newScale = (_previousScale * details.scale).clamp(
      _minScale,
      _maxScale,
    );
    final normalizedOffset =
        (_startingFocalPoint - _previousOffset) / _previousScale;
    var newOffset = details.focalPoint - normalizedOffset * newScale;
    newOffset = _clampOffset(newOffset, newScale);
    setState(() {
      _scale = newScale;
      _offset = newOffset;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_gestureIsDismiss == true) {
      final velocity = details.velocity.pixelsPerSecond.dy;
      if (_dismissOffset.dy > _dismissThreshold ||
          velocity > _dismissVelocity) {
        Navigator.of(context).pop();
      } else {
        _animateDismissOffsetTo(Offset.zero);
      }
      _gestureIsDismiss = null;
      return;
    }

    if (_scale <= _minScale + 0.01) {
      _animateZoomTo(scale: _minScale, offset: Offset.zero);
    }
  }

  Offset _clampOffset(Offset offset, double scale) {
    if (_viewportSize == Size.zero) return offset;
    final maxX = (_viewportSize.width * (scale - 1)) / 2;
    final maxY = (_viewportSize.height * (scale - 1)) / 2;
    return Offset(offset.dx.clamp(-maxX, maxX), offset.dy.clamp(-maxY, maxY));
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _animateZoomTo(scale: _minScale, offset: Offset.zero);
      return;
    }
    final tapPosition = _doubleTapDetails?.localPosition ?? Offset.zero;
    final viewportCenter = Offset(
      _viewportSize.width / 2,
      _viewportSize.height / 2,
    );
    final focal = tapPosition - viewportCenter;
    final targetOffset = _clampOffset(
      -focal * (_doubleTapScale - 1),
      _doubleTapScale,
    );
    _animateZoomTo(scale: _doubleTapScale, offset: targetOffset);
  }

  void _animateZoomTo({required double scale, required Offset offset}) {
    _scaleTween = Tween<double>(begin: _scale, end: scale);
    _offsetTween = Tween<Offset>(begin: _offset, end: offset);
    _activeAnim = _AnimTarget.zoom;
    _animController.forward(from: 0);
  }

  void _animateDismissOffsetTo(Offset target) {
    _dismissTween = Tween<Offset>(begin: _dismissOffset, end: target);
    _activeAnim = _AnimTarget.dismissSpring;
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final dragDistance = _dismissOffset.dy.abs();
    final dragProgress = (dragDistance / 300).clamp(0.0, 1.0);
    final backdropOpacity = 1 - dragProgress;
    final imageScale = (1 - dragProgress * 0.25).clamp(0.75, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: backdropOpacity),
              ),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewportSize = constraints.biggest;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  onDoubleTapDown: _handleDoubleTapDown,
                  onDoubleTap: _handleDoubleTap,
                  child: Transform.translate(
                    offset: _dismissOffset,
                    child: Transform.scale(
                      scale: imageScale,
                      child: Center(
                        child: Hero(
                          tag: widget.heroTag,
                          child: Transform(
                            transform: Matrix4.identity()
                              ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                              ..scaleByDouble(_scale, _scale, 1, 1),
                            alignment: Alignment.center,
                            child: Image(
                              image: widget.imageProvider,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white70,
                                    strokeWidth: 2.4,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.white54,
                                      size: 40,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Opacity(
              opacity: backdropOpacity,
              child: _CloseButton(onTap: () => Navigator.of(context).pop()),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.close, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
