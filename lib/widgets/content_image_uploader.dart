import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/app_colors.dart';
import '../services/photo_upload_quality.dart';

/// A reusable photo-upload card used in post and event creation screens.
///
/// Shows an empty placeholder with camera/library hint when [imagePath] is null,
/// and a full-bleed preview with an X button and a "Change" pill when a photo
/// has been selected. Tapping anywhere on the card opens the bottom-sheet picker.
class ContentImageUploader extends StatefulWidget {
  final String? imagePath;
  final ValueChanged<String?> onChanged;
  final double height;

  /// Falls back to a localized default when not provided.
  final String? emptyTitle;

  /// Falls back to a localized default when not provided.
  final String? emptySubtitle;

  /// When true, the empty state is a small "add photo" button instead of a
  /// large tap area. The full-bleed preview is still shown once a photo is
  /// selected. Defaults to the original large placeholder.
  final bool compact;

  const ContentImageUploader({
    super.key,
    required this.imagePath,
    required this.onChanged,
    this.height = 180,
    this.emptyTitle,
    this.emptySubtitle,
    this.compact = false,
  });

  @override
  State<ContentImageUploader> createState() => _ContentImageUploaderState();
}

class _ContentImageUploaderState extends State<ContentImageUploader> {
  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;
    final cropPhotoTitle = AppLocalizations.of(context)!.cropPhoto;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: PhotoUploadQuality.contentMaxDimension,
      maxHeight: PhotoUploadQuality.contentMaxDimension,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: PhotoUploadQuality.jpegQuality,
      uiSettings: [
        IOSUiSettings(
          title: cropPhotoTitle,
          resetAspectRatioEnabled: true,
          rotateButtonsHidden: false,
        ),
        AndroidUiSettings(
          toolbarTitle: cropPhotoTitle,
          toolbarColor: AppColors.primaryRed,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
          showCropGrid: true,
        ),
      ],
    );
    if (cropped != null && mounted) widget.onChanged(cropped.path);
  }

  void _showPickerSheet() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.camera_alt_rounded,
                color: AppColors.primaryRed,
              ),
              title: Text(
                l10n.takePhoto,
                style: TextStyle(color: AppColors.text),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_rounded,
                color: AppColors.primaryRed,
              ),
              title: Text(
                l10n.chooseFromLib,
                style: TextStyle(color: AppColors.text),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (widget.imagePath != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  l10n.removePhoto,
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onChanged(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final emptyTitle = widget.emptyTitle ?? l10n.addCoverPhotoOptional;
    final emptySubtitle = widget.emptySubtitle ?? l10n.tapToPickPhotoHint;

    // Compact empty state — a small button rather than a large tap target.
    if (widget.compact && widget.imagePath == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: _showPickerSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.all(Radius.circular(12)),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 20,
                  color: AppColors.primaryRed,
                ),
                const SizedBox(width: 8),
                Text(
                  emptyTitle,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _showPickerSheet,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.imagePath != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(widget.imagePath!), fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => widget.onChanged(null),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            l10n.changeLabel,
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 36,
                    color: AppColors.secondaryText.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptyTitle,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emptySubtitle,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
