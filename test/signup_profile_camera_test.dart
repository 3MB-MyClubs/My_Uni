import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/screens/signup_steps/step_profile.dart';
import 'package:flutter_application_1/services/signup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('camera photo is attached before signup can continue', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final tempDir = Directory.systemTemp.createTempSync('signup-camera-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final imageFile = File('${tempDir.path}/camera.png');
    imageFile.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
        'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );

    final cameraResult = Completer<XFile?>();
    ImageSource? requestedSource;
    String? submittedImagePath;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StepProfile(
            initialName: 'Alice Yılmaz',
            initialMajor: 'Computer Engineering',
            initialYear: 'Freshman',
            loadMajors: () async => const [
              SignupLookupItem(id: 'major-1', name: 'Computer Engineering'),
            ],
            loadAcademicYears: () async => const [
              SignupLookupItem(id: 'year-1', name: 'Freshman'),
            ],
            imagePickerOverride: (source) {
              requestedSource = source;
              return cameraResult.future;
            },
            imageCropperOverride: (sourcePath) async => CroppedFile(sourcePath),
            onNext: (_, _, _, _, _, imagePath) async {
              submittedImagePath = imagePath;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('signup-profile-photo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('signup-photo-camera')));
    await tester.pump(const Duration(milliseconds: 350));

    expect(requestedSource, ImageSource.camera);
    final continueButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('signup-profile-continue')),
    );
    expect(continueButton.onPressed, isNull);

    cameraResult.complete(XFile(imageFile.path));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);

    // Continue stays disabled until the student accepts the Terms, which now
    // live on this (final) sign-up step.
    final beforeTermsButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('signup-profile-continue')),
    );
    expect(beforeTermsButton.onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final enabledContinueButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('signup-profile-continue')),
    );
    expect(enabledContinueButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('signup-profile-continue')));
    await tester.pump();
    expect(submittedImagePath, imageFile.path);
    expect(tester.takeException(), isNull);
  });
}
