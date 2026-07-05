import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import 'loading_skeleton.dart';
import 'profile_photo_viewer.dart';

/// Shows a club's profile photo if one has been set, otherwise falls back to
/// the first letter of the club name on a colored background.
///
/// Rebuilds only when one of the specific UserState entries this club's
/// photo can come from actually changes, instead of on any unrelated
/// mutation app-wide.
///
/// [shape] — 'circle' | 'rounded' (default 'rounded')
class ClubAvatar extends ConsumerWidget {
  final String clubId;
  final String clubName;
  final Color color;
  final double size;
  final double fontSize;
  final String shape; // 'circle' | 'rounded'
  final double borderRadius;
  final String? imageUrl;
  final String? profilePhotoFallbackId;

  const ClubAvatar({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.color,
    this.size = 48,
    this.fontSize = 20,
    this.shape = 'rounded',
    this.borderRadius = 14,
    this.imageUrl,
    this.profilePhotoFallbackId,
  });

  // The set of profile ids (club + fallback + club admins) is fixed for a
  // given widget instance (it only depends on clubs/adminUserIds, not
  // UserState), so this resolves to the same two strings .select() would
  // otherwise need a variable-length dependency list for — records compare
  // by value, so .select() only fires when the resolved photo/fallback
  // actually changes, not on unrelated UserState mutations.
  (String?, String?) _selectPhoto(UserState s) {
    final profileIds = _profileIdsForClub();
    final photoPath =
        s.clubPhotoPaths[clubId] ??
        _firstValue(profileIds.map((id) => s.profilePhotoPaths[id]));
    final fallbackUrl = _firstNetworkImage([
      ...profileIds.map((id) => s.mockPhotoUrls[id]),
      s.mockClubPhotoUrls[clubId],
    ]);
    return (photoPath, fallbackUrl);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (photoPath, fallbackUrl) = ref.watch(
      userStateProvider.select(_selectPhoto),
    );
    final logoUrl = imageUrl?.trim();
    final isCircle = shape == 'circle';

    if (logoUrl != null && _isNetworkImage(logoUrl)) {
      return _photo(context, CachedNetworkImageProvider(logoUrl), isCircle);
    }

    if (photoPath != null && _isNetworkImage(photoPath)) {
      return _photo(context, CachedNetworkImageProvider(photoPath), isCircle);
    }

    final file = photoPath != null ? File(photoPath) : null;
    if (file != null && file.existsSync()) {
      return _photo(context, FileImage(file), isCircle);
    }

    if (fallbackUrl != null) {
      return _photo(context, CachedNetworkImageProvider(fallbackUrl), isCircle);
    }
    return _initial(isCircle);
  }

  bool _isNetworkImage(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  String? _firstNetworkImage(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      if (candidate != null && _isNetworkImage(candidate)) return candidate;
    }
    return null;
  }

  String? _firstValue(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    return null;
  }

  List<String> _profileIdsForClub() {
    final ids = <String>{?profilePhotoFallbackId, clubId};
    for (final club in clubs) {
      if (club.id != clubId) continue;
      ids.addAll(club.adminUserIds);
      break;
    }
    return ids.toList();
  }

  Widget _photo(
    BuildContext context,
    ImageProvider imageProvider,
    bool isCircle,
  ) {
    // Decode at the actual rendered size (accounting for screen density)
    // instead of the full uploaded resolution (up to 1920px for a ~48px
    // avatar slot). The full-resolution provider is kept for the tap-to-view
    // full-screen viewer below.
    final decodeSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showProfilePhotoViewer(
        context: context,
        imageProvider: imageProvider,
      ),
      child: ClipRRect(
        borderRadius: isCircle
            ? BorderRadius.all(Radius.circular(size / 2))
            : BorderRadius.all(Radius.circular(borderRadius)),
        child: Image(
          image: ResizeImage(
            imageProvider,
            width: decodeSize,
            height: decodeSize,
          ),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (ctx, e, st) => _initial(isCircle),
          loadingBuilder: (ctx, child, progress) =>
              progress == null ? child : _skeleton(isCircle),
        ),
      ),
    );
  }

  Widget _skeleton(bool isCircle) {
    return SkeletonBox(
      width: size,
      height: size,
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: isCircle
          ? null
          : BorderRadius.all(Radius.circular(borderRadius)),
    );
  }

  Widget _initial(bool isCircle) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle
            ? null
            : BorderRadius.all(Radius.circular(borderRadius)),
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
