import 'dart:io';
import 'package:flutter/material.dart';
import '../services/user_state.dart';
import '../services/app_colors.dart';
import 'profile_photo_viewer.dart';

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
        final mockUrl = userState.mockPhotoUrls[userId];
        final bg = backgroundColor ?? AppColors.lightRed;
        final fg = textColor ?? AppColors.primaryRed;
        final isCircle = borderRadius == null;
        final clip = isCircle ? BorderRadius.circular(size / 2) : borderRadius!;

        // User-uploaded photo takes highest priority
        if (photoPath != null) {
          final file = File(photoPath);
          if (file.existsSync()) {
            final imageProvider = FileImage(file);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showProfilePhotoViewer(
                context: context,
                imageProvider: imageProvider,
              ),
              child: ClipRRect(
                borderRadius: clip,
                child: Image(
                  image: imageProvider,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, e, st) => _initial(bg, fg, isCircle),
                ),
              ),
            );
          }
        }

        // Fall back to mock network photo for demo users
        if (mockUrl != null) {
          final imageProvider = NetworkImage(mockUrl);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showProfilePhotoViewer(
              context: context,
              imageProvider: imageProvider,
            ),
            child: ClipRRect(
              borderRadius: clip,
              child: Image(
                image: imageProvider,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (ctx, e, st) => _initial(bg, fg, isCircle),
                loadingBuilder: (ctx, child, progress) =>
                    progress == null ? child : _initial(bg, fg, isCircle),
              ),
            ),
          );
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
        child: Builder(
          builder: (context) {
            final display = userState.displayNameFor(userId, name);
            return Text(
              display.isNotEmpty ? display[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            );
          },
        ),
      ),
    );
  }
}
