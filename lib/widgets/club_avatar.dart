import 'dart:io';
import 'package:flutter/material.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import 'profile_photo_viewer.dart';

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: userState,
      builder: (context, _) {
        final profileIds = _profileIdsForClub();
        final photoPath =
            userState.clubPhotoPaths[clubId] ??
            _firstValue(
              profileIds.map((id) => userState.profilePhotoPaths[id]),
            );
        final fallbackUrl = _firstNetworkImage([
          imageUrl,
          ...profileIds.map((id) => userState.mockPhotoUrls[id]),
          userState.mockClubPhotoUrls[clubId],
        ]);
        final isCircle = shape == 'circle';

        if (photoPath != null && _isNetworkImage(photoPath)) {
          return _photo(context, NetworkImage(photoPath), isCircle);
        }

        final file = photoPath != null ? File(photoPath) : null;
        if (file != null && file.existsSync()) {
          return _photo(context, FileImage(file), isCircle);
        }

        if (fallbackUrl != null) {
          return _photo(context, NetworkImage(fallbackUrl), isCircle);
        }
        return _initial(isCircle);
      },
    );
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showProfilePhotoViewer(
        context: context,
        imageProvider: imageProvider,
      ),
      child: ClipRRect(
        borderRadius: isCircle
            ? BorderRadius.circular(size / 2)
            : BorderRadius.circular(borderRadius),
        child: Image(
          image: imageProvider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (ctx, e, st) => _initial(isCircle),
        ),
      ),
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
