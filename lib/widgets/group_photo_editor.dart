import 'dart:io';

import 'package:cropme/cropme.dart' as cropme;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../services/app_colors.dart';
import '../services/locale_service.dart';
import '../services/photo_upload_quality.dart';

/// Opens the full group-photo editor and returns a durable local JPEG path.
///
/// The first screen is a touch-first cropper where users can drag, pinch and
/// twist with two fingers to freely tilt the photo. The creative editor then
/// provides filters, adjustments, drawing, text and emoji.
Future<String?> showGroupPhotoEditor(
  BuildContext context,
  String sourcePath,
) async {
  final sourceBytes = await File(sourcePath).readAsBytes();
  if (!context.mounted) return null;
  final touchCrop = await cropme.ImageCropper.show(
    context: context,
    imageBytes: sourceBytes,
    theme: groupPhotoTiltTheme(),
  );
  if (touchCrop == null || !context.mounted) return null;

  final temporaryDirectory = await getTemporaryDirectory();
  final touchCropFile = File(
    '${temporaryDirectory.path}/group_photo_tilt_'
    '${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await touchCropFile.writeAsBytes(touchCrop.bytes, flush: true);
  if (!context.mounted) {
    await touchCropFile.delete();
    return null;
  }

  try {
    return await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (editorContext) => ProImageEditor.file(
          touchCropFile,
          configs: groupPhotoEditorConfigs(),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              final documents = await getApplicationDocumentsDirectory();
              final directory = Directory('${documents.path}/group_photos');
              await directory.create(recursive: true);
              final file = File(
                '${directory.path}/group_photo_'
                '${DateTime.now().microsecondsSinceEpoch}.jpg',
              );
              await file.writeAsBytes(bytes, flush: true);
              if (editorContext.mounted) {
                Navigator.of(editorContext).pop(file.path);
              }
            },
          ),
        ),
      ),
    );
  } finally {
    try {
      if (await touchCropFile.exists()) await touchCropFile.delete();
    } catch (_) {
      // Temporary-file cleanup must never discard an otherwise valid result.
    }
  }
}

/// Theme for the touch positioning step. Cropme supplies both two-finger
/// rotation and a precision rotation trackbar; these labels follow app locale.
cropme.CropperThemeData groupPhotoTiltTheme() {
  final isTurkish = localeService.languageCode == 'tr';
  return cropme.CropperThemeData(
    backgroundColor: const Color(0xFF0C0608),
    accentColor: AppColors.primaryRed,
    cropButtonColor: AppColors.primaryRed,
    cropButtonTextColor: Colors.white,
    resetLabel: isTurkish ? 'Sıfırla' : 'Reset',
    cropLabel: isTurkish ? 'Fotoğrafı kullan' : 'Use photo',
  );
}

/// Shared configuration kept public so the editor contract can be regression
/// tested without invoking camera/gallery platform channels.
ProImageEditorConfigs groupPhotoEditorConfigs() {
  final isTurkish = localeService.languageCode == 'tr';
  final editorTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0C0608),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryRed,
      brightness: Brightness.dark,
    ),
  );

  return ProImageEditorConfigs(
    theme: editorTheme,
    i18n: I18n(
      cancel: isTurkish ? 'İptal' : 'Cancel',
      done: isTurkish ? 'Bitti' : 'Done',
      undo: isTurkish ? 'Geri al' : 'Undo',
      redo: isTurkish ? 'İleri al' : 'Redo',
      remove: isTurkish ? 'Kaldır' : 'Remove',
      doneLoadingMsg: isTurkish
          ? 'Düzenlemeler uygulanıyor'
          : 'Applying your edits',
      various: I18nVarious(
        closeEditorWarningTitle: isTurkish
            ? 'Fotoğraf düzenleyici kapatılsın mı?'
            : 'Close photo editor?',
        closeEditorWarningMessage: isTurkish
            ? 'Kaydedilmemiş düzenlemelerin kaybolacak.'
            : 'Your unsaved edits will be lost.',
        closeEditorWarningConfirmBtn: isTurkish ? 'Kapat' : 'Close',
        closeEditorWarningCancelBtn: isTurkish ? 'İptal' : 'Cancel',
      ),
      cropRotateEditor: I18nCropRotateEditor(
        bottomNavigationBarText: isTurkish ? 'Kırp' : 'Crop',
      ),
      tuneEditor: I18nTuneEditor(
        bottomNavigationBarText: isTurkish ? 'Ayarla' : 'Adjust',
      ),
      filterEditor: I18nFilterEditor(
        bottomNavigationBarText: isTurkish ? 'Filtre' : 'Filter',
      ),
      paintEditor: I18nPaintEditor(
        bottomNavigationBarText: isTurkish ? 'Çiz' : 'Draw',
      ),
      textEditor: I18nTextEditor(
        bottomNavigationBarText: isTurkish ? 'Metin' : 'Text',
      ),
      emojiEditor: I18nEmojiEditor(
        bottomNavigationBarText: isTurkish ? 'Emoji' : 'Emoji',
      ),
    ),
    mainEditor: const MainEditorConfigs(
      tools: [
        SubEditorMode.cropRotate,
        SubEditorMode.tune,
        SubEditorMode.filter,
        SubEditorMode.paint,
        SubEditorMode.text,
        SubEditorMode.emoji,
      ],
    ),
    cropRotateEditor: const CropRotateEditorConfigs(
      initAspectRatio: 1,
      aspectRatios: [AspectRatioItem(text: '1:1', value: 1)],
      tools: [CropRotateTool.rotate, CropRotateTool.flip, CropRotateTool.reset],
    ),
    imageGeneration: const ImageGenerationConfigs(
      outputFormat: OutputFormat.jpg,
      jpegQuality: PhotoUploadQuality.jpegQuality,
      maxOutputSize: Size.square(PhotoUploadQuality.avatarMaxDimension * 1.0),
    ),
  );
}
