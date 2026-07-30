import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/photo_file_cache.dart';
import '../services/user_state.dart';
import '../services/app_colors.dart';
import 'loading_skeleton.dart';
import 'profile_photo_viewer.dart';

/// Shows a user's profile photo if they have one, otherwise their initial.
/// Used everywhere a user avatar appears so photo changes are visible app-wide.
class UserAvatar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuilds when one of these three values actually changes for this
    // user, instead of on any unrelated UserState mutation app-wide.
    final avatarState = ref.watch(
      userStateProvider.select(
        (s) => (
          s.profilePhotoPaths[userId],
          s.mockPhotoUrls[userId],
          s.displayNameFor(userId, name),
          s.profilePhotoRevisionFor(userId),
        ),
      ),
    );
    final photoPath = avatarState.$1;
    final mockUrl = avatarState.$2;
    final displayName = avatarState.$3;
    final bg = backgroundColor ?? AppColors.lightRed;
    final fg = textColor ?? AppColors.primaryRed;
    final isCircle = borderRadius == null;
    final clip = isCircle
        ? BorderRadius.all(Radius.circular(size / 2))
        : borderRadius!;
    // Decode at the actual rendered size (accounting for screen density)
    // instead of the full uploaded resolution (up to 1024px for a ~40px
    // avatar slot).
    final decodeSize = (size * MediaQuery.devicePixelRatioOf(context)).round();

    // User-uploaded photo takes highest priority
    if (photoPath != null) {
      final file = File(photoPath);
      if (photoFileCache.existsSync(photoPath)) {
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
              image: ResizeImage(
                imageProvider,
                width: decodeSize,
                height: decodeSize,
              ),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (ctx, e, st) =>
                  _initial(bg, fg, isCircle, displayName),
            ),
          ),
        );
      }
    }

    // Fall back to mock network photo for demo users
    if (mockUrl != null) {
      final imageProvider = CachedNetworkImageProvider(mockUrl);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showProfilePhotoViewer(
          context: context,
          imageProvider: imageProvider,
        ),
        child: ClipRRect(
          borderRadius: clip,
          child: Image(
            image: ResizeImage(
              imageProvider,
              width: decodeSize,
              height: decodeSize,
            ),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, e, st) =>
                _initial(bg, fg, isCircle, displayName),
            loadingBuilder: (ctx, child, progress) =>
                progress == null ? child : _skeleton(isCircle),
          ),
        ),
      );
    }

    return _initial(bg, fg, isCircle, displayName);
  }

  Widget _initial(Color bg, Color fg, bool isCircle, String displayName) {
    if (displayName.trim().isEmpty) return _skeleton(isCircle);
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
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _skeleton(bool isCircle) {
    return SkeletonBox(
      width: size,
      height: size,
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: isCircle ? null : borderRadius,
    );
  }
}
