import 'package:flutter/material.dart';

import '../theme/app_semantic_colors.dart';

enum MediaScrimPosition { top, bottom, full }

/// A paint-only media overlay. Place it above a photo/video and below its text.
/// The opaque end covers the text safe zone; it never samples the image or
/// changes color asynchronously.
class MediaScrim extends StatelessWidget {
  const MediaScrim({super.key, this.position = MediaScrimPosition.bottom});

  final MediaScrimPosition position;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final begin = switch (position) {
      MediaScrimPosition.top => Alignment.topCenter,
      MediaScrimPosition.bottom => Alignment.bottomCenter,
      MediaScrimPosition.full => Alignment.topCenter,
    };
    final end = switch (position) {
      MediaScrimPosition.top => Alignment.bottomCenter,
      MediaScrimPosition.bottom => Alignment.topCenter,
      MediaScrimPosition.full => Alignment.bottomCenter,
    };
    final gradientColors = position == MediaScrimPosition.full
        ? [colors.mediaScrim, colors.mediaScrim]
        : [
            colors.mediaScrim,
            colors.mediaScrim.withValues(alpha: 0.62),
            colors.mediaScrimSoft,
          ];
    final stops = position == MediaScrimPosition.full
        ? const [0.0, 1.0]
        : const [0.0, 0.42, 1.0];

    return IgnorePointer(
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const ValueKey('media-scrim-paint'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: gradientColors,
              stops: stops,
            ),
          ),
        ),
      ),
    );
  }
}
