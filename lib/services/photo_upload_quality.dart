/// Shared output settings for user-uploaded photos.
///
/// The picker intentionally receives no quality or size constraints so the
/// cropper is the only lossy step in the pipeline. Re-encoding in both places
/// noticeably softens photos, even when each individual quality value is high.
abstract final class PhotoUploadQuality {
  /// Keeps post and event images sharp on high-density and large displays.
  static const int contentMaxDimension = 3840;

  /// More than enough detail for avatars, including full-screen viewing.
  static const int avatarMaxDimension = 1024;

  /// Visually near-lossless JPEG output without the extreme size cost of 100.
  static const int jpegQuality = 95;
}
