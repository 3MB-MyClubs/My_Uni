import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/app_colors.dart';
import '../services/photo_file_cache.dart';
import 'user_avatar.dart';

class GroupAvatarStack extends StatelessWidget {
  final List<String> memberIds;
  final String Function(String userId) nameForUser;
  final String? photoPath;
  final double size;

  const GroupAvatarStack({
    super.key,
    required this.memberIds,
    required this.nameForUser,
    this.photoPath,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final photo = photoPath?.trim() ?? '';
    final isNetworkPhoto =
        photo.startsWith('http://') || photo.startsWith('https://');
    if (photo.isNotEmpty &&
        (isNetworkPhoto || photoFileCache.existsSync(photo))) {
      final provider = isNetworkPhoto
          ? CachedNetworkImageProvider(photo) as ImageProvider
          : FileImage(File(photo));
      final decodeSize = (size * MediaQuery.devicePixelRatioOf(context))
          .round();
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
          image: DecorationImage(
            image: ResizeImage(provider, width: decodeSize, height: decodeSize),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    final visible = memberIds.take(3).toList();
    if (visible.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(
          Icons.group_rounded,
          size: size * 0.48,
          color: AppColors.secondaryText,
        ),
      );
    }
    if (visible.length == 1) {
      return UserAvatar(
        userId: visible.first,
        name: nameForUser(visible.first),
        size: size,
        fontSize: size * 0.36,
      );
    }

    final avatarSize = size * 0.64;
    final positions = visible.length == 2
        ? <Offset>[Offset.zero, Offset(size - avatarSize, size - avatarSize)]
        : <Offset>[
            Offset((size - avatarSize) / 2, 0),
            Offset(0, size - avatarSize),
            Offset(size - avatarSize, size - avatarSize),
          ];

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: positions[index].dx,
              top: positions[index].dy,
              child: Container(
                padding: EdgeInsets.all(size * 0.025),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.background,
                    width: size * 0.025,
                  ),
                ),
                child: UserAvatar(
                  userId: visible[index],
                  name: nameForUser(visible[index]),
                  size: avatarSize - size * 0.05,
                  fontSize: avatarSize * 0.32,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
