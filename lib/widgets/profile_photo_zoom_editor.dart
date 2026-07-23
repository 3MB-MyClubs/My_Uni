import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../services/app_colors.dart';
import '../services/locale_service.dart';
import '../services/photo_upload_quality.dart';

/// Opens the student-avatar editor used by Settings > Edit profile.
///
/// The crop surface supports drag, two-finger pinch zoom (up to 7x), and
/// double-tap zoom. It stays locked to a circular 1:1 preview so the saved
/// result matches the avatar shown throughout the app.
Future<Uint8List?> showProfilePhotoZoomEditor(
  BuildContext context,
  String sourcePath,
) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute<Uint8List>(
      fullscreenDialog: true,
      builder: (editorContext) {
        final editorTheme = profilePhotoEditorTheme(
          Theme.of(editorContext).brightness,
        );
        return CropRotateEditor.file(
          File(sourcePath),
          initConfigs: CropRotateEditorInitConfigs(
            theme: editorTheme,
            convertToUint8List: true,
            configs: profilePhotoZoomEditorConfigs(editorTheme),
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (bytes) async {
                if (editorContext.mounted) {
                  Navigator.of(editorContext).pop(bytes);
                }
              },
            ),
          ),
        );
      },
    ),
  );
}

ThemeData profilePhotoEditorTheme(Brightness brightness) {
  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF0C0608)
        : const Color(0xFFF8F5F6),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryRed,
      brightness: brightness,
    ),
  );
}

/// Public configuration keeps the zoom/crop contract regression-testable
/// without opening camera or gallery platform channels.
ProImageEditorConfigs profilePhotoZoomEditorConfigs(ThemeData editorTheme) {
  final isTurkish = localeService.languageCode == 'tr';
  return ProImageEditorConfigs(
    theme: editorTheme,
    i18n: I18n(
      cancel: isTurkish ? 'İptal' : 'Cancel',
      done: isTurkish ? 'Kullan' : 'Use',
      doneLoadingMsg: isTurkish
          ? 'Fotoğraf hazırlanıyor'
          : 'Preparing your photo',
      cropRotateEditor: I18nCropRotateEditor(
        bottomNavigationBarText: isTurkish
            ? 'Yakınlaştır ve kırp'
            : 'Zoom & crop',
        rotate: isTurkish ? 'Döndür' : 'Rotate',
        flip: isTurkish ? 'Yansıt' : 'Flip',
        back: isTurkish ? 'Geri' : 'Back',
        done: isTurkish ? 'Kullan' : 'Use',
        cancel: isTurkish ? 'İptal' : 'Cancel',
        undo: isTurkish ? 'Geri al' : 'Undo',
        redo: isTurkish ? 'İleri al' : 'Redo',
        reset: isTurkish ? 'Sıfırla' : 'Reset',
        smallScreenMoreTooltip: isTurkish ? 'Daha fazla' : 'More',
      ),
    ),
    cropRotateEditor: const CropRotateEditorConfigs(
      initialCropMode: CropMode.oval,
      initAspectRatio: 1,
      aspectRatios: [AspectRatioItem(text: '1:1', value: 1)],
      maxScale: 7,
      enableDoubleTap: true,
      doubleTapScaleFactor: 2,
      tools: [CropRotateTool.rotate, CropRotateTool.flip, CropRotateTool.reset],
    ),
    imageGeneration: const ImageGenerationConfigs(
      outputFormat: OutputFormat.jpg,
      jpegQuality: PhotoUploadQuality.jpegQuality,
      maxOutputSize: Size.square(PhotoUploadQuality.avatarMaxDimension * 1.0),
    ),
  );
}
