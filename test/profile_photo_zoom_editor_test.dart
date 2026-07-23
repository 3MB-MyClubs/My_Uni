import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/profile_photo_zoom_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  test(
    'student profile photo editor enables a locked zoomable avatar crop',
    () {
      final theme = profilePhotoEditorTheme(Brightness.dark);
      final configs = profilePhotoZoomEditorConfigs(theme);
      final crop = configs.cropRotateEditor;

      expect(crop.initialCropMode, CropMode.oval);
      expect(crop.initAspectRatio, 1);
      expect(crop.aspectRatios, hasLength(1));
      expect(crop.aspectRatios.single.value, 1);
      expect(crop.maxScale, 7);
      expect(crop.enableDoubleTap, isTrue);
      expect(crop.doubleTapScaleFactor, 2);
      expect(configs.imageGeneration.outputFormat, OutputFormat.jpg);
      expect(configs.imageGeneration.maxOutputSize, const Size.square(1024));
    },
  );

  test('student profile photo editor follows light and dark appearance', () {
    final light = profilePhotoEditorTheme(Brightness.light);
    final dark = profilePhotoEditorTheme(Brightness.dark);

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, isNot(dark.scaffoldBackgroundColor));
    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
  });
}
