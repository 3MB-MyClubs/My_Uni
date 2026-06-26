import 'package:flutter/material.dart';

import '../services/app_colors.dart';

/// Small theme-aware shimmer block for transient network/data loading.
///
/// Use this while Supabase/network content is still pending; keep normal
/// fallback UI for true errors so failures do not get hidden forever.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.margin,
    this.baseColor,
    this.highlightColor,
  });

  const SkeletonBox.circle({
    super.key,
    required double size,
    this.margin,
    this.baseColor,
    this.highlightColor,
  }) : width = size,
       height = size,
       borderRadius = null,
       shape = BoxShape.circle;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base =
        widget.baseColor ??
        Color.lerp(AppColors.surfaceAlt, AppColors.divider, 0.25)!;
    final highlight =
        widget.highlightColor ??
        Color.lerp(base, AppColors.card, 0.72)!.withValues(alpha: 0.95);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final x = -1.7 + (_controller.value * 3.4);
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : widget.borderRadius ?? BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(x, -0.35),
              end: Alignment(x + 1.0, 0.35),
              colors: [base, highlight, base],
              stops: const [0.18, 0.5, 0.82],
            ),
          ),
        );
      },
    );
  }
}
