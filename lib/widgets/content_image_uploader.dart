import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../services/app_colors.dart';

/// A reusable photo-upload card used in post and event creation screens.
///
/// Shows an empty placeholder with camera/library hint when [imagePath] is null,
/// and a full-bleed preview with an X button and a "Change" pill when a photo
/// has been selected. Tapping anywhere on the card opens the bottom-sheet picker.
class ContentImageUploader extends StatefulWidget {
  final String? imagePath;
  final ValueChanged<String?> onChanged;
  final double height;

  const ContentImageUploader({
    super.key,
    required this.imagePath,
    required this.onChanged,
    this.height = 180,
  });

  @override
  State<ContentImageUploader> createState() => _ContentImageUploaderState();
}

class _ContentImageUploaderState extends State<ContentImageUploader> {
  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        IOSUiSettings(
          title: 'Crop Photo',
          resetAspectRatioEnabled: true,
          rotateButtonsHidden: false,
        ),
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.camera_alt_rounded,
                color: AppColors.primaryRed,
              ),
              title: Text(
                'Take a photo',
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
                'Choose from library',
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
                  'Remove photo',
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
    return GestureDetector(
      onTap: _showPickerSheet,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Change',
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
                    'Add cover photo (optional)',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to pick from camera or library',
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
