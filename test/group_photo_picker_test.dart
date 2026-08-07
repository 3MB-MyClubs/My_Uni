import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/widgets/group_photo_editor.dart';
import 'package:flutter_application_1/widgets/group_photo_picker.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  test('group photo editor exposes Instagram-style editing tools', () async {
    final originalLanguage = localeService.languageCode;
    await localeService.setLanguage('en');
    addTearDown(() => localeService.setLanguage(originalLanguage));

    final configs = groupPhotoEditorConfigs();
    final tiltTheme = groupPhotoTiltTheme();

    expect(configs.mainEditor.tools, [
      SubEditorMode.cropRotate,
      SubEditorMode.tune,
      SubEditorMode.filter,
      SubEditorMode.paint,
      SubEditorMode.text,
      SubEditorMode.emoji,
    ]);
    expect(configs.cropRotateEditor.initAspectRatio, 1);
    expect(configs.cropRotateEditor.aspectRatios, hasLength(1));
    expect(configs.cropRotateEditor.aspectRatios.single.value, 1);
    expect(configs.imageGeneration.maxOutputSize, const Size.square(1024));
    expect(tiltTheme.cropLabel, 'Use photo');
    expect(tiltTheme.accentColor, isNot(Colors.amber));
  });

  testWidgets('selected group photo goes through the editor before saving', (
    tester,
  ) async {
    ImageSource? selectedSource;
    String? editorInput;
    String? changedPath;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GroupPhotoPicker(
              imagePath: null,
              memberIds: const ['u2'],
              nameForUser: (_) => 'Can',
              onChanged: (path) => changedPath = path,
              sourcePicker: (source) async {
                selectedSource = source;
                return '/picked/group.jpg';
              },
              editorLauncher: (context, sourcePath) async {
                editorInput = sourcePath;
                return '/edited/group.jpg';
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('group-photo-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('group-photo-library')));
    await tester.pumpAndSettle();

    expect(selectedSource, ImageSource.gallery);
    expect(editorInput, '/picked/group.jpg');
    expect(changedPath, '/edited/group.jpg');
    expect(tester.takeException(), isNull);
  });
}
