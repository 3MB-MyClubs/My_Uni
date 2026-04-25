import 'dart:io';
import 'package:flutter/material.dart';
import '../services/user_state.dart';
import '../services/app_colors.dart';

/// Shows a user's profile photo if they have one, otherwise their initial.
/// Used everywhere a user avatar appears so photo changes are visible app-wide.
class UserAvatar extends StatelessWidget {
  final String userId;
  final String name;
  final double size;
  final double fontSize;
  final Color? backgroundColor;
  final Color? textColor;
  final BorderRadius? borderRadius; // null = circle

  const UserAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.size = 40,
    this.fontSize = 16,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: userState,
      builder: (context, _) {
        final photoPath = userState.profilePhotoPaths[userId];
        final bg = backgroundColor ?? AppColors.lightRed;
        final fg = textColor ?? AppColors.primaryRed;
        final isCircle = borderRadius == null;

        if (photoPath != null) {
          final file = File(photoPath);
          // Guard: if the file was deleted (e.g. temp dir cleared), fall back.
          if (file.existsSync()) {
            return ClipRRect(
              borderRadius: isCircle
                  ? BorderRadius.circular(size / 2)
                  : borderRadius!,
              child: Image.file(
                file,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (ctx, e, st) => _initial(bg, fg, isCircle),
              ),
            );
          }
        }
        return _initial(bg, fg, isCircle);
      },
    );
  }

  Widget _initial(Color bg, Color fg, bool isCircle) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : borderRadius,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
      ),
    );
  }
}
