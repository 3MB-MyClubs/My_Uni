import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event.dart';
import '../services/app_colors.dart';
import '../services/mock_data.dart';
import '../services/photo_file_cache.dart';
import '../services/user_state.dart';
import 'app_network_image.dart';
import 'loading_skeleton.dart';

class EventCoverImage extends ConsumerWidget {
  final Event event;
  final Color color;
  final double? width;
  final double? height;
  final double? cacheWidth;
  final double? cacheHeight;
  final BoxFit fit;
  final BorderRadiusGeometry borderRadius;

  const EventCoverImage({
    super.key,
    required this.event,
    required this.color,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (clubPhotoPath, fallbackUrl) = ref.watch(
      userStateProvider.select(_selectClubCoverPhoto),
    );
    final path = _firstUsablePath([
      event.imagePath,
      clubPhotoPath,
      fallbackUrl,
    ]);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalCacheWidth =
        cacheWidth ?? (width != null && width!.isFinite ? width : null);
    final logicalCacheHeight =
        cacheHeight ?? (height != null && height!.isFinite ? height : null);

    final child = path == null
        ? _EventCoverFallback(color: color)
        : _isRemote(path)
        ? AppNetworkImage(
            url: path,
            width: width,
            height: height,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            fit: fit,
            placeholderBuilder: (_) => const SkeletonBox(),
            errorBuilder: (_) => _EventCoverFallback(color: color),
          )
        : Image.file(
            File(path),
            width: width,
            height: height,
            cacheWidth: logicalCacheWidth == null
                ? null
                : (logicalCacheWidth * dpr).round(),
            cacheHeight: logicalCacheHeight == null
                ? null
                : (logicalCacheHeight * dpr).round(),
            fit: fit,
            errorBuilder: (_, _, _) => _EventCoverFallback(color: color),
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: width, height: height, child: child),
    );
  }

  bool _isRemote(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  String? _firstUsablePath(Iterable<String?> paths) {
    for (final raw in paths) {
      final path = raw?.trim() ?? '';
      if (path.isEmpty) continue;
      if (_isRemote(path) || photoFileCache.existsSync(path)) return path;
    }
    return null;
  }

  (String?, String?) _selectClubCoverPhoto(UserState state) {
    final club = clubForId(event.clubId);
    final profileIds = <String>{event.clubId, ...?club?.adminUserIds};
    final clubPhotoPath =
        state.clubPhotoPaths[event.clubId] ??
        _firstValue(profileIds.map((id) => state.profilePhotoPaths[id]));
    final fallbackUrl = _firstNetworkImage([
      club?.logoUrl,
      ...profileIds.map((id) => state.remotePhotoUrls[id]),
      state.remoteClubPhotoUrls[event.clubId],
    ]);
    return (clubPhotoPath, fallbackUrl);
  }

  String? _firstValue(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  String? _firstNetworkImage(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty && _isRemote(value)) return value;
    }
    return null;
  }
}

class _EventCoverFallback extends StatelessWidget {
  final Color color;

  const _EventCoverFallback({required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.92),
            AppColors.primaryRed.withValues(alpha: 0.68),
            AppColors.darkRed.withValues(alpha: 0.78),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -20,
            child: Icon(
              Icons.event_rounded,
              size: 112,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: Icon(
              Icons.photo_camera_back_rounded,
              size: 34,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}
