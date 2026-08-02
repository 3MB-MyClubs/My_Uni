import 'package:flutter/material.dart';

/// Consistent pressed-state feedback for custom controls that cannot use a
/// Material button or [InkWell].
///
/// The response is intentionally subtle: the control compresses immediately
/// under the finger, then settles back with a softer release. System reduced-
/// motion preferences are respected.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.opaque,
    this.pressedScale = 0.97,
    this.pressedOpacity = 0.92,
  });

  final Widget child;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final HitTestBehavior behavior;
  final double pressedScale;
  final double pressedOpacity;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion
        ? Duration.zero
        : _pressed
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 180);
    final curve = _pressed ? Curves.easeOutCubic : Curves.easeOutBack;

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: duration,
          curve: curve,
          child: AnimatedOpacity(
            opacity: _pressed ? widget.pressedOpacity : 1,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
