import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_colors.dart';
import 'group_avatar_stack.dart';
import 'group_photo_editor.dart';

typedef GroupPhotoSourcePicker = Future<String?> Function(ImageSource source);
typedef GroupPhotoEditorLauncher =
    Future<String?> Function(BuildContext context, String sourcePath);

class GroupPhotoPicker extends StatelessWidget {
  final String? imagePath;
  final List<String> memberIds;
  final String Function(String userId) nameForUser;
  final ValueChanged<String?> onChanged;
  final double size;
  final GroupPhotoSourcePicker? sourcePicker;
  final GroupPhotoEditorLauncher editorLauncher;

  const GroupPhotoPicker({
    super.key,
    required this.imagePath,
    required this.memberIds,
    required this.nameForUser,
    required this.onChanged,
    this.size = 88,
    this.sourcePicker,
    this.editorLauncher = showGroupPhotoEditor,
  });

  Future<void> _pickPhoto(BuildContext context, ImageSource source) async {
    try {
      final selectedPath = sourcePicker != null
          ? await sourcePicker!(source)
          : (await ImagePicker().pickImage(source: source))?.path;
      if (selectedPath == null || !context.mounted) return;

      final editedPath = await editorLauncher(context, selectedPath);
      if (editedPath != null && context.mounted) onChanged(editedPath);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not open the photo editor.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: SafeArea(
          top: false,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Group photo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                ListTile(
                  key: const ValueKey('group-photo-camera'),
                  leading: Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.primaryRed,
                  ),
                  title: Text(
                    'Take a photo',
                    style: TextStyle(color: AppColors.text),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickPhoto(context, ImageSource.camera);
                  },
                ),
                ListTile(
                  key: const ValueKey('group-photo-library'),
                  leading: Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primaryRed,
                  ),
                  title: Text(
                    'Choose from library',
                    style: TextStyle(color: AppColors.text),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickPhoto(context, ImageSource.gallery);
                  },
                ),
                if ((imagePath?.trim() ?? '').isNotEmpty)
                  ListTile(
                    key: const ValueKey('group-photo-remove'),
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Remove photo',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onChanged(null);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: imagePath == null ? 'Add group photo' : 'Change group photo',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GroupAvatarStack(
              memberIds: memberIds,
              nameForUser: nameForUser,
              photoPath: imagePath,
              size: size,
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const ValueKey('group-photo-picker'),
                  customBorder: const CircleBorder(),
                  onTap: () => _showPicker(context),
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: IgnorePointer(
                child: Container(
                  width: size * 0.34,
                  height: size * 0.34,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 3),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
