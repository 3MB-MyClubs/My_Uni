import 'dart:io';
import 'package:flutter/material.dart';
import '../services/user_state.dart';

/// Shows a club's profile photo if one has been set, otherwise falls back to
/// the first letter of the club name on a colored background.
///
/// Wraps itself in a [ListenableBuilder] so it rebuilds instantly when any
/// club admin changes their club photo — visible to all users app-wide.
///
/// [shape] — 'circle' | 'rounded' (default 'rounded')
class ClubAvatar extends StatelessWidget {
  final String clubId;
  final String clubName;
  final Color color;
  final double size;
  final double fontSize;
  final String shape; // 'circle' | 'rounded'
  final double borderRadius;

  const ClubAvatar({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.color,
    this.size = 48,
    this.fontSize = 20,
    this.shape = 'rounded',
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: userState,
      builder: (context, _) {
        final photoPath = userState.clubPhotoPaths[clubId];
        final file = photoPath != null ? File(photoPath) : null;
        final isCircle = shape == 'circle';

        if (file != null && file.existsSync()) {
          return ClipRRect(
            borderRadius: isCircle
                ? BorderRadius.circular(size / 2)
                : BorderRadius.circular(borderRadius),
            child: Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (ctx, e, st) => _initial(isCircle),
            ),
          );
        }
        return _initial(isCircle);
      },
    );
  }

  Widget _initial(bool isCircle) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          clubName.isNotEmpty ? clubName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
